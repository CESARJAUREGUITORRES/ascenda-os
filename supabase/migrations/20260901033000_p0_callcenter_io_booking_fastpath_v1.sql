-- ASCENDA OS · P0 Call Center IO / booking fast-path V1
-- Goal: preserve attribution/ownership semantics while preventing Call Center
-- requests from materializing the complete marketing touchpoint timeline for a
-- single phone. The scope is transaction-local and therefore invisible to all
-- reporting/marketing callers.

-- ---------------------------------------------------------------------------
-- A. Marketing touchpoints: optional transaction-local phone scope.
-- ---------------------------------------------------------------------------
create or replace function public.aos_marketing_touchpoints_v2(
  p_desde date default null::date,
  p_hasta date default null::date
)
returns table(
  lead_id bigint,
  numero_limpio text,
  fecha date,
  hora_ingreso timestamp with time zone,
  tratamiento text,
  anuncio text,
  lead_ts timestamp with time zone,
  next_lead_ts timestamp with time zone,
  es_duplicado_tecnico_probable boolean,
  duplicate_rank bigint
)
language sql
stable
set search_path = 'pg_catalog','public','pg_temp'
as $function$
with scope as (
  select pg_catalog.regexp_replace(
    coalesce(pg_catalog.current_setting('aos.callcenter_phone',true),''),
    '[^0-9]','','g'
  ) as phone
), base as (
  select l.*,
         public.aos_lead_event_ts(l.fecha,l.hora_ingreso,l.created_at) as _lead_ts,
         row_number() over(
           partition by l.numero_limpio,l.fecha,l.hora_ingreso,coalesce(l.tratamiento,''),coalesce(l.anuncio,''),l.created_at
           order by l.id
         ) as _dup_rank
  from public.aos_leads l
  cross join scope s
  where l.numero_limpio is not null
    and l.numero_limpio<>''
    and (s.phone='' or l.numero_limpio=s.phone)
), timeline as (
  select b.*,
         lead(b._lead_ts) over(partition by b.numero_limpio order by b._lead_ts,b.id) as _next_lead_ts
  from base b
  where b._dup_rank=1
)
select b.id::bigint,b.numero_limpio,b.fecha,b.hora_ingreso,b.tratamiento,b.anuncio,b._lead_ts,
       case when b._dup_rank=1 then t._next_lead_ts else null end,
       (b._dup_rank>1),b._dup_rank::bigint
from base b
left join timeline t on t.id=b.id
where (p_desde is null or b.fecha>=p_desde)
  and (p_hasta is null or b.fecha<=p_hasta)
order by b.fecha,b._lead_ts,b.id;
$function$;

-- ---------------------------------------------------------------------------
-- B. Governed Call Center core: set the phone scope before entering the
-- existing V2 implementation. Idempotency, ownership and business policy are
-- otherwise byte-for-byte equivalent to the certified core wrapper.
-- ---------------------------------------------------------------------------
create or replace function public.aos_callcenter_commit_action_core_v1(
  p_actor uuid,
  p_idempotency_key text,
  p_action_type text,
  p_payload jsonb,
  p_test_fail_stage text default null::text
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare
  v_key text:=pg_catalog.btrim(coalesce(p_idempotency_key,''));
  v_action text:=upper(pg_catalog.btrim(coalesce(p_action_type,'')));
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_source_mode text:=upper(pg_catalog.btrim(coalesce(v_payload->>'source_mode','QUEUE')));
  v_num text:=pg_catalog.regexp_replace(coalesce(v_payload->>'numero',''),'[^0-9]','','g');
  v_hash text;
  v_existing record;
begin
  if p_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if pg_catalog.length(v_key)<16 or pg_catalog.length(v_key)>160 then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_IDEMPOTENCY_KEY'); end if;
  if v_action not in ('COMMERCIAL_CALL_APPOINTMENT','CALLBACK_INBOUND_APPOINTMENT','REACTIVATION','PATIENT_FOLLOWUP','AGENDA_ONLY') then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ACTION'); end if;
  if v_source_mode not in ('QUEUE','MANUAL','CALLBACK','FOLLOWUP') then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_SOURCE_MODE'); end if;
  if pg_catalog.length(v_num)<7 then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_PHONE'); end if;

  -- Critical P0 fast-path: every aos_marketing_touchpoints_v2(NULL,NULL)
  -- reached by the implementation now sees only this phone for this xact.
  perform pg_catalog.set_config('aos.callcenter_phone',v_num,true);

  v_hash:=pg_catalog.encode(extensions.digest(v_action||'|'||(v_payload-'event_ts'-'business_date')::text,'sha256'),'hex');
  select * into v_existing from public.aos_callcenter_actions_v1 a where a.idempotency_key=v_key;
  if found then
    if v_existing.actor_user_id<>p_actor then return pg_catalog.jsonb_build_object('ok',false,'error','IDEMPOTENCY_ACTOR_CONFLICT'); end if;
    if v_existing.request_hash<>v_hash then return pg_catalog.jsonb_build_object('ok',false,'error','IDEMPOTENCY_CONFLICT'); end if;
    if v_existing.status='COMPLETE' and v_existing.result is not null then return v_existing.result||pg_catalog.jsonb_build_object('idempotent',true); end if;
    return pg_catalog.jsonb_build_object('ok',false,'error','ACTION_IN_PROGRESS');
  end if;
  perform pg_catalog.set_config('aos.loop6_governed_write','1',true);
  return public.aos_callcenter_commit_action_core_impl_v2(p_actor,p_idempotency_key,p_action_type,v_payload,p_test_fail_stage);
end
$function$;

-- Queue validation happens before the generic core, so scope it in the public
-- governed wrapper as well.
create or replace function public.aos_callcenter_confirm_queue_appointment_v1(
  p_token text,
  p_idempotency_key text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid;
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_num text:=pg_catalog.regexp_replace(coalesce(v_payload->>'numero',''),'[^0-9]','','g');
begin
  v_actor:=public.aos_app_actor_v3(p_token,'advisor-calls',false);
  if v_actor is null then
    v_actor:=public.aos_app_actor_v3(p_token,'admin-calls',true);
  end if;
  if v_actor is null then
    return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  if pg_catalog.length(v_num)>=7 then
    perform pg_catalog.set_config('aos.callcenter_phone',v_num,true);
  end if;
  v_payload:=(v_payload-'event_ts'-'business_date')
    || pg_catalog.jsonb_build_object('event_ts',pg_catalog.now());
  return public.aos_callcenter_confirm_queue_core_v1(v_actor,p_idempotency_key,v_payload,null);
end
$function$;

-- ---------------------------------------------------------------------------
-- C. Hot-path expression indexes. Existing indexes are case-sensitive while
-- the legacy panel RPCs intentionally compare UPPER(asesor).
-- ---------------------------------------------------------------------------
create index if not exists idx_aos_llamadas_upper_asesor_fecha_v1
  on public.aos_llamadas ((upper(asesor)),fecha);
create index if not exists idx_aos_agenda_upper_asesor_fecha_v1
  on public.aos_agenda_citas ((upper(asesor)),fecha_cita);
create index if not exists idx_aos_ventas_upper_asesor_fecha_v1
  on public.aos_ventas ((upper(asesor)),fecha);

comment on function public.aos_marketing_touchpoints_v2(date,date) is
  'Marketing attribution authority. Optional transaction-local aos.callcenter_phone scope is reserved for governed Call Center fast-paths; reporting semantics are unchanged when unset.';
