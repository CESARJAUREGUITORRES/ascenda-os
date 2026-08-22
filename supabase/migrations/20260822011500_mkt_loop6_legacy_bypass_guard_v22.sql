-- Loop 6 V2.2: fail closed legacy Call Center writes and mark governed transactions.

insert into public.aos_loop6_function_backups_v1(backup_key,function_name,function_args,definition)
select '20260821_legacy_bypass_guard_v22',p.proname,pg_get_function_identity_arguments(p.oid),pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prokind='f' and p.proname='aos_callcenter_commit_action_core_v1'
on conflict do nothing;

create or replace function public.aos_loop6_require_governed_call_v22()
returns trigger
language plpgsql security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
begin
  if upper(coalesce(new.estado,''))='CITA CONFIRMADA'
     and upper(coalesce(new.tipo_gestion,'LLAMADA')) <> 'INFERIDA_HISTORICA'
     and coalesce(pg_catalog.current_setting('aos.loop6_governed_write',true),'') <> '1' then
    raise exception using errcode='P0001',
      message='AOS_LOOP6_RUNTIME_REQUIRED',
      detail='Call Center actualizado requerido. Recarga ASCENDA antes de registrar una cita comercial.';
  end if;
  return new;
end
$function$;

create or replace function public.aos_loop6_require_governed_agenda_v22()
returns trigger
language plpgsql security definer
set search_path to 'pg_catalog','public','pg_temp'
as $function$
declare v_origin text:=upper(coalesce(new.origen_cita,''));
begin
  if (v_origin='CITA_MANUAL' or v_origin like 'CALL_CENTER%')
     and coalesce(pg_catalog.current_setting('aos.loop6_governed_write',true),'') <> '1' then
    raise exception using errcode='P0001',
      message='AOS_LOOP6_RUNTIME_REQUIRED',
      detail='Call Center actualizado requerido. Recarga ASCENDA antes de registrar una cita desde este panel.';
  end if;
  return new;
end
$function$;

revoke all on function public.aos_loop6_require_governed_call_v22() from public,anon,authenticated;
revoke all on function public.aos_loop6_require_governed_agenda_v22() from public,anon,authenticated;

drop trigger if exists trg_000_aos_loop6_governed_call_v22 on public.aos_llamadas;
create trigger trg_000_aos_loop6_governed_call_v22
before insert on public.aos_llamadas
for each row execute function public.aos_loop6_require_governed_call_v22();

drop trigger if exists trg_000_aos_loop6_governed_agenda_v22 on public.aos_agenda_citas;
create trigger trg_000_aos_loop6_governed_agenda_v22
before insert on public.aos_agenda_citas
for each row execute function public.aos_loop6_require_governed_agenda_v22();

create or replace function public.aos_callcenter_commit_action_core_v1(
  p_actor uuid,p_idempotency_key text,p_action_type text,p_payload jsonb,p_test_fail_stage text default null
) returns jsonb
language plpgsql security definer
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

  v_hash:=pg_catalog.encode(extensions.digest(v_action||'|'||(v_payload-'event_ts'-'business_date')::text,'sha256'),'hex');
  select * into v_existing from public.aos_callcenter_actions_v1 a where a.idempotency_key=v_key;
  if found then
    if v_existing.actor_user_id<>p_actor then return pg_catalog.jsonb_build_object('ok',false,'error','IDEMPOTENCY_ACTOR_CONFLICT'); end if;
    if v_existing.request_hash<>v_hash then return pg_catalog.jsonb_build_object('ok',false,'error','IDEMPOTENCY_CONFLICT'); end if;
    if v_existing.status='COMPLETE' and v_existing.result is not null then return v_existing.result||pg_catalog.jsonb_build_object('idempotent',true); end if;
    return pg_catalog.jsonb_build_object('ok',false,'error','ACTION_IN_PROGRESS');
  end if;

  perform pg_catalog.set_config('aos.loop6_governed_write','1',true);
  return public.aos_callcenter_commit_action_core_impl_v2(p_actor,p_idempotency_key,p_action_type,p_payload,p_test_fail_stage);
end
$function$;

revoke all on function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text) to service_role;
