-- ASCENDA OS — FASE 2 Cartera
-- Bridge de reconciliacion, gateway admin 2FA y abono de cotizacion v2.
-- No envia recordatorios ni modifica los montos historicos de ventas/cotizaciones.

begin;

insert into public.aos_paneles_disponibles(id,nombre,icono,categoria,orden,descripcion)
values (
  'admin-cartera',
  'Cartera',
  '💼',
  'admin',
  76,
  'Reconciliacion y seguimiento manual de saldos. Requiere administrador, 2FA y asignacion explicita.'
)
on conflict (id) do update
set nombre=excluded.nombre,
    icono=excluded.icono,
    categoria=excluded.categoria,
    orden=excluded.orden,
    descripcion=excluded.descripcion;

create table if not exists public.aos_cartera_reconciliacion (
  id uuid primary key default extensions.gen_random_uuid(),
  source_type text not null check (source_type in ('VENTA','COTIZACION')),
  venta_row_id bigint references public.aos_ventas(id) on delete restrict,
  cotizacion_id text references public.aos_cotizaciones(id) on delete restrict,
  pago_id text references public.aos_pagos(id) on delete restrict,
  grupo_pago_id uuid not null default extensions.gen_random_uuid(),
  rol_pago text not null default 'ADELANTO'
    check (rol_pago in ('UNICO','ADELANTO','PARTE_1','PARTE_2','SALDO','COMPLEMENTO')),
  estado_reconciliacion text not null default 'PENDIENTE_RECONCILIAR'
    check (estado_reconciliacion in (
      'PENDIENTE_RECONCILIAR','SALDO_CONFIRMADO','PAGO_RECONCILIADO',
      'CERRADO','NO_ES_DEUDA','REVISAR'
    )),
  confianza text not null default 'NO_EVALUADA'
    check (confianza in ('NO_EVALUADA','BAJA','MEDIA','ALTA','CONFIRMADA')),
  monto_registrado numeric(14,2) not null default 0 check (monto_registrado >= 0),
  total_compra_esperado numeric(14,2),
  saldo_confirmado numeric(14,2),
  source_active boolean not null default true,
  evidencia jsonb not null default '{}'::jsonb,
  observacion text,
  confirmado_por uuid references public.aos_usuarios(id),
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (source_type='VENTA' and venta_row_id is not null)
    or (source_type='COTIZACION' and cotizacion_id is not null)
  ),
  check (total_compra_esperado is null or total_compra_esperado >= 0),
  check (saldo_confirmado is null or saldo_confirmado >= 0),
  check (
    estado_reconciliacion <> 'SALDO_CONFIRMADO'
    or (saldo_confirmado is not null and saldo_confirmado > 0)
  )
);

create unique index if not exists aos_cartera_venta_source_uidx
  on public.aos_cartera_reconciliacion(venta_row_id)
  where source_type='VENTA';

create unique index if not exists aos_cartera_cotizacion_source_uidx
  on public.aos_cartera_reconciliacion(cotizacion_id)
  where source_type='COTIZACION';

create index if not exists aos_cartera_estado_active_idx
  on public.aos_cartera_reconciliacion(estado_reconciliacion,source_active,updated_at desc);

alter table public.aos_cartera_reconciliacion enable row level security;
revoke all on table public.aos_cartera_reconciliacion from public,anon,authenticated;
grant all on table public.aos_cartera_reconciliacion to service_role;

-- Las fuentes financieras dejan de estar expuestas como tablas REST anonimas.
-- Las lecturas/escrituras operativas pasan exclusivamente por gateways 2FA.
alter table public.aos_cotizaciones enable row level security;
alter table public.aos_cotizacion_items enable row level security;
alter table public.aos_pagos enable row level security;
revoke all on table public.aos_cotizaciones from public,anon,authenticated;
revoke all on table public.aos_cotizacion_items from public,anon,authenticated;
revoke all on table public.aos_pagos from public,anon,authenticated;
grant all on table public.aos_cotizaciones to service_role;
grant all on table public.aos_cotizacion_items to service_role;
grant all on table public.aos_pagos to service_role;

alter table public.aos_pagos
  add column if not exists request_id uuid,
  add column if not exists request_hash text,
  add column if not exists cash_session_id text,
  add column if not exists registrado_por_user_id uuid references public.aos_usuarios(id);

alter table public.aos_caja_sesiones
  add column if not exists abierto_por_user_id uuid references public.aos_usuarios(id);

revoke insert,update,delete,truncate,references,trigger
  on table public.aos_caja_sesiones from public,anon,authenticated;
grant all on table public.aos_caja_sesiones to service_role;

create unique index if not exists aos_pagos_request_id_uidx
  on public.aos_pagos(request_id)
  where request_id is not null;

-- Snapshot derivado y reversible: no modifica las fuentes financieras.
insert into public.aos_cartera_reconciliacion(
  source_type,venta_row_id,cotizacion_id,rol_pago,estado_reconciliacion,
  confianza,monto_registrado,evidencia
)
select
  'VENTA',v.id,v.cotizacion_id,'ADELANTO','PENDIENTE_RECONCILIAR',
  'NO_EVALUADA',greatest(coalesce(v.monto,0),0),
  jsonb_build_object(
    'source','aos_ventas',
    'source_estado_pago',v.estado_pago,
    'source_fecha',v.fecha,
    'classification_rule','ESTADO_PAGO_ADELANTO_IS_PAYMENT_NOT_BALANCE'
  )
from public.aos_ventas v
where upper(trim(coalesce(v.estado_pago,'')))='ADELANTO'
on conflict (venta_row_id) where source_type='VENTA' do nothing;

insert into public.aos_cartera_reconciliacion(
  source_type,cotizacion_id,rol_pago,estado_reconciliacion,
  confianza,monto_registrado,total_compra_esperado,evidencia
)
select
  'COTIZACION',c.id,'ADELANTO','PENDIENTE_RECONCILIAR',
  'NO_EVALUADA',greatest(coalesce(c.total_pagado,0),0),
  greatest(coalesce(c.subtotal,0),0),
  jsonb_build_object(
    'source','aos_cotizaciones',
    'source_estado',c.estado,
    'source_saldo_registrado',c.saldo_pendiente,
    'ledger_complete',false,
    'classification_rule','QUOTE_BALANCE_REQUIRES_RECONCILIATION'
  )
from public.aos_cotizaciones c
where c.estado='PAGADO_PARCIAL' and coalesce(c.saldo_pendiente,0)>0
on conflict (cotizacion_id) where source_type='COTIZACION' do nothing;

create or replace function public.aos_cartera_sync_venta()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if upper(trim(coalesce(new.estado_pago,'')))='ADELANTO' then
    insert into public.aos_cartera_reconciliacion(
      source_type,venta_row_id,cotizacion_id,rol_pago,monto_registrado,evidencia,source_active
    ) values (
      'VENTA',new.id,new.cotizacion_id,'ADELANTO',greatest(coalesce(new.monto,0),0),
      jsonb_build_object(
        'source','aos_ventas','source_estado_pago',new.estado_pago,
        'source_fecha',new.fecha,
        'classification_rule','ESTADO_PAGO_ADELANTO_IS_PAYMENT_NOT_BALANCE'
      ),true
    )
    on conflict (venta_row_id) where source_type='VENTA' do update
    set cotizacion_id=coalesce(excluded.cotizacion_id,public.aos_cartera_reconciliacion.cotizacion_id),
        monto_registrado=excluded.monto_registrado,
        source_active=true,
        estado_reconciliacion='REVISAR',
        confianza='NO_EVALUADA',
        saldo_confirmado=null,
        confirmado_por=null,
        confirmed_at=null,
        evidencia=public.aos_cartera_reconciliacion.evidencia||excluded.evidencia,
        updated_at=now();
  else
    update public.aos_cartera_reconciliacion
    set source_active=false,estado_reconciliacion='REVISAR',
        confianza='NO_EVALUADA',saldo_confirmado=null,
        confirmado_por=null,confirmed_at=null,updated_at=now(),
        evidencia=evidencia||jsonb_build_object('source_estado_pago_actual',new.estado_pago)
    where source_type='VENTA' and venta_row_id=new.id;
  end if;
  return new;
end;
$function$;

-- No se instala un trigger sobre aos_ventas: esa tabla legacy conserva acceso
-- directo en modulos existentes. El snapshot inicial cubre el corte historico y
-- los nuevos pagos v2 escriben el bridge dentro de la misma transaccion.
-- Evita que una escritura legacy no autenticada se convierta en un caso admin.
drop trigger if exists trg_aos_cartera_sync_venta on public.aos_ventas;

create or replace function public.aos_cartera_sync_cotizacion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.estado='PAGADO_PARCIAL' and coalesce(new.saldo_pendiente,0)>0 then
    insert into public.aos_cartera_reconciliacion(
      source_type,cotizacion_id,rol_pago,monto_registrado,total_compra_esperado,
      evidencia,source_active
    ) values (
      'COTIZACION',new.id,'ADELANTO',greatest(coalesce(new.total_pagado,0),0),
      greatest(coalesce(new.subtotal,0),0),
      jsonb_build_object(
        'source','aos_cotizaciones','source_estado',new.estado,
        'source_saldo_registrado',new.saldo_pendiente,'ledger_complete',false,
        'classification_rule','QUOTE_BALANCE_REQUIRES_RECONCILIATION'
      ),true
    )
    on conflict (cotizacion_id) where source_type='COTIZACION' do update
    set monto_registrado=excluded.monto_registrado,
        total_compra_esperado=excluded.total_compra_esperado,
        source_active=true,
        estado_reconciliacion='REVISAR',
        confianza='NO_EVALUADA',
        saldo_confirmado=null,
        confirmado_por=null,
        confirmed_at=null,
        evidencia=public.aos_cartera_reconciliacion.evidencia||excluded.evidencia,
        updated_at=now();
    update public.aos_cartera_reconciliacion
    set estado_reconciliacion='REVISAR',confianza='NO_EVALUADA',
        saldo_confirmado=null,confirmado_por=null,confirmed_at=null,
        evidencia=evidencia||jsonb_build_object(
          'quote_changed_at',now(),'source_saldo_actual',new.saldo_pendiente
        ),updated_at=now()
    where source_type='VENTA' and cotizacion_id=new.id and source_active=true;
  else
    update public.aos_cartera_reconciliacion
    set source_active=false,estado_reconciliacion='REVISAR',
        confianza='NO_EVALUADA',saldo_confirmado=null,
        confirmado_por=null,confirmed_at=null,updated_at=now(),
        evidencia=evidencia||jsonb_build_object(
          'source_estado_actual',new.estado,
          'source_saldo_actual',new.saldo_pendiente
        )
    where source_type='COTIZACION' and cotizacion_id=new.id;
    update public.aos_cartera_reconciliacion
    set source_active=false,
        estado_reconciliacion=case
          when new.estado='PAGADO_COMPLETO' then 'PAGO_RECONCILIADO'
          else 'REVISAR' end,
        confianza=case
          when new.estado='PAGADO_COMPLETO' then 'CONFIRMADA'
          else 'NO_EVALUADA' end,
        saldo_confirmado=case when new.estado='PAGADO_COMPLETO' then 0 else null end,
        confirmado_por=null,confirmed_at=null,
        evidencia=evidencia||jsonb_build_object(
          'quote_changed_at',now(),'source_estado_actual',new.estado,
          'source_saldo_actual',new.saldo_pendiente
        ),updated_at=now()
    where source_type='VENTA' and cotizacion_id=new.id and source_active=true;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_aos_cartera_sync_cotizacion on public.aos_cotizaciones;
create trigger trg_aos_cartera_sync_cotizacion
after insert or update of estado,total_pagado,saldo_pendiente,subtotal on public.aos_cotizaciones
for each row execute function public.aos_cartera_sync_cotizacion();

-- Se reutiliza la sesion 2FA ya certificada en FASE 1. Esta migracion no
-- redefine el verificador de contrasena ni amplia quien puede emitir tokens.

create or replace function public.aos_cartera_actor(
  p_token text,
  p_panel text
) returns uuid
language sql
stable
security definer
set search_path = ''
as $function$
  select au.id
  from public.aos_cia_admin_sessions s
  join public.aos_usuarios au on au.id=s.user_id
  join public.aos_rrhh r on r.codigo_asesor=au.codigo_asesor
  where s.token_hash=encode(extensions.digest(p_token,'sha256'),'hex')
    and s.revoked=false
    and s.expires_at>now()
    and au.activo=true
    and au.two_factor=true
    and au.nivel_jerarquia in (1,2)
    and lower(coalesce(au.rol,''))='admin'
    and upper(trim(coalesce(r.estado,'')))='ACTIVO'
    and coalesce(au.paneles_acceso,'{}'::text[]) @> array[p_panel]::text[]
  limit 1
$function$;

create or replace function public.aos_cartera_gateway(
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
  v_actor:=public.aos_cartera_actor(p_token,'admin-cartera');
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
  from public.aos_usuarios au where au.id=v_actor;
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

  update public.aos_cia_admin_sessions
  set last_used_at=now()
  where user_id=v_actor and revoked=false;

  with cases as (
    select
      cr.id,cr.source_type,cr.venta_row_id,cr.cotizacion_id,cr.rol_pago,
      cr.estado_reconciliacion,cr.confianza,cr.monto_registrado,
      cr.total_compra_esperado,cr.saldo_confirmado,cr.source_active,
      cr.observacion,cr.updated_at,
      coalesce(v.fecha,c.fecha_creacion) as source_date,
      coalesce(nullif(trim(coalesce(v.nombres,'')||' '||coalesce(v.apellidos,'')),''),c.nombre_paciente,'SIN NOMBRE') as patient_name,
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
          select 1 from public.aos_ventas v2
          where v2.id<>v.id and v2.fecha>v.fecha and v2.fecha<=v.fecha+30
            and (
              (nullif(regexp_replace(coalesce(v.numero_limpio,v.celular,''),'\D','','g'),'') is not null
               and regexp_replace(coalesce(v2.numero_limpio,v2.celular,''),'\D','','g')=
                   regexp_replace(coalesce(v.numero_limpio,v.celular,''),'\D','','g'))
              or (nullif(regexp_replace(coalesce(v.dni,''),'\D','','g'),'') is not null
                  and regexp_replace(coalesce(v2.dni,''),'\D','','g')=regexp_replace(coalesce(v.dni,''),'\D','','g'))
            )
            and upper(trim(coalesce(v2.estado_pago,'')))='PAGO COMPLETO'
            and upper(trim(coalesce(v2.tratamiento,'')))=upper(trim(coalesce(v.tratamiento,'')))
        ) then 'POSIBLE_PAGO_POSTERIOR'
        when cr.source_type='VENTA' then 'TOTAL_ESPERADO_DESCONOCIDO'
        else 'LEDGER_INCOMPLETO'
      end as evidence_signal
    from public.aos_cartera_reconciliacion cr
    left join public.aos_ventas v on cr.source_type='VENTA' and v.id=cr.venta_row_id
    left join public.aos_cotizaciones c on cr.cotizacion_id=c.id
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
      'historicalAdvancesCutoff',count(*) filter(where source_type='VENTA' and source_date<='2026-08-12'),
      'historicalAdvancePayments',coalesce(sum(monto_registrado) filter(where source_type='VENTA' and source_date<='2026-08-12'),0)
    ) data from cases
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
      select * from cases order by source_date desc,id limit p_limit offset p_offset
    ) p
  )
  select jsonb_build_object(
    'ok',true,'readOnly',false,'summary',summary.data,'rows',page.data,
    'policy',jsonb_build_object(
      'advanceIsPaymentNotBalance',true,
      'remindersEnabled',false,
      'onlyConfirmedBalancesCollectible',true
    )
  ) into v_result
  from summary,page;

  return v_result;
end;
$function$;

create or replace function public.aos_cartera_reconcile(
  p_token text,
  p_case_id uuid,
  p_expected_updated_at timestamptz,
  p_estado text,
  p_confianza text default 'CONFIRMADA',
  p_total_esperado numeric default null,
  p_saldo_confirmado numeric default null,
  p_cotizacion_id text default null,
  p_rol_pago text default 'ADELANTO',
  p_observacion text default ''
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid;
  v_level integer;
  v_allowed_sedes text[];
  v_source_sede text;
  v_quote_sede text;
  v_target_quote text;
  v_quote_balance numeric;
  v_quote_total numeric;
  v_quote_paid numeric;
  v_quote_estado text;
  v_source_phone text;
  v_source_dni text;
  v_quote_phone text;
  v_quote_dni text;
  v_estado text:=upper(trim(coalesce(p_estado,'')));
  v_confianza text:=upper(trim(coalesce(p_confianza,'')));
  v_rol text:=upper(trim(coalesce(p_rol_pago,'')));
  v_previous record;
begin
  if coalesce(length(p_token),0)<32 or p_case_id is null then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_actor:=public.aos_cartera_actor(p_token,'admin-cartera');
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
  from public.aos_usuarios au where au.id=v_actor;
  if v_level<>1 and cardinality(v_allowed_sedes)=0 then
    return jsonb_build_object('ok',false,'error','NO_ALLOWED_SEDE');
  end if;
  if v_estado not in (
    'PENDIENTE_RECONCILIAR','SALDO_CONFIRMADO','PAGO_RECONCILIADO',
    'CERRADO','NO_ES_DEUDA','REVISAR'
  ) or v_confianza not in ('NO_EVALUADA','BAJA','MEDIA','ALTA','CONFIRMADA')
     or v_rol not in ('UNICO','ADELANTO','PARTE_1','PARTE_2','SALDO','COMPLEMENTO') then
    return jsonb_build_object('ok',false,'error','INVALID_STATE');
  end if;
  if v_estado='SALDO_CONFIRMADO'
     and (coalesce(p_saldo_confirmado,0)<=0 or coalesce(p_total_esperado,0)<=0) then
    return jsonb_build_object('ok',false,'error','CONFIRMED_BALANCE_REQUIRED');
  end if;
  if coalesce(p_total_esperado,0)<0 or coalesce(p_saldo_confirmado,0)<0 then
    return jsonb_build_object('ok',false,'error','INVALID_AMOUNT');
  end if;

  -- Lectura inicial para identificar la cotizacion; la validacion final se
  -- repite bajo lock despues de bloquear primero la fuente financiera.
  select * into v_previous
  from public.aos_cartera_reconciliacion
  where id=p_case_id;
  if v_previous.id is null then
    return jsonb_build_object('ok',false,'error','CASE_NOT_FOUND');
  end if;

  if v_previous.source_type='COTIZACION'
     and p_cotizacion_id is not null
     and p_cotizacion_id<>v_previous.cotizacion_id then
    return jsonb_build_object('ok',false,'error','QUOTE_SOURCE_IMMUTABLE');
  end if;
  v_target_quote:=case
    when v_previous.source_type='COTIZACION' then v_previous.cotizacion_id
    else coalesce(p_cotizacion_id,v_previous.cotizacion_id)
  end;

  if v_target_quote is not null then
    select upper(trim(coalesce(c.sede,''))),c.saldo_pendiente,c.subtotal,c.total_pagado,c.estado,
           regexp_replace(coalesce(c.numero_limpio,''),'\D','','g'),
           regexp_replace(coalesce(c.dni_paciente,''),'\D','','g')
      into v_quote_sede,v_quote_balance,v_quote_total,v_quote_paid,v_quote_estado,v_quote_phone,v_quote_dni
    from public.aos_cotizaciones c where c.id=v_target_quote
    for update;
    if v_quote_sede is null then
      return jsonb_build_object('ok',false,'error','QUOTE_NOT_FOUND');
    end if;
  end if;

  select * into v_previous
  from public.aos_cartera_reconciliacion
  where id=p_case_id
  for update;
  if p_expected_updated_at is null or v_previous.updated_at<>p_expected_updated_at then
    return jsonb_build_object(
      'ok',false,'error','STALE_CASE','current_updated_at',v_previous.updated_at
    );
  end if;
  if not coalesce(v_previous.source_active,false) then
    return jsonb_build_object('ok',false,'error','INACTIVE_CASE');
  end if;

  select upper(trim(coalesce(v.sede,c.sede,''))) into v_source_sede
  from public.aos_cartera_reconciliacion cr
  left join public.aos_ventas v on cr.source_type='VENTA' and v.id=cr.venta_row_id
  left join public.aos_cotizaciones c on cr.cotizacion_id=c.id
  where cr.id=p_case_id;
  if v_source_sede is null or v_source_sede not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'error','SOURCE_SEDE_INVALID');
  end if;
  if v_level<>1 and not coalesce(v_source_sede=any(v_allowed_sedes),false) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_SEDE');
  end if;

  if v_target_quote is not null then
    if v_quote_sede<>v_source_sede then
      return jsonb_build_object('ok',false,'error','QUOTE_SEDE_MISMATCH');
    end if;
    if v_level<>1 and not coalesce(v_quote_sede=any(v_allowed_sedes),false) then
      return jsonb_build_object('ok',false,'error','FORBIDDEN_SEDE');
    end if;
    if v_previous.source_type='VENTA' then
      select regexp_replace(coalesce(v.numero_limpio,v.celular,''),'\D','','g'),
             regexp_replace(coalesce(v.dni,''),'\D','','g')
        into v_source_phone,v_source_dni
      from public.aos_ventas v where v.id=v_previous.venta_row_id;
      if (
        length(coalesce(v_source_phone,''))>=6
        and length(coalesce(v_quote_phone,''))>=6
        and v_source_phone<>v_quote_phone
      ) or (
        length(coalesce(v_source_dni,''))>=6
        and length(coalesce(v_quote_dni,''))>=6
        and v_source_dni<>v_quote_dni
      ) or not (
        (length(coalesce(v_source_phone,''))>=6 and v_source_phone=v_quote_phone)
        or (length(coalesce(v_source_dni,''))>=6 and v_source_dni=v_quote_dni)
      ) then
        return jsonb_build_object('ok',false,'error','QUOTE_IDENTITY_MISMATCH');
      end if;
    end if;
  end if;

  if v_estado='SALDO_CONFIRMADO' then
    if p_saldo_confirmado>p_total_esperado then
      return jsonb_build_object('ok',false,'error','BALANCE_EXCEEDS_EXPECTED_TOTAL');
    end if;
    if v_target_quote is not null
       and upper(trim(coalesce(v_quote_estado,'')))<>'PAGADO_PARCIAL' then
      return jsonb_build_object('ok',false,'error','QUOTE_NOT_COLLECTIBLE');
    end if;
    if v_target_quote is not null and (
      greatest(coalesce(v_quote_total,0),0)-greatest(coalesce(v_quote_paid,0),0)
        <>greatest(coalesce(v_quote_balance,0),0)
      or p_saldo_confirmado<>greatest(coalesce(v_quote_balance,0),0)
      or p_total_esperado<>greatest(coalesce(v_quote_total,0),0)
    ) then
      return jsonb_build_object('ok',false,'error','BALANCE_MUST_MATCH_QUOTE');
    end if;
  end if;

  update public.aos_cartera_reconciliacion
  set estado_reconciliacion=v_estado,
      confianza=v_confianza,
      total_compra_esperado=p_total_esperado,
      saldo_confirmado=case
        when v_estado='SALDO_CONFIRMADO' then p_saldo_confirmado
        when v_estado in ('PAGO_RECONCILIADO','CERRADO','NO_ES_DEUDA') then 0
        else p_saldo_confirmado
      end,
      cotizacion_id=coalesce(v_target_quote,cotizacion_id),
      rol_pago=v_rol,
      observacion=nullif(trim(coalesce(p_observacion,'')),''),
      confirmado_por=v_actor,
      confirmed_at=now(),
      updated_at=now(),
      evidencia=evidencia||jsonb_build_object(
        'reviewed_at',now(),
        'previous',jsonb_build_object(
          'state',v_previous.estado_reconciliacion,
          'confidence',v_previous.confianza,
          'expected_total',v_previous.total_compra_esperado,
          'confirmed_balance',v_previous.saldo_confirmado,
          'quote_id',v_previous.cotizacion_id,
          'role',v_previous.rol_pago,
          'observation',v_previous.observacion,
          'updated_at',v_previous.updated_at
        )
      )
  where id=p_case_id;

  insert into public.aos_security_log(usuario,accion,detalles)
  select au.nombre,'CARTERA_CASE_RECONCILED',jsonb_build_object(
    'actor_id',v_actor,'case_id',p_case_id,
    'before',jsonb_build_object(
      'state',v_previous.estado_reconciliacion,
      'confidence',v_previous.confianza,
      'expected_total',v_previous.total_compra_esperado,
      'confirmed_balance',v_previous.saldo_confirmado,
      'quote_id',v_previous.cotizacion_id,
      'role',v_previous.rol_pago,
      'observation',v_previous.observacion,
      'updated_at',v_previous.updated_at
    ),
    'after',jsonb_build_object(
      'state',v_estado,'confidence',v_confianza,
      'expected_total',p_total_esperado,
      'confirmed_balance',case
        when v_estado='SALDO_CONFIRMADO' then p_saldo_confirmado
        when v_estado in ('PAGO_RECONCILIADO','CERRADO','NO_ES_DEUDA') then 0
        else p_saldo_confirmado end,
      'quote_id',coalesce(v_target_quote,v_previous.cotizacion_id),
      'role',v_rol,'observation',nullif(trim(coalesce(p_observacion,'')),'')
    )
  )
  from public.aos_usuarios au where au.id=v_actor;

  return jsonb_build_object('ok',true,'case_id',p_case_id,'status',v_estado);
end;
$function$;

create or replace function public.aos_caja_cotizaciones_gateway(
  p_token text,
  p_mode text,
  p_numero_limpio text default null,
  p_cotizacion_id text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid;
  v_level integer;
  v_allowed_sedes text[];
  v_mode text:=upper(trim(coalesce(p_mode,'')));
  v_numero text:=regexp_replace(coalesce(p_numero_limpio,''),'\D','','g');
  v_result jsonb;
begin
  if coalesce(length(p_token),0)<32 or v_mode not in ('LIST','DETAIL') then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_actor:=public.aos_cartera_actor(p_token,'admin-caja');
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
  from public.aos_usuarios au where au.id=v_actor;
  if v_level<>1 and cardinality(v_allowed_sedes)=0 then
    return jsonb_build_object('ok',false,'error','NO_ALLOWED_SEDE');
  end if;

  update public.aos_cia_admin_sessions
  set last_used_at=now()
  where user_id=v_actor and revoked=false;

  if v_mode='LIST' then
    if length(v_numero)<6 then
      return jsonb_build_object('ok',false,'error','INVALID_PATIENT_KEY');
    end if;
    select jsonb_build_object(
      'ok',true,
      'rows',coalesce(jsonb_agg(jsonb_build_object(
        'id',c.id,'numero_cotizacion',c.numero_cotizacion,
        'fecha_creacion',c.fecha_creacion,'plan_id',c.plan_id,
        'subtotal',c.subtotal,'saldo_pendiente',c.saldo_pendiente,
        'asesor',c.asesor,'origen',c.origen,'sede',c.sede
      ) order by c.created_at desc),'[]'::jsonb)
    ) into v_result
    from (
      select q.* from public.aos_cotizaciones q
      where regexp_replace(coalesce(q.numero_limpio,''),'\D','','g')=v_numero
        and q.estado not in ('ANULADO','PAGADO_COMPLETO')
        and coalesce(q.saldo_pendiente,0)>0
        and (v_level=1 or coalesce(upper(trim(coalesce(q.sede,'')))=any(v_allowed_sedes),false))
      order by q.created_at desc limit 10
    ) c;
    return v_result;
  end if;

  if nullif(trim(coalesce(p_cotizacion_id,'')),'') is null then
    return jsonb_build_object('ok',false,'error','QUOTE_REQUIRED');
  end if;
  select jsonb_build_object(
    'ok',true,
    'quote',jsonb_build_object(
      'id',c.id,'numero_cotizacion',c.numero_cotizacion,
      'numero_limpio',c.numero_limpio,'estado',c.estado,
      'subtotal',c.subtotal,'total_pagado',c.total_pagado,
      'saldo_pendiente',c.saldo_pendiente,'sede',c.sede,
      'asesor',c.asesor,'plan_id',c.plan_id,'origen',c.origen,
      'venta_id_origen',c.venta_legacy_id
    ),
    'items',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',i.id,'nombre',i.nombre,'descripcion',i.descripcion,
        'tipo',i.tipo,'cantidad',i.cantidad,'precio_unitario',i.precio_unitario,
        'subtotal',i.subtotal,'moneda',i.moneda,'created_at',i.created_at
      ) order by i.created_at,i.id)
      from public.aos_cotizacion_items i where i.cotizacion_id=c.id
    ),'[]'::jsonb)
  ) into v_result
  from public.aos_cotizaciones c
  where c.id=p_cotizacion_id
    and (v_level=1 or coalesce(upper(trim(coalesce(c.sede,'')))=any(v_allowed_sedes),false));
  if v_result is null then
    return jsonb_build_object('ok',false,'error','QUOTE_NOT_FOUND');
  end if;
  return v_result;
end;
$function$;

create or replace function public.aos_abonar_cotizacion_v2(
  p_token text,
  p_idempotency_key uuid,
  p_cotizacion_id text,
  p_monto numeric,
  p_metodo_pago text,
  p_tipo_comprobante text default 'BOLETA VIRTUAL',
  p_nro_doc text default '',
  p_nota text default '',
  p_sesion_id text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid;
  v_actor_name text;
  v_level integer;
  v_allowed_sedes text[];
  v_quote_sede text;
  v_cot record;
  v_existing record;
  v_cash record;
  v_name_matches integer;
  v_request_hash text;
  v_prev_pagado numeric;
  v_nuevo_pagado numeric;
  v_nuevo_saldo numeric;
  v_nuevo_estado text;
  v_venta_id text;
  v_venta_row_id bigint;
  v_pago_id text;
  v_fecha date;
  v_tratamiento text;
  v_rol text;
  v_estado_pago text;
begin
  if coalesce(length(p_token),0)<32 or p_idempotency_key is null then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_actor:=public.aos_cartera_actor(p_token,'admin-caja');
  if v_actor is null then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  select au.nombre,au.nivel_jerarquia,
         coalesce((
           select array_agg(upper(trim(s)))
           from unnest(coalesce(au.sedes_permitidas,'{}'::text[])) s
           where nullif(trim(s),'') is not null
         ),'{}'::text[])
    into v_actor_name,v_level,v_allowed_sedes
  from public.aos_usuarios au where au.id=v_actor;
  if v_level<>1 and cardinality(v_allowed_sedes)=0 then
    return jsonb_build_object('ok',false,'error','NO_ALLOWED_SEDE');
  end if;
  if p_cotizacion_id is null or coalesce(p_monto,0)<=0
     or round(p_monto,2)<>p_monto
     or trim(coalesce(p_metodo_pago,''))='' then
    return jsonb_build_object('ok',false,'error','INVALID_PAYMENT');
  end if;
  v_fecha:=(now() at time zone 'America/Lima')::date;
  v_request_hash:=encode(extensions.digest(jsonb_build_object(
    'actor_id',v_actor,'quote_id',p_cotizacion_id,'amount',p_monto,
    'payment_method',upper(trim(p_metodo_pago)),
    'receipt_type',upper(trim(coalesce(p_tipo_comprobante,''))),
    'document',trim(coalesce(p_nro_doc,'')),
    'note',trim(coalesce(p_nota,'')),
    'cash_session_id',trim(coalesce(p_sesion_id,''))
  )::text,'sha256'),'hex');

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_idempotency_key::text));

  select p.id,p.cotizacion_id,p.monto,p.metodo_pago,p.registrado_por_user_id,
         p.request_hash,p.cash_session_id
    into v_existing
  from public.aos_pagos p
  where p.request_id=p_idempotency_key;

  select * into v_cot
  from public.aos_cotizaciones
  where id=p_cotizacion_id
  for update;
  if v_cot.id is null then
    return jsonb_build_object('ok',false,'error','QUOTE_NOT_FOUND');
  end if;
  v_quote_sede:=upper(trim(coalesce(v_cot.sede,'')));
  if v_quote_sede not in ('SAN ISIDRO','PUEBLO LIBRE') then
    return jsonb_build_object('ok',false,'error','QUOTE_SEDE_INVALID');
  end if;
  if v_level<>1 and not coalesce(v_quote_sede=any(v_allowed_sedes),false) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_SEDE');
  end if;
  if nullif(trim(coalesce(p_sesion_id,'')),'') is null then
    return jsonb_build_object('ok',false,'error','INVALID_CASH_SESSION');
  end if;
  select cs.* into v_cash
  from public.aos_caja_sesiones cs
    where cs.id=p_sesion_id
  for update;
  if v_cash.id is null
     or upper(trim(coalesce(v_cash.sede,'')))<>v_quote_sede
     or upper(trim(coalesce(v_cash.estado,'')))<>'ABIERTA'
     or v_cash.fecha<>v_fecha then
    return jsonb_build_object('ok',false,'error','INVALID_CASH_SESSION');
  end if;
  if v_cash.abierto_por_user_id is null then
    select count(*) into v_name_matches
    from public.aos_usuarios au
    where au.activo=true and lower(trim(coalesce(au.nombre,'')))=lower(trim(v_actor_name));
    if v_name_matches<>1
       or lower(trim(coalesce(v_cash.abierto_por,'')))<>lower(trim(v_actor_name)) then
      return jsonb_build_object('ok',false,'error','CASH_SESSION_OWNER_UNVERIFIED');
    end if;
    update public.aos_caja_sesiones
    set abierto_por_user_id=v_actor,updated_at=now()
    where id=v_cash.id and abierto_por_user_id is null;
    v_cash.abierto_por_user_id:=v_actor;
  end if;
  if v_cash.abierto_por_user_id<>v_actor then
    return jsonb_build_object('ok',false,'error','INVALID_CASH_SESSION');
  end if;

  if v_existing.id is not null then
    if v_existing.cotizacion_id<>p_cotizacion_id
       or v_existing.registrado_por_user_id<>v_actor
       or v_existing.request_hash<>v_request_hash
       or v_existing.cash_session_id<>p_sesion_id then
      return jsonb_build_object('ok',false,'error','IDEMPOTENCY_CONFLICT');
    end if;
    return jsonb_build_object(
      'ok',true,'replay',true,'cotizacion_id',v_cot.id,
      'numero',v_cot.numero_cotizacion,'monto_abonado',v_existing.monto,
      'total_pagado',v_cot.total_pagado,'saldo',v_cot.saldo_pendiente,
      'estado',v_cot.estado,'pago_id',v_existing.id
    );
  end if;
  if v_cot.estado in ('ANULADO','PAGADO_COMPLETO') then
    return jsonb_build_object('ok',false,'error','QUOTE_NOT_PAYABLE');
  end if;

  v_prev_pagado:=greatest(coalesce(v_cot.total_pagado,0),0);
  v_nuevo_saldo:=greatest(coalesce(v_cot.subtotal,0)-v_prev_pagado,0);
  if v_nuevo_saldo<=0 then
    return jsonb_build_object('ok',false,'error','QUOTE_WITHOUT_BALANCE');
  end if;
  if p_monto>v_nuevo_saldo then
    return jsonb_build_object('ok',false,'error','OVERPAYMENT','max_amount',v_nuevo_saldo);
  end if;

  v_nuevo_pagado:=v_prev_pagado+p_monto;
  v_nuevo_saldo:=greatest(coalesce(v_cot.subtotal,0)-v_nuevo_pagado,0);
  v_nuevo_estado:=case when v_nuevo_saldo=0 then 'PAGADO_COMPLETO' else 'PAGADO_PARCIAL' end;
  v_estado_pago:=case when v_nuevo_estado='PAGADO_COMPLETO' then 'PAGO COMPLETO' else 'ADELANTO' end;
  v_rol:=case
    when v_prev_pagado=0 and v_nuevo_saldo=0 then 'UNICO'
    when v_prev_pagado=0 then 'ADELANTO'
    when v_nuevo_saldo=0 then 'SALDO'
    else 'COMPLEMENTO'
  end;

  select coalesce(nullif(trim(nombre),''),nullif(trim(descripcion),''),'Servicio')
  into v_tratamiento
  from public.aos_cotizacion_items
  where cotizacion_id=p_cotizacion_id
  order by created_at,id
  limit 1;
  v_tratamiento:=coalesce(v_tratamiento,'Servicio');

  update public.aos_cotizaciones
  set total_pagado=v_nuevo_pagado,
      saldo_pendiente=v_nuevo_saldo,
      estado=v_nuevo_estado,
      fecha_pago_completo=case when v_nuevo_saldo=0 then v_fecha else fecha_pago_completo end,
      updated_at=now()
  where id=p_cotizacion_id;

  insert into public.aos_pagos(
    id,cotizacion_id,monto,moneda,metodo_pago,tipo_comprobante,
    numero_comprobante,sede,registrado_por,registrado_por_user_id,fecha_pago,
    nota,asesor_comision,request_id,request_hash,cash_session_id
  ) values (
    extensions.gen_random_uuid()::text,p_cotizacion_id,p_monto,'PEN',p_metodo_pago,
    p_tipo_comprobante,p_nro_doc,v_quote_sede,v_actor_name,v_actor,v_fecha,p_nota,
    coalesce(v_cot.asesor,''),p_idempotency_key,v_request_hash,p_sesion_id
  ) returning id into v_pago_id;

  v_venta_id:='V-'||to_char(now() at time zone 'America/Lima','YYYYMMDD-HH24MISS')||'-'||
              substr(extensions.gen_random_uuid()::text,1,4);

  insert into public.aos_ventas(
    venta_id,fecha,nombres,apellidos,dni,celular,tratamiento,descripcion,
    pago,monto,estado_pago,asesor,sede,tipo,numero_limpio,moneda,nro_doc,
    tipo_comprobante,cotizacion_id,plan_id,created_at,updated_at
  ) values (
    v_venta_id,v_fecha,v_cot.nombre_paciente,'',v_cot.dni_paciente,v_cot.numero_limpio,
    v_tratamiento,
    case when v_rol='SALDO' then 'Saldo' when v_rol='UNICO' then 'Pago' else 'Abono' end||
      ' #'||v_cot.numero_cotizacion||' — '||v_tratamiento,
    p_metodo_pago,p_monto,v_estado_pago,coalesce(v_cot.asesor,''),v_quote_sede,
    'SERVICIO',v_cot.numero_limpio,'PEN',p_nro_doc,p_tipo_comprobante,
    p_cotizacion_id,v_cot.plan_id,now(),now()
  ) returning id into v_venta_row_id;

  insert into public.aos_cartera_reconciliacion(
    source_type,venta_row_id,cotizacion_id,pago_id,rol_pago,
    estado_reconciliacion,confianza,monto_registrado,total_compra_esperado,
    saldo_confirmado,evidencia,source_active
  ) values (
    'VENTA',v_venta_row_id,p_cotizacion_id,v_pago_id,v_rol,
    case when v_nuevo_saldo=0 then 'PAGO_RECONCILIADO' else 'PENDIENTE_RECONCILIAR' end,
    case when v_nuevo_saldo=0 then 'CONFIRMADA' else 'ALTA' end,
    p_monto,v_cot.subtotal,
    case when v_nuevo_saldo=0 then 0 else null end,
    jsonb_build_object(
      'source','aos_abonar_cotizacion_v2','quote_locked',true,
      'payment_id',v_pago_id,'balance_after',v_nuevo_saldo
    ),true
  )
  on conflict (venta_row_id) where source_type='VENTA' do update
  set cotizacion_id=excluded.cotizacion_id,pago_id=excluded.pago_id,
      rol_pago=excluded.rol_pago,
      estado_reconciliacion=excluded.estado_reconciliacion,
      confianza=excluded.confianza,
      total_compra_esperado=excluded.total_compra_esperado,
      saldo_confirmado=excluded.saldo_confirmado,
      evidencia=public.aos_cartera_reconciliacion.evidencia||excluded.evidencia,
      source_active=true,updated_at=now();

  insert into public.aos_caja_log(
    sesion_id,sede,accion,entidad_tipo,entidad_id,usuario,detalle,monto_despues
  ) values (
    p_sesion_id,v_quote_sede,'ABONO_COTIZACION','cotizacion',p_cotizacion_id,
    v_actor_name,v_tratamiento||' — '||v_rol||' #'||v_cot.numero_cotizacion||' S/'||p_monto,
    p_monto
  );

  insert into public.aos_security_log(usuario,accion,detalles)
  select au.nombre,'COTIZACION_PAYMENT_V2',jsonb_build_object(
    'actor_id',v_actor,'cotizacion_id',p_cotizacion_id,'payment_id',v_pago_id,
    'venta_row_id',v_venta_row_id,'request_id',p_idempotency_key,
    'amount',p_monto,'role',v_rol,'balance_after',v_nuevo_saldo,
    'sede',v_quote_sede,'cash_session_id',p_sesion_id
  ) from public.aos_usuarios au where au.id=v_actor;

  return jsonb_build_object(
    'ok',true,'cotizacion_id',p_cotizacion_id,'numero',v_cot.numero_cotizacion,
    'monto_abonado',p_monto,'total_pagado',v_nuevo_pagado,
    'saldo',v_nuevo_saldo,
    'estado',v_nuevo_estado,'venta_id',v_venta_id,'venta_row_id',v_venta_row_id,
    'pago_id',v_pago_id,'rol_pago',v_rol,'lineas',1,'tratamiento',v_tratamiento
  );
end;
$function$;

-- El contrato legacy queda disponible solo para service_role durante el canary.
revoke all on function public.aos_abonar_cotizacion(
  text,numeric,text,text,text,text,text,text,text,text,text
) from public,anon,authenticated;
grant execute on function public.aos_abonar_cotizacion(
  text,numeric,text,text,text,text,text,text,text,text,text
) to service_role;

revoke all on function public.aos_cartera_sync_venta() from public,anon,authenticated;
revoke all on function public.aos_cartera_sync_cotizacion() from public,anon,authenticated;
revoke all on function public.aos_cartera_actor(text,text) from public,anon,authenticated;
revoke all on function public.aos_cartera_gateway(text,text,text,integer,integer) from public;
revoke all on function public.aos_cartera_reconcile(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text) from public;
revoke all on function public.aos_caja_cotizaciones_gateway(text,text,text,text) from public;
revoke all on function public.aos_abonar_cotizacion_v2(
  text,uuid,text,numeric,text,text,text,text,text
) from public;

grant execute on function public.aos_cartera_gateway(text,text,text,integer,integer)
  to anon,authenticated,service_role;
grant execute on function public.aos_cartera_reconcile(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text)
  to anon,authenticated,service_role;
grant execute on function public.aos_caja_cotizaciones_gateway(text,text,text,text)
  to anon,authenticated,service_role;
grant execute on function public.aos_abonar_cotizacion_v2(
  text,uuid,text,numeric,text,text,text,text,text
) to anon,authenticated,service_role;

commit;
