-- ASCENDA OS — F4 Cartera gateway V2 Auth V3 chain hotfix.
-- Read-path only for business data: removes the incompatible second legacy-session
-- validation from aos_cartera_gateway_v2 and makes the old READ gateway a compatibility
-- alias to V2. No legacy write function is widened or changed.

begin;

create or replace function public.aos_cartera_gateway_v2(
  p_token text,
  p_estado text default '',
  p_sede text default '',
  p_limit integer default 50,
  p_offset integer default 0
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid;
  v_level integer;
  v_allowed_sedes text[];
  v_estado text:=upper(trim(coalesce(p_estado,'')));
  v_sede text:=upper(trim(coalesce(p_sede,'')));
  v_result jsonb;
begin
  if coalesce(length(p_token),0)<32 then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  -- Canonical F4 authority. Do not delegate back to the legacy finance-session
  -- gateway: doing so would require aos_cia_admin_sessions after Auth V3 already
  -- succeeded and would reject a valid aos_app_token.
  v_actor:=public.aos_f4_actor(p_token,'admin-cartera');
  if v_actor is null then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  select au.nivel_jerarquia,
         coalesce((
           select array_agg(upper(trim(s)))
           from unnest(coalesce(au.sedes_permitidas,'{}'::text[])) s
           where nullif(trim(s),'') is not null
         ),'{}'::text[])
    into v_level,v_allowed_sedes
  from public.aos_usuarios au
  where au.id=v_actor;

  if v_estado not in (
    '','PENDIENTE_RECONCILIAR','SALDO_CONFIRMADO','PAGO_RECONCILIADO',
    'CERRADO','NO_ES_DEUDA','REVISAR'
  ) or v_sede not in ('','SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'error','INVALID_FILTER');
  end if;

  if v_level<>1 and cardinality(v_allowed_sedes)=0 then
    return jsonb_build_object('ok',false,'error','NO_ALLOWED_SEDE');
  end if;
  if v_sede<>'' and v_level<>1
     and not coalesce(v_sede=any(v_allowed_sedes),false) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_SEDE');
  end if;
  if p_limit not between 1 and 100 or p_offset<0 then
    return jsonb_build_object('ok',false,'error','INVALID_PAGE');
  end if;

  update public.aos_app_sessions_v3
  set last_used_at=now()
  where user_id=v_actor and revoked=false;

  with cases as (
    select
      cr.id,cr.source_type,cr.venta_row_id,cr.cotizacion_id,cr.rol_pago,
      cr.estado_reconciliacion,cr.confianza,cr.monto_registrado,
      cr.total_compra_esperado,cr.saldo_confirmado,cr.source_active,
      cr.observacion,cr.updated_at,
      coalesce(v.fecha,c.fecha_creacion) as source_date,
      coalesce(
        nullif(trim(coalesce(v.nombres,'')||' '||coalesce(v.apellidos,'')),''),
        c.nombre_paciente,'SIN NOMBRE'
      ) as patient_name,
      case
        when length(regexp_replace(coalesce(v.numero_limpio,v.celular,c.numero_limpio,''),'\D','','g'))>=4
          then '***'||right(regexp_replace(coalesce(v.numero_limpio,v.celular,c.numero_limpio,''),'\D','','g'),4)
        else 'SIN CONTACTO'
      end as contact_masked,
      coalesce(v.sede,c.sede,'SIN SEDE') as sede,
      coalesce(v.asesor,c.asesor,'') as asesor,
      coalesce(v.tratamiento,'Cotizacion #'||coalesce(c.numero_cotizacion::text,'')) as concept,
      c.saldo_pendiente as quote_balance_recorded,
      case
        when cr.source_type='VENTA' and exists (
          select 1
          from public.aos_ventas v2
          where v2.id<>v.id
            and v2.fecha>v.fecha
            and v2.fecha<=v.fecha+30
            and (
              (
                nullif(regexp_replace(coalesce(v.numero_limpio,v.celular,''),'\D','','g'),'') is not null
                and regexp_replace(coalesce(v2.numero_limpio,v2.celular,''),'\D','','g')=
                    regexp_replace(coalesce(v.numero_limpio,v.celular,''),'\D','','g')
              )
              or (
                nullif(regexp_replace(coalesce(v.dni,''),'\D','','g'),'') is not null
                and regexp_replace(coalesce(v2.dni,''),'\D','','g')=
                    regexp_replace(coalesce(v.dni,''),'\D','','g')
              )
            )
            and upper(trim(coalesce(v2.estado_pago,'')))='PAGO COMPLETO'
            and upper(trim(coalesce(v2.tratamiento,'')))=upper(trim(coalesce(v.tratamiento,'')))
        ) then 'POSIBLE_PAGO_POSTERIOR'
        when cr.source_type='VENTA' then 'TOTAL_ESPERADO_DESCONOCIDO'
        else 'LEDGER_INCOMPLETO'
      end as evidence_signal
    from public.aos_cartera_reconciliacion cr
    left join public.aos_ventas v
      on cr.source_type='VENTA' and v.id=cr.venta_row_id
    left join public.aos_cotizaciones c
      on cr.cotizacion_id=c.id
    where cr.source_active=true
      and (
        v_level=1
        or coalesce(upper(trim(coalesce(v.sede,c.sede,'')))=any(v_allowed_sedes),false)
      )
      and (v_estado='' or cr.estado_reconciliacion=v_estado)
      and (v_sede='' or upper(coalesce(v.sede,c.sede,''))=v_sede)
  ), summary as (
    select jsonb_build_object(
      'activeCases',count(*),
      'pending',count(*) filter(where estado_reconciliacion='PENDIENTE_RECONCILIAR'),
      'review',count(*) filter(where estado_reconciliacion='REVISAR'),
      'confirmedBalances',count(*) filter(where estado_reconciliacion='SALDO_CONFIRMADO'),
      'confirmedAmount',coalesce(sum(saldo_confirmado) filter(where estado_reconciliacion='SALDO_CONFIRMADO'),0),
      'reconciled',count(*) filter(where estado_reconciliacion in ('PAGO_RECONCILIADO','CERRADO','NO_ES_DEUDA')),
      'historicalAdvancesCutoff',count(*) filter(where source_type='VENTA' and source_date<='2026-08-12')
    ) data
    from cases
  ), page as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id',id,'sourceType',source_type,'sourceDate',source_date,
      'patient',patient_name,'contact',contact_masked,'sede',sede,'asesor',asesor,
      'concept',concept,'role',rol_pago,'status',estado_reconciliacion,
      'confidence',confianza,'paidAmount',monto_registrado,
      'expectedTotal',total_compra_esperado,'confirmedBalance',saldo_confirmado,
      'quoteBalanceRecorded',quote_balance_recorded,'signal',evidence_signal,
      'note',observacion,'updatedAt',updated_at
    ) order by source_date desc,id), '[]'::jsonb) data
    from (
      select *
      from cases
      order by source_date desc,id
      limit p_limit offset p_offset
    ) p
  )
  select jsonb_build_object(
    'ok',true,
    'readOnly',false,
    'contract','F4_CARTERA_GATEWAY_V2',
    'strongAuth',true,
    'summary',summary.data,
    'rows',page.data,
    'policy',jsonb_build_object(
      'advanceIsPaymentNotBalance',true,
      'legacyAmountsTrusted',false,
      'remindersEnabled',false,
      'onlyConfirmedBalancesCollectible',true
    )
  ) into v_result
  from summary,page;

  return v_result;
end
$function$;

revoke all on function public.aos_cartera_gateway_v2(text,text,text,integer,integer) from public;
grant execute on function public.aos_cartera_gateway_v2(text,text,text,integer,integer) to anon,authenticated;

-- Transitional READ compatibility for the currently deployed panel and stale
-- service-worker/browser assets. This old read name no longer performs its own
-- finance-session validation; it is a narrow alias to the canonical V2 gate.
-- No reconcile/write function is changed here.
create or replace function public.aos_cartera_gateway(
  p_token text,
  p_estado text default '',
  p_sede text default '',
  p_limit integer default 50,
  p_offset integer default 0
) returns jsonb
language sql
security definer
set search_path = ''
as $function$
  select public.aos_cartera_gateway_v2(
    p_token,p_estado,p_sede,p_limit,p_offset
  )
$function$;

revoke all on function public.aos_cartera_gateway(text,text,text,integer,integer) from public;
grant execute on function public.aos_cartera_gateway(text,text,text,integer,integer) to anon,authenticated;

notify pgrst, 'reload schema';

commit;
