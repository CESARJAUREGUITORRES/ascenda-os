-- ASCENDA OS — F4 Cartera Reconciliation V2
-- Candidate discovery is read-only. Linking existing evidence never creates aos_pagos rows.

create or replace function public.aos_cartera_candidates_v2(p_token text,p_case_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_case record;
  v_phone text;
  v_dni text;
  v_sede text;
  v_date date;
  v_concept text;
  v_amount numeric;
  v_product_key text;
  v_candidates jsonb;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-cartera');
  if v_actor is null or p_case_id is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;

  select cr.id,cr.source_type,cr.venta_row_id,cr.cotizacion_id,cr.monto_registrado,
         upper(trim(coalesce(v.sede,c.sede,''))) sede,
         coalesce(v.fecha,c.fecha_creacion) source_date,
         regexp_replace(coalesce(v.numero_limpio,v.celular,c.numero_limpio,''),'\D','','g') phone,
         regexp_replace(coalesce(v.dni,c.dni_paciente,''),'\D','','g') dni,
         upper(trim(coalesce(v.tratamiento,''))) concept,
         f.product_key
    into v_case
  from public.aos_cartera_reconciliacion cr
  left join public.aos_ventas v on cr.source_type='VENTA' and v.id=cr.venta_row_id
  left join public.aos_cotizaciones c on cr.cotizacion_id=c.id
  left join public.aos_product_sale_fact_v1 f on f.sale_id=v.id and f.resolution_status='RESOLVED'
  where cr.id=p_case_id and cr.source_active=true;

  if v_case.id is null then return jsonb_build_object('ok',false,'error','CASE_NOT_FOUND'); end if;
  if not public.aos_f4_sede_allowed(v_actor,v_case.sede) then return jsonb_build_object('ok',false,'error','FORBIDDEN_SEDE'); end if;

  v_phone:=nullif(v_case.phone,'');
  v_dni:=nullif(v_case.dni,'');
  v_sede:=v_case.sede;
  v_date:=v_case.source_date;
  v_concept:=v_case.concept;
  v_amount:=coalesce(v_case.monto_registrado,0);
  v_product_key:=v_case.product_key;

  if coalesce(length(v_phone),0)<6 and coalesce(length(v_dni),0)<6 then
    return jsonb_build_object('ok',true,'caseId',p_case_id,'candidates','[]'::jsonb,'reason','IDENTITY_INSUFFICIENT','mutates',false);
  end if;

  with raw as (
    select
      'COTIZACION'::text candidate_type,
      c.id::text candidate_id,
      c.fecha_creacion candidate_date,
      c.sede,
      c.nombre_paciente label,
      c.subtotal total_amount,
      c.total_pagado paid_amount,
      c.saldo_pendiente balance_amount,
      c.estado status,
      (
        (case when length(coalesce(v_phone,''))>=6 and regexp_replace(coalesce(c.numero_limpio,''),'\D','','g')=v_phone then 45 else 0 end) +
        (case when length(coalesce(v_dni,''))>=6 and regexp_replace(coalesce(c.dni_paciente,''),'\D','','g')=v_dni then 50 else 0 end) +
        10 +
        (case when abs(c.fecha_creacion-v_date)<=30 then 15 when abs(c.fecha_creacion-v_date)<=60 then 8 else 3 end) +
        (case when v_amount>0 and abs(coalesce(c.total_pagado,0)-v_amount)<=1 then 10 else 0 end) +
        (case when upper(trim(coalesce(c.estado,''))) in ('PAGADO_COMPLETO','PAGADO_PARCIAL') then 5 else 0 end)
      )::integer score,
      jsonb_strip_nulls(jsonb_build_object(
        'phoneMatch',case when length(coalesce(v_phone,''))>=6 and regexp_replace(coalesce(c.numero_limpio,''),'\D','','g')=v_phone then true else null end,
        'dniMatch',case when length(coalesce(v_dni,''))>=6 and regexp_replace(coalesce(c.dni_paciente,''),'\D','','g')=v_dni then true else null end,
        'sameSede',true,
        'daysApart',abs(c.fecha_creacion-v_date),
        'amountNear',case when v_amount>0 then abs(coalesce(c.total_pagado,0)-v_amount)<=1 else null end
      )) reasons
    from public.aos_cotizaciones c
    where upper(trim(coalesce(c.sede,'')))=v_sede
      and c.fecha_creacion between v_date-90 and v_date+90
      and (v_case.cotizacion_id is null or c.id<>v_case.cotizacion_id)
      and (
        (length(coalesce(v_phone,''))>=6 and regexp_replace(coalesce(c.numero_limpio,''),'\D','','g')=v_phone)
        or (length(coalesce(v_dni,''))>=6 and regexp_replace(coalesce(c.dni_paciente,''),'\D','','g')=v_dni)
      )

    union all

    select
      'VENTA'::text candidate_type,
      v.id::text candidate_id,
      v.fecha candidate_date,
      v.sede,
      trim(coalesce(v.nombres,'')||' '||coalesce(v.apellidos,'')) label,
      v.monto total_amount,
      case when upper(trim(coalesce(v.estado_pago,'')))='PAGO COMPLETO' then v.monto else null end paid_amount,
      null::numeric balance_amount,
      v.estado_pago status,
      (
        (case when length(coalesce(v_phone,''))>=6 and regexp_replace(coalesce(v.numero_limpio,v.celular,''),'\D','','g')=v_phone then 45 else 0 end) +
        (case when length(coalesce(v_dni,''))>=6 and regexp_replace(coalesce(v.dni,''),'\D','','g')=v_dni then 50 else 0 end) +
        10 +
        (case when abs(v.fecha-v_date)<=30 then 15 when abs(v.fecha-v_date)<=60 then 8 else 3 end) +
        (case when v_product_key is not null and f2.product_key=v_product_key then 15 when v_concept<>'' and upper(trim(coalesce(v.tratamiento,'')))=v_concept then 12 else 0 end) +
        (case when v_amount>0 and abs(coalesce(v.monto,0)-v_amount)<=1 then 8 else 0 end) +
        (case when upper(trim(coalesce(v.estado_pago,'')))='PAGO COMPLETO' then 8 else 0 end)
      )::integer score,
      jsonb_strip_nulls(jsonb_build_object(
        'phoneMatch',case when length(coalesce(v_phone,''))>=6 and regexp_replace(coalesce(v.numero_limpio,v.celular,''),'\D','','g')=v_phone then true else null end,
        'dniMatch',case when length(coalesce(v_dni,''))>=6 and regexp_replace(coalesce(v.dni,''),'\D','','g')=v_dni then true else null end,
        'sameSede',true,
        'daysApart',abs(v.fecha-v_date),
        'sameConcept',case when v_concept<>'' then upper(trim(coalesce(v.tratamiento,'')))=v_concept else null end,
        'sameCanonicalProduct',case when v_product_key is not null then f2.product_key=v_product_key else null end,
        'fullPayment',upper(trim(coalesce(v.estado_pago,'')))='PAGO COMPLETO',
        'amountNear',case when v_amount>0 then abs(coalesce(v.monto,0)-v_amount)<=1 else null end
      )) reasons
    from public.aos_ventas v
    left join public.aos_product_sale_fact_v1 f2 on f2.sale_id=v.id and f2.resolution_status='RESOLVED'
    where upper(trim(coalesce(v.sede,'')))=v_sede
      and v.fecha between v_date-90 and v_date+90
      and (v_case.venta_row_id is null or v.id<>v_case.venta_row_id)
      and (
        (length(coalesce(v_phone,''))>=6 and regexp_replace(coalesce(v.numero_limpio,v.celular,''),'\D','','g')=v_phone)
        or (length(coalesce(v_dni,''))>=6 and regexp_replace(coalesce(v.dni,''),'\D','','g')=v_dni)
      )
  ), ranked as (
    select *,case when score>=85 then 'ALTA' when score>=65 then 'MEDIA' else 'BAJA' end confidence
    from raw
    where score>=55
    order by score desc,candidate_date desc
    limit 12
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'type',candidate_type,'id',candidate_id,'date',candidate_date,'sede',sede,
    'label',label,'totalAmount',total_amount,'paidAmount',paid_amount,'balanceAmount',balance_amount,
    'status',status,'score',score,'confidence',confidence,'reasons',reasons
  ) order by score desc,candidate_date desc),'[]'::jsonb)
  into v_candidates from ranked;

  return jsonb_build_object('ok',true,'caseId',p_case_id,'candidates',v_candidates,'mutates',false,'autoDecision',false);
end
$function$;

create or replace function public.aos_cartera_reconcile_v2(
  p_token text,
  p_case_id uuid,
  p_expected_updated_at timestamptz,
  p_estado text,
  p_confianza text default 'CONFIRMADA',
  p_total_esperado numeric default null,
  p_saldo_confirmado numeric default null,
  p_candidate_type text default null,
  p_candidate_id text default null,
  p_rol_pago text default 'ADELANTO',
  p_observacion text default ''
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_actor_name text;
  v_type text:=upper(trim(coalesce(p_candidate_type,'')));
  v_candidates jsonb;
  v_valid boolean:=false;
  v_quote_id text:=null;
  v_result jsonb;
  v_payments_before bigint;
begin
  v_actor:=public.aos_f4_actor(p_token,'admin-cartera');
  if v_actor is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if (v_type='' and nullif(trim(coalesce(p_candidate_id,'')),'') is not null)
     or (v_type<>'' and nullif(trim(coalesce(p_candidate_id,'')),'') is null)
     or v_type not in ('','VENTA','COTIZACION') then
    return jsonb_build_object('ok',false,'error','INVALID_CANDIDATE');
  end if;

  if v_type<>'' then
    v_candidates:=public.aos_cartera_candidates_v2(p_token,p_case_id);
    select exists(
      select 1 from jsonb_array_elements(coalesce(v_candidates->'candidates','[]'::jsonb)) x
      where x->>'type'=v_type and x->>'id'=p_candidate_id
    ) into v_valid;
    if not v_valid then return jsonb_build_object('ok',false,'error','CANDIDATE_NOT_ALLOWED'); end if;
    if v_type='COTIZACION' then v_quote_id:=p_candidate_id; end if;
  end if;

  if upper(trim(coalesce(p_estado,'')))='PAGO_RECONCILIADO' and v_type='' then
    return jsonb_build_object('ok',false,'error','EVIDENCE_LINK_REQUIRED');
  end if;

  select count(*) into v_payments_before from public.aos_pagos;
  v_result:=public.aos_cartera_reconcile(
    p_token,p_case_id,p_expected_updated_at,p_estado,p_confianza,
    p_total_esperado,p_saldo_confirmado,v_quote_id,p_rol_pago,p_observacion
  );
  if coalesce((v_result->>'ok')::boolean,false)=false then return v_result; end if;

  if v_type='VENTA' then
    update public.aos_cartera_reconciliacion
    set evidencia=coalesce(evidencia,'{}'::jsonb)||jsonb_build_object(
      'f4_link',jsonb_build_object('type','VENTA','sale_id',p_candidate_id,'linked_at',now(),'linked_by',v_actor)
    ),updated_at=now()
    where id=p_case_id;
  elsif v_type='COTIZACION' then
    update public.aos_cartera_reconciliacion
    set evidencia=coalesce(evidencia,'{}'::jsonb)||jsonb_build_object(
      'f4_link',jsonb_build_object('type','COTIZACION','quote_id',p_candidate_id,'linked_at',now(),'linked_by',v_actor)
    )
    where id=p_case_id;
  end if;

  if (select count(*) from public.aos_pagos)<>v_payments_before then
    raise exception 'F4_RECONCILIATION_MUST_NOT_CREATE_PAYMENTS';
  end if;

  select au.nombre into v_actor_name from public.aos_usuarios au where au.id=v_actor;
  insert into public.aos_security_log(usuario,accion,detalles)
  values(coalesce(v_actor_name,'ADMIN'),'F4_CARTERA_LINK',jsonb_build_object(
    'actor_id',v_actor,'case_id',p_case_id,'candidate_type',nullif(v_type,''),'candidate_id',p_candidate_id,'status',p_estado
  ));

  return v_result || jsonb_build_object('candidateType',nullif(v_type,''),'candidateId',p_candidate_id,'createdPayment',false,'contract','F4_CARTERA_RECONCILIATION_V2');
end
$function$;

revoke all on function public.aos_cartera_candidates_v2(text,uuid) from public;
revoke all on function public.aos_cartera_reconcile_v2(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text,text) from public;
grant execute on function public.aos_cartera_candidates_v2(text,uuid) to anon,authenticated;
grant execute on function public.aos_cartera_reconcile_v2(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text,text) to anon,authenticated;
