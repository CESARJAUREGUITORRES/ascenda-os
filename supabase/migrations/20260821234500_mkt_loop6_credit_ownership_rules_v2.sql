-- ASCENDA OS · MKT-INTEGRITY-HOTFIX-V3 · LOOP 6
-- Credit/ownership hardening: 15-day reactivation, 72h no-show ownership,
-- active-appointment duplicate guard, executed_by vs credited_advisor, policy audit.

create table if not exists public.aos_loop6_function_backups_v1 (
  backup_key text not null,
  function_name text not null,
  function_args text not null,
  definition text not null,
  captured_at timestamptz not null default now(),
  primary key (backup_key,function_name,function_args)
);
revoke all on public.aos_loop6_function_backups_v1 from public,anon,authenticated;
grant select,insert on public.aos_loop6_function_backups_v1 to service_role;

insert into public.aos_loop6_function_backups_v1(backup_key,function_name,function_args,definition)
select '20260821_credit_rules_v2',p.proname,pg_get_function_identity_arguments(p.oid),pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prokind='f' and p.proname in (
  'aos_callcenter_prepare_action_v1','aos_callcenter_commit_action_core_v1',
  'aos_hotfix_call_guard_v1','aos_hotfix_manual_agenda_cleanup_v1'
)
on conflict do nothing;

alter table public.aos_callcenter_actions_v1
  add column if not exists credited_advisor text,
  add column if not exists credited_advisor_id text,
  add column if not exists commercial_owner text,
  add column if not exists commercial_owner_id text,
  add column if not exists beneficiary_scope text,
  add column if not exists eligibility_status text,
  add column if not exists eligibility_reason text,
  add column if not exists prior_agenda_id text,
  add column if not exists prior_advisor text,
  add column if not exists prior_advisor_id text,
  add column if not exists ownership_transfer boolean not null default false,
  add column if not exists rule_context jsonb;

create table if not exists public.aos_callcenter_policy_events_v1 (
  event_id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null,
  executed_by text not null,
  executed_by_id text,
  numero_limpio text not null,
  requested_action text not null,
  decision text not null,
  reason text,
  credited_advisor text,
  credited_advisor_id text,
  commercial_owner text,
  commercial_owner_id text,
  beneficiary_scope text,
  context jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_aos_callcenter_policy_events_v1_num
  on public.aos_callcenter_policy_events_v1(numero_limpio,created_at desc);
create index if not exists idx_aos_callcenter_policy_events_v1_actor
  on public.aos_callcenter_policy_events_v1(actor_user_id,created_at desc);
revoke all on public.aos_callcenter_policy_events_v1 from public,anon,authenticated;
grant select,insert on public.aos_callcenter_policy_events_v1 to service_role;

create or replace function public.aos_callcenter_try_timestamptz_v1(p_value text)
returns timestamptz
language plpgsql immutable
set search_path=''
as $function$
begin
  if nullif(pg_catalog.btrim(coalesce(p_value,'')),'') is null then return null; end if;
  return p_value::timestamptz;
exception when others then return null;
end
$function$;
revoke all on function public.aos_callcenter_try_timestamptz_v1(text) from public,anon,authenticated;
grant execute on function public.aos_callcenter_try_timestamptz_v1(text) to service_role;

create or replace function public.aos_callcenter_agenda_slot_v1(p_fecha date,p_hora text)
returns timestamptz
language plpgsql immutable
set search_path=''
as $function$
declare v_time time;
begin
  if p_fecha is null then return null; end if;
  begin
    v_time:=nullif(pg_catalog.btrim(coalesce(p_hora,'')),'')::time;
  exception when others then
    v_time:='00:00'::time;
  end;
  if v_time is null then v_time:='00:00'::time; end if;
  return (p_fecha::timestamp+v_time) at time zone 'America/Lima';
end
$function$;
revoke all on function public.aos_callcenter_agenda_slot_v1(date,text) from public,anon,authenticated;
grant execute on function public.aos_callcenter_agenda_slot_v1(date,text) to service_role;

create or replace function public.aos_callcenter_credit_context_v2(
  p_numero text,
  p_event_ts timestamptz default now()
) returns jsonb
language plpgsql stable security definer
set search_path=''
as $function$
declare
  v_num text:=pg_catalog.regexp_replace(coalesce(p_numero,''),'[^0-9]','','g');
  v_event timestamptz:=coalesce(p_event_ts,pg_catalog.now());
  v_day date:=(v_event at time zone 'America/Lima')::date;
  v_state jsonb;
  v_last_qual_ts timestamptz;
  v_last_qual_type text;
  v_reactivation_from timestamptz;
  v_active record;
  v_no_show record;
  v_no_show_slot timestamptz;
  v_protected_until timestamptz;
  v_owner_followup boolean:=false;
begin
  v_state:=public.aos_callcenter_patient_state_v1(v_num,v_event);
  if coalesce((v_state->>'ok')::boolean,false)=false then return v_state; end if;

  select q.ts,q.kind into v_last_qual_ts,v_last_qual_type
  from (
    select (v.fecha::timestamp at time zone 'America/Lima') ts,'SALE'::text kind
    from public.aos_ventas v
    where v.numero_limpio=v_num and v.fecha<=v_day
    union all
    select (a.fecha::timestamp at time zone 'America/Lima'),'ATTENTION'
    from public.aos_atenciones a
    where a.numero_limpio=v_num and a.fecha<=v_day
    union all
    select public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita),'ATTENDED_APPOINTMENT'
    from public.aos_agenda_citas a
    where a.numero_limpio=v_num
      and upper(coalesce(a.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA')
      and public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita)<=v_event
  ) q
  where q.ts<=v_event
  order by q.ts desc nulls last limit 1;
  if v_last_qual_ts is not null then v_reactivation_from:=v_last_qual_ts+interval '15 days'; end if;

  select a.id,a.asesor,a.id_asesor,a.fecha_cita,a.hora_cita,a.estado_cita,a.lead_id_origen,
         public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) slot
  into v_active
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('PENDIENTE','CITA CONFIRMADA')
    and a.fecha_cita>=v_day
  order by public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) asc,a.ts_creado asc nulls last
  limit 1;

  select a.id,a.asesor,a.id_asesor,a.fecha_cita,a.hora_cita,a.estado_cita,a.lead_id_origen,
         public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) slot
  into v_no_show
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('NO ASISTIO','NO ASISTIÓ')
    and public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita)<v_event
  order by public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) desc,a.ts_creado desc nulls last
  limit 1;

  if v_no_show.id is not null then
    v_no_show_slot:=v_no_show.slot;
    v_protected_until:=v_no_show_slot+interval '72 hours';
    select exists(
      select 1 from public.aos_llamadas l
      where l.numero_limpio=v_num
        and upper(coalesce(l.asesor,''))=upper(coalesce(v_no_show.asesor,''))
        and public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)>v_no_show_slot
        and public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)<v_event
    ) or exists(
      select 1 from public.aos_seguimientos s
      where pg_catalog.regexp_replace(coalesce(s."NUMERO",''),'[^0-9]','','g')=v_num
        and upper(coalesce(s."ASESOR",''))=upper(coalesce(v_no_show.asesor,''))
        and (
          public.aos_callcenter_try_timestamptz_v1(s."TS_CREADO")>v_no_show_slot
          or (
            upper(coalesce(s."ESTADO",''))='COMPLETADO'
            and public.aos_callcenter_try_timestamptz_v1(s."TS_ACTUALIZADO")>v_no_show_slot
          )
        )
        and coalesce(public.aos_callcenter_try_timestamptz_v1(s."TS_CREADO"),public.aos_callcenter_try_timestamptz_v1(s."TS_ACTUALIZADO"))<v_event
    ) into v_owner_followup;
  end if;

  return v_state||pg_catalog.jsonb_build_object(
    'creditPolicy',pg_catalog.jsonb_build_object(
      'lastQualifyingTs',v_last_qual_ts,
      'lastQualifyingType',v_last_qual_type,
      'reactivationEligibleFrom',v_reactivation_from,
      'reactivationEligible',case when coalesce((v_state->>'converted')::boolean,false) and v_reactivation_from is not null then v_event>=v_reactivation_from else false end,
      'activeAppointment',case when v_active.id is null then null else pg_catalog.jsonb_build_object(
        'id',v_active.id,'advisor',v_active.asesor,'advisorId',v_active.id_asesor,
        'date',v_active.fecha_cita,'time',v_active.hora_cita,'status',v_active.estado_cita,'slot',v_active.slot,'leadId',v_active.lead_id_origen
      ) end,
      'lastNoShow',case when v_no_show.id is null then null else pg_catalog.jsonb_build_object(
        'id',v_no_show.id,'advisor',v_no_show.asesor,'advisorId',v_no_show.id_asesor,
        'date',v_no_show.fecha_cita,'time',v_no_show.hora_cita,'slot',v_no_show_slot,'leadId',v_no_show.lead_id_origen,
        'protectedUntil',v_protected_until,'ownerFollowupAfterNoShow',v_owner_followup
      ) end
    )
  );
end
$function$;
revoke all on function public.aos_callcenter_credit_context_v2(text,timestamptz) from public,anon,authenticated;
grant execute on function public.aos_callcenter_credit_context_v2(text,timestamptz) to service_role;

create or replace function public.aos_callcenter_policy_log_v1(
  p_actor uuid,p_numero text,p_action text,p_decision text,p_reason text,
  p_credited text,p_credited_id text,p_owner text,p_owner_id text,p_beneficiary text,p_context jsonb
) returns void
language plpgsql security definer
set search_path=''
as $function$
declare v_user record;v_num text:=pg_catalog.regexp_replace(coalesce(p_numero,''),'[^0-9]','','g');
begin
  select u.nombre,u.codigo_asesor into v_user from public.aos_usuarios u where u.id=p_actor limit 1;
  insert into public.aos_callcenter_policy_events_v1(
    actor_user_id,executed_by,executed_by_id,numero_limpio,requested_action,decision,reason,
    credited_advisor,credited_advisor_id,commercial_owner,commercial_owner_id,beneficiary_scope,context
  ) values(
    p_actor,upper(coalesce(v_user.nombre,'')),v_user.codigo_asesor,v_num,p_action,p_decision,p_reason,
    p_credited,p_credited_id,p_owner,p_owner_id,p_beneficiary,coalesce(p_context,'{}'::jsonb)
  );
end
$function$;
revoke all on function public.aos_callcenter_policy_log_v1(uuid,text,text,text,text,text,text,text,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.aos_callcenter_policy_log_v1(uuid,text,text,text,text,text,text,text,text,text,jsonb) to service_role;

create or replace function public.aos_callcenter_prepare_action_v1(p_token text,p_numero text)
returns jsonb
language plpgsql stable security definer
set search_path=''
as $function$
declare v_actor uuid;v_state jsonb;v_user record;v_allowed jsonb;
begin
  v_actor:=public.aos_app_actor_v3(p_token,'advisor-calls',false);
  if v_actor is null then v_actor:=public.aos_app_actor_v3(p_token,'admin-calls',true); end if;
  if v_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  select u.nombre,u.apellidos,u.codigo_asesor,u.rol into v_user from public.aos_usuarios u where u.id=v_actor and u.activo=true limit 1;
  v_state:=public.aos_callcenter_credit_context_v2(p_numero,pg_catalog.now());
  if coalesce((v_state->>'ok')::boolean,false)=false then
    return v_state||pg_catalog.jsonb_build_object('actorUserId',v_actor,'asesor',upper(coalesce(v_user.nombre,'')),'idAsesor',v_user.codigo_asesor);
  end if;
  if v_state->>'patientState'='CONVERTED_PATIENT' then
    v_allowed:='["REACTIVATION","PATIENT_FOLLOWUP","AGENDA_ONLY"]'::jsonb;
  else
    v_allowed:='["COMMERCIAL_CALL_APPOINTMENT","CALLBACK_INBOUND_APPOINTMENT","AGENDA_ONLY"]'::jsonb;
  end if;
  return v_state||pg_catalog.jsonb_build_object(
    'actorUserId',v_actor,'asesor',upper(coalesce(v_user.nombre,'')),'idAsesor',v_user.codigo_asesor,'allowedActions',v_allowed
  );
end
$function$;
revoke all on function public.aos_callcenter_prepare_action_v1(text,text) from public;
grant execute on function public.aos_callcenter_prepare_action_v1(text,text) to anon,authenticated,service_role;

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
  v_event_ts timestamptz:=coalesce(nullif(v_payload->>'event_ts','')::timestamptz,pg_catalog.now());
  v_day date:=(v_event_ts at time zone 'America/Lima')::date;
  v_hash text;v_inserted boolean:=false;v_existing record;v_user record;v_ctx jsonb;v_policy jsonb;
  v_patient_state text;v_identity_status text;v_canonical text;v_is_converted boolean:=false;
  v_active jsonb;v_no_show jsonb;v_active_id text;v_no_show_id text;v_no_show_owner text;v_no_show_owner_id text;
  v_protected_until timestamptz;v_owner_followup boolean:=false;v_same_owner boolean:=false;
  v_reactivation_from timestamptz;v_reactivation_eligible boolean:=false;
  v_effective_action text;v_decision text:='ALLOW';v_reason text:='Eligible action';
  v_need_call boolean:=false;v_need_agenda boolean:=false;v_call_state text;v_sub_state text;v_tipo_gestion text;
  v_origin text;v_agenda_origin text;v_beneficiary text:='ADVISOR';
  v_credited text;v_credited_id text;v_owner text;v_owner_id text;v_transfer boolean:=false;
  v_lead_id bigint;v_lead_anuncio text;v_lead_trat text;v_explicit_lead bigint;v_prior_count integer:=0;v_match_count integer:=0;
  v_treatment text:=pg_catalog.btrim(coalesce(v_payload->>'tratamiento',''));v_attempt integer:=1;
  v_call_id bigint;v_call_actual_state text;v_call_actual_type text;v_call_actual_origin text;v_call_actual_lead bigint;
  v_agenda_id text;v_fecha_cita date;v_hora_cita text;v_result jsonb;v_fail text:=upper(pg_catalog.btrim(coalesce(p_test_fail_stage,'')));
  v_agenda_advisor text;v_agenda_advisor_id text;v_agenda_lead bigint;
begin
  if p_actor is null then return pg_catalog.jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if pg_catalog.length(v_key)<16 or pg_catalog.length(v_key)>160 then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_IDEMPOTENCY_KEY'); end if;
  if v_action not in ('COMMERCIAL_CALL_APPOINTMENT','CALLBACK_INBOUND_APPOINTMENT','REACTIVATION','PATIENT_FOLLOWUP','AGENDA_ONLY') then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ACTION'); end if;
  if v_source_mode not in ('QUEUE','MANUAL','CALLBACK','FOLLOWUP') then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_SOURCE_MODE'); end if;
  if pg_catalog.length(v_num)<7 then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_PHONE'); end if;

  select u.nombre,u.apellidos,u.codigo_asesor,u.rol,u.paneles_acceso into v_user from public.aos_usuarios u where u.id=p_actor and u.activo=true limit 1;
  if v_user.nombre is null or v_user.codigo_asesor is null then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_ACTOR'); end if;
  v_credited:=upper(v_user.nombre);v_credited_id:=v_user.codigo_asesor;v_owner:=upper(v_user.nombre);v_owner_id:=v_user.codigo_asesor;
  v_agenda_advisor:=upper(v_user.nombre);v_agenda_advisor_id:=v_user.codigo_asesor;

  v_ctx:=public.aos_callcenter_credit_context_v2(v_num,v_event_ts);
  if coalesce((v_ctx->>'ok')::boolean,false)=false then return v_ctx; end if;
  v_patient_state:=v_ctx->>'patientState';v_identity_status:=v_ctx->>'identityStatus';v_canonical:=v_ctx->>'canonicalPatientId';
  v_is_converted:=coalesce((v_ctx->>'converted')::boolean,false);v_policy:=coalesce(v_ctx->'creditPolicy','{}'::jsonb);
  v_active:=v_policy->'activeAppointment';v_no_show:=v_policy->'lastNoShow';v_active_id:=v_active->>'id';v_no_show_id:=v_no_show->>'id';
  v_no_show_owner:=upper(coalesce(v_no_show->>'advisor',''));v_no_show_owner_id:=v_no_show->>'advisorId';
  begin v_protected_until:=nullif(v_no_show->>'protectedUntil','')::timestamptz; exception when others then v_protected_until:=null; end;
  v_owner_followup:=coalesce((v_no_show->>'ownerFollowupAfterNoShow')::boolean,false);
  v_same_owner:=v_no_show_owner<>'' and v_no_show_owner=upper(v_user.nombre);
  begin v_reactivation_from:=nullif(v_policy->>'reactivationEligibleFrom','')::timestamptz; exception when others then v_reactivation_from:=null; end;
  v_reactivation_eligible:=coalesce((v_policy->>'reactivationEligible')::boolean,false);

  if v_identity_status='IDENTITY_CONFLICT' or v_patient_state='REVIEW' then
    perform public.aos_callcenter_policy_log_v1(p_actor,v_num,v_action,'BLOCK','IDENTITY_CONFLICT',null,null,null,null,null,v_ctx);
    return pg_catalog.jsonb_build_object('ok',false,'error','IDENTITY_CONFLICT','patient',v_ctx);
  end if;
  if v_is_converted and v_action in ('COMMERCIAL_CALL_APPOINTMENT','CALLBACK_INBOUND_APPOINTMENT') then
    perform public.aos_callcenter_policy_log_v1(p_actor,v_num,v_action,'BLOCK','PATIENT_ACTION_REQUIRED',null,null,null,null,'CLINIC',v_ctx);
    return pg_catalog.jsonb_build_object('ok',false,'error','PATIENT_ACTION_REQUIRED','patient',v_ctx,'allowedActions','["REACTIVATION","PATIENT_FOLLOWUP","AGENDA_ONLY"]'::jsonb);
  end if;
  if not v_is_converted and v_action in ('REACTIVATION','PATIENT_FOLLOWUP') then
    perform public.aos_callcenter_policy_log_v1(p_actor,v_num,v_action,'BLOCK','PATIENT_NOT_CONVERTED',null,null,null,null,null,v_ctx);
    return pg_catalog.jsonb_build_object('ok',false,'error','PATIENT_NOT_CONVERTED','patient',v_ctx,'allowedActions','["COMMERCIAL_CALL_APPOINTMENT","CALLBACK_INBOUND_APPOINTMENT","AGENDA_ONLY"]'::jsonb);
  end if;

  v_need_agenda:=v_action<>'PATIENT_FOLLOWUP' or nullif(v_payload->>'fecha_cita','') is not null;
  if v_need_agenda then
    begin v_fecha_cita:=nullif(v_payload->>'fecha_cita','')::date; exception when others then return pg_catalog.jsonb_build_object('ok',false,'error','INVALID_APPOINTMENT_DATE'); end;
    v_hora_cita:=pg_catalog.btrim(coalesce(v_payload->>'hora_cita',''));
    if v_fecha_cita is null or v_hora_cita='' then return pg_catalog.jsonb_build_object('ok',false,'error','APPOINTMENT_REQUIRED'); end if;
    if v_active_id is not null then
      perform public.aos_callcenter_policy_log_v1(p_actor,v_num,v_action,'BLOCK','ACTIVE_APPOINTMENT_EXISTS',v_active->>'advisor',v_active->>'advisorId',v_active->>'advisor',v_active->>'advisorId','ADVISOR',v_ctx);
      return pg_catalog.jsonb_build_object('ok',false,'error','ACTIVE_APPOINTMENT_EXISTS','activeAppointment',v_active,'patient',v_ctx);
    end if;
  end if;

  v_effective_action:=v_action;
  if v_is_converted then
    v_lead_id:=null;v_origin:='PACIENTE_EXISTENTE';
    if v_action='REACTIVATION' then
      v_need_call:=true;v_need_agenda:=true;v_tipo_gestion:='REACTIVACION';v_agenda_origin:='CALL_CENTER_REACTIVACION';
      if v_reactivation_eligible then
        v_call_state:='CITA CONFIRMADA';v_sub_state:='REACTIVACION_ELEGIBLE';v_decision:='ALLOW';v_reason:='REACTIVATION_15D_ELIGIBLE';v_beneficiary:='ADVISOR';
      else
        v_call_state:='SEGUIMIENTO';v_sub_state:='REACTIVACION_NO_ELEGIBLE';v_decision:='DOWNGRADE';v_reason:='REACTIVATION_BEFORE_15D';v_beneficiary:='CLINIC';v_credited:=null;v_credited_id:=null;v_owner:=null;v_owner_id:=null;
      end if;
    elsif v_action='PATIENT_FOLLOWUP' then
      v_need_call:=true;v_call_state:='SEGUIMIENTO';v_sub_state:='PACIENTE';v_tipo_gestion:='SEGUIMIENTO_PACIENTE';v_agenda_origin:='CALL_CENTER_SEGUIMIENTO';v_decision:='ALLOW_NO_COMMERCIAL_CREDIT';v_reason:='PATIENT_FOLLOWUP';v_beneficiary:='CLINIC';v_credited:=null;v_credited_id:=null;
    else
      v_need_call:=false;v_agenda_origin:='CALL_CENTER_SOLO_AGENDAR';v_decision:='ALLOW_NO_COMMERCIAL_CREDIT';v_reason:='AGENDA_ONLY';v_beneficiary:='CLINIC';v_credited:=null;v_credited_id:=null;
    end if;
  else
    if v_action='AGENDA_ONLY' then
      v_need_call:=false;v_agenda_origin:='CALL_CENTER_SOLO_AGENDAR';v_origin:='ORGANICO';v_decision:='ALLOW_NO_COMMERCIAL_CREDIT';v_reason:='AGENDA_ONLY';v_beneficiary:='CLINIC';v_credited:=null;v_credited_id:=null;
    else
      v_need_call:=true;v_need_agenda:=true;
      if v_no_show_id is not null then
        if v_same_owner then
          v_call_state:='SEGUIMIENTO';v_sub_state:='REAGENDADO_NO_SHOW_OWNER';v_tipo_gestion:='RECUPERACION_SEGUIMIENTO';v_agenda_origin:='CALL_CENTER_REAGENDADO';v_decision:='DOWNGRADE';v_reason:='ORIGINAL_OWNER_REBOOK';v_beneficiary:='ADVISOR';v_credited:=v_no_show_owner;v_credited_id:=v_no_show_owner_id;v_owner:=v_no_show_owner;v_owner_id:=v_no_show_owner_id;v_agenda_advisor:=v_no_show_owner;v_agenda_advisor_id:=v_no_show_owner_id;
        elsif v_protected_until is not null and v_event_ts<v_protected_until then
          v_call_state:='SEGUIMIENTO';v_sub_state:='RECUPERACION_APOYO_72H';v_tipo_gestion:='RECUPERACION_APOYO';v_agenda_origin:='CALL_CENTER_APOYO';v_decision:='DOWNGRADE';v_reason:='NO_SHOW_PROTECTED_72H';v_beneficiary:='ADVISOR';v_credited:=v_no_show_owner;v_credited_id:=v_no_show_owner_id;v_owner:=v_no_show_owner;v_owner_id:=v_no_show_owner_id;v_agenda_advisor:=v_no_show_owner;v_agenda_advisor_id:=v_no_show_owner_id;
        elsif v_owner_followup then
          v_call_state:='SEGUIMIENTO';v_sub_state:='RECUPERACION_APOYO_OWNER_ACTIVE';v_tipo_gestion:='RECUPERACION_APOYO';v_agenda_origin:='CALL_CENTER_APOYO';v_decision:='DOWNGRADE';v_reason:='ORIGINAL_OWNER_FOLLOWUP_EXISTS';v_beneficiary:='ADVISOR';v_credited:=v_no_show_owner;v_credited_id:=v_no_show_owner_id;v_owner:=v_no_show_owner;v_owner_id:=v_no_show_owner_id;v_agenda_advisor:=v_no_show_owner;v_agenda_advisor_id:=v_no_show_owner_id;
        else
          v_call_state:='CITA CONFIRMADA';v_sub_state:='RECUPERACION_NO_SHOW_72H';v_tipo_gestion:=case when v_source_mode='FOLLOWUP' then 'FOLLOWUP_CONVERSION' when v_action='CALLBACK_INBOUND_APPOINTMENT' then 'CALLBACK_INBOUND' else 'RECUPERACION_NO_SHOW' end;v_agenda_origin:='CALL_CENTER_RECUPERACION';v_decision:='ALLOW';v_reason:='NO_SHOW_RECOVERY_72H';v_beneficiary:='ADVISOR';v_transfer:=true;
        end if;
      else
        v_call_state:='CITA CONFIRMADA';v_sub_state:=case when v_source_mode='FOLLOWUP' then 'FOLLOWUP_CONVERSION' when v_action='CALLBACK_INBOUND_APPOINTMENT' then 'CALLBACK_INBOUND' else null end;
        v_tipo_gestion:=case when v_source_mode='FOLLOWUP' then 'FOLLOWUP_CONVERSION' when v_action='CALLBACK_INBOUND_APPOINTMENT' then 'CALLBACK_INBOUND' when v_source_mode='MANUAL' then 'LLAMADA_MANUAL_COMERCIAL' else 'LLAMADA' end;
        v_agenda_origin:=case when v_source_mode='MANUAL' then 'CITA_MANUAL' else 'CALL_CENTER' end;v_decision:='ALLOW';v_reason:='NEW_OR_HISTORICAL_PROSPECT_ELIGIBLE';v_beneficiary:='ADVISOR';
      end if;
    end if;
  end if;

  if not v_is_converted and v_action in ('COMMERCIAL_CALL_APPOINTMENT','CALLBACK_INBOUND_APPOINTMENT') then
    begin v_explicit_lead:=nullif(v_payload->>'lead_id','')::bigint; exception when others then v_explicit_lead:=null; end;
    if v_explicit_lead is not null then
      select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio from public.aos_marketing_touchpoints_v2(null,null)t where t.lead_id=v_explicit_lead and t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_event_ts limit 1;
    end if;
    if v_lead_id is null then
      select count(*) into v_prior_count from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_event_ts;
      if v_prior_count>0 and nullif(v_treatment,'') is not null then
        select count(*) into v_match_count from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_event_ts and pg_catalog.regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=pg_catalog.regexp_replace(upper(v_treatment),'[^A-Z0-9]+','','g');
        if v_match_count>0 then select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_event_ts and pg_catalog.regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=pg_catalog.regexp_replace(upper(v_treatment),'[^A-Z0-9]+','','g') order by t.lead_ts desc,t.lead_id desc limit 1; end if;
      elsif v_prior_count>0 then select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_event_ts order by t.lead_ts desc,t.lead_id desc limit 1; end if;
    end if;
    if v_lead_id is not null then v_origin:='MARKETING'; elsif v_prior_count>0 then v_origin:='MARKETING_REVIEW'; else v_origin:='ORGANICO'; end if;
    if v_decision='DOWNGRADE' and v_no_show_id is not null then
      begin v_agenda_lead:=nullif(v_no_show->>'leadId','')::bigint; exception when others then v_agenda_lead:=null; end;
    else v_agenda_lead:=v_lead_id; end if;
  end if;

  v_hash:=pg_catalog.encode(extensions.digest(v_action||'|'||(v_payload-'event_ts'-'business_date')::text,'sha256'),'hex');
  insert into public.aos_callcenter_actions_v1(
    idempotency_key,request_hash,actor_user_id,asesor,id_asesor,numero_limpio,action_type,source_mode,patient_state,identity_status,canonical_patient_id,
    lead_id_origen,origen,status,created_at,updated_at,credited_advisor,credited_advisor_id,commercial_owner,commercial_owner_id,beneficiary_scope,
    eligibility_status,eligibility_reason,prior_agenda_id,prior_advisor,prior_advisor_id,ownership_transfer,rule_context
  ) values(
    v_key,v_hash,p_actor,upper(v_user.nombre),v_user.codigo_asesor,v_num,v_action,v_source_mode,v_patient_state,v_identity_status,v_canonical,
    v_lead_id,v_origin,'PROCESSING',v_event_ts,pg_catalog.now(),v_credited,v_credited_id,v_owner,v_owner_id,v_beneficiary,
    v_decision,v_reason,v_no_show_id,v_no_show_owner,v_no_show_owner_id,v_transfer,v_ctx
  ) on conflict(idempotency_key) do nothing returning true into v_inserted;
  if not coalesce(v_inserted,false) then
    select * into v_existing from public.aos_callcenter_actions_v1 a where a.idempotency_key=v_key for update;
    if v_existing.request_hash<>v_hash then return pg_catalog.jsonb_build_object('ok',false,'error','IDEMPOTENCY_CONFLICT'); end if;
    if v_existing.status='COMPLETE' and v_existing.result is not null then return v_existing.result||pg_catalog.jsonb_build_object('idempotent',true); end if;
    return pg_catalog.jsonb_build_object('ok',false,'error','ACTION_IN_PROGRESS');
  end if;

  if v_decision<>'ALLOW' then
    perform public.aos_callcenter_policy_log_v1(p_actor,v_num,v_action,v_decision,v_reason,v_credited,v_credited_id,v_owner,v_owner_id,v_beneficiary,v_ctx);
  end if;

  if v_need_call then
    select count(*)::integer+1 into v_attempt from public.aos_llamadas l where l.numero_limpio=v_num;
    insert into public.aos_llamadas(fecha,numero,numero_limpio,tratamiento,estado,sub_estado,observacion,hora_llamada,asesor,id_asesor,anuncio,origen,intento,created_at,duracion_seg,tipo_gestion,desde_dispositivo,lead_id_origen)
    values(v_day,v_num,v_num,coalesce(nullif(v_treatment,''),v_lead_trat,''),v_call_state,v_sub_state,coalesce(v_payload->>'obs',''),to_char(v_event_ts at time zone 'America/Lima','HH24:MI:SS'),upper(v_user.nombre),v_user.codigo_asesor,coalesce(v_lead_anuncio,v_payload->>'anuncio',''),v_origin,v_attempt,v_event_ts,greatest(0,coalesce(nullif(v_payload->>'duracion_seg','')::integer,0)),v_tipo_gestion,coalesce(nullif(v_payload->>'desde_dispositivo',''),'web'),case when v_call_state='CITA CONFIRMADA' then v_lead_id else null end)
    returning id,estado,tipo_gestion,origen,lead_id_origen into v_call_id,v_call_actual_state,v_call_actual_type,v_call_actual_origin,v_call_actual_lead;
    if v_call_id is null then raise exception 'CALL_INSERT_SUPPRESSED'; end if;
    if v_fail='AFTER_CALL' then raise exception 'LOOP6_TEST_FAIL_AFTER_CALL'; end if;
  end if;

  if v_need_agenda then
    v_agenda_id:=pg_catalog.gen_random_uuid()::text;
    insert into public.aos_agenda_citas(id,fecha_cita,tratamiento,tipo_cita,sede,numero,numero_limpio,nombre,apellido,dni,correo,asesor,id_asesor,estado_cita,obs,ts_creado,hora_cita,doctora,tipo_atencion,origen_cita,origen,lead_id_origen,llamada_id_origen)
    values(v_agenda_id,v_fecha_cita,v_treatment,coalesce(nullif(v_payload->>'tipo_cita',''),'CONSULTA NUEVA'),coalesce(v_payload->>'sede',''),v_num,v_num,coalesce(v_payload->>'nombre',''),coalesce(v_payload->>'apellido',''),coalesce(v_payload->>'dni',''),coalesce(v_payload->>'correo',''),v_agenda_advisor,v_agenda_advisor_id,'PENDIENTE',coalesce(v_payload->>'obs',''),v_event_ts,v_hora_cita,coalesce(v_payload->>'doctora',''),coalesce(v_payload->>'tipo_atencion',''),v_agenda_origin,'MANUAL',case when v_call_state='CITA CONFIRMADA' then coalesce(v_call_actual_lead,v_lead_id) else coalesce(v_agenda_lead,nullif(v_no_show->>'leadId','')::bigint) end,v_call_id);
    if not exists(select 1 from public.aos_agenda_citas a where a.id=v_agenda_id) then raise exception 'AGENDA_INSERT_SUPPRESSED'; end if;
    if v_fail='AFTER_AGENDA' then raise exception 'LOOP6_TEST_FAIL_AFTER_AGENDA'; end if;
  end if;

  if nullif(v_payload->>'followup_id','') is not null then update public.aos_seguimientos set "ESTADO"='COMPLETADO',"TS_ACTUALIZADO"=pg_catalog.now() where "ID"=v_payload->>'followup_id'; end if;

  v_result:=pg_catalog.jsonb_build_object(
    'ok',true,'idempotent',false,'requestedAction',v_action,'effectiveAction',v_effective_action,'patientState',v_patient_state,
    'identityStatus',v_identity_status,'canonicalPatientId',v_canonical,'converted',v_is_converted,'callId',v_call_id,'agendaId',v_agenda_id,
    'leadId',coalesce(v_call_actual_lead,v_lead_id),'origin',coalesce(v_call_actual_origin,v_origin),'callState',v_call_actual_state,'tipoGestion',v_call_actual_type,
    'businessDate',v_day,'executedBy',upper(v_user.nombre),'executedById',v_user.codigo_asesor,'creditedAdvisor',v_credited,'creditedAdvisorId',v_credited_id,
    'commercialOwner',v_owner,'commercialOwnerId',v_owner_id,'beneficiaryScope',v_beneficiary,'eligibilityStatus',v_decision,'eligibilityReason',v_reason,
    'ownershipTransfer',v_transfer,'priorAgendaId',v_no_show_id,'priorAdvisor',v_no_show_owner,'policy',v_policy
  );
  update public.aos_callcenter_actions_v1 set status='COMPLETE',llamada_id=v_call_id,agenda_id=v_agenda_id,lead_id_origen=coalesce(v_call_actual_lead,v_lead_id),origen=coalesce(v_call_actual_origin,v_origin),result=v_result,updated_at=pg_catalog.now() where idempotency_key=v_key;
  return v_result;
end
$function$;

revoke all on function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text) to service_role;

-- Guard: eligible reactivation / explicit recovery is already policy-authorized by Loop 6 core.
create or replace function public.aos_hotfix_call_guard_v1()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp'
as $function$
declare v_num text;v_call_ts timestamptz;v_eff_trat text;v_prior_count integer:=0;v_match_count integer:=0;v_any_leads integer:=0;v_lead_id bigint;v_lead_trat text;v_lead_anuncio text;v_noncommercial text;v_reason text;v_policy_authorized boolean:=false;
begin
  v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');new.numero_limpio:=v_num;
  if upper(trim(coalesce(new.estado,'')))<>'CITA CONFIRMADA' or v_num='' then return new;end if;
  v_call_ts:=public.aos_llamada_event_ts(coalesce(new.fecha,(now() at time zone 'America/Lima')::date),new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);
  v_policy_authorized:=upper(coalesce(new.tipo_gestion,'')) in ('REACTIVACION','RECUPERACION_NO_SHOW','FOLLOWUP_CONVERSION');
  if not v_policy_authorized and (
    exists(select 1 from public.aos_ventas v where v.numero_limpio=v_num and v.fecha<coalesce(new.fecha,(now() at time zone 'America/Lima')::date))
    or exists(select 1 from public.aos_atenciones a where a.numero_limpio=v_num and a.fecha<coalesce(new.fecha,(now() at time zone 'America/Lima')::date))
    or exists(select 1 from public.aos_agenda_citas a where a.numero_limpio=v_num and a.fecha_cita<coalesce(new.fecha,(now() at time zone 'America/Lima')::date) and upper(coalesce(a.estado_cita,'')) in ('ASISTIO','ASISTIÓ','EFECTIVA'))
  ) then v_noncommercial:='PACIENTE_CONTINUIDAD';v_reason:='Paciente/continuidad: evidencia clínica, venta o asistencia previa.';
  elsif not v_policy_authorized and upper(coalesce(new.observacion,''))~'(ANTIGU|SESION|SESIÓN|CONTROL|DEUDA|APLICACION|APLICACIÓN)' then v_noncommercial:='PACIENTE_CONTINUIDAD';v_reason:='Continuidad legacy inferida por texto operativo.';end if;
  if v_noncommercial is not null then insert into public.aos_gestiones_no_comerciales(source_call_id,clasificacion,motivo,asesor,numero_limpio,fecha,lead_id_origen,call_payload,agenda_ids,source) values(new.id,v_noncommercial,v_reason,new.asesor,v_num,coalesce(new.fecha,(now() at time zone 'America/Lima')::date),new.lead_id_origen,to_jsonb(new),null,'CALL_GUARD_V3') on conflict(source_call_id)do nothing;return null;end if;
  if exists(select 1 from public.aos_llamadas l where l.numero_limpio=v_num and l.fecha=coalesce(new.fecha,(now() at time zone 'America/Lima')::date) and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,'')) and upper(coalesce(l.estado,''))='CITA CONFIRMADA')then new.estado:='SEGUIMIENTO';new.sub_estado:='CITA YA EXISTENTE';new.origen:=coalesce(nullif(new.origen,''),'FOLLOWUP_EXISTING_CITA');new.observacion:=trim(concat_ws(' | ',nullif(new.observacion,''),'No suma nueva conversión: ya existía CITA CONFIRMADA para este número/asesor en el día.'));return new;end if;
  v_eff_trat:=case when upper(coalesce(new.tratamiento,''))='ORGANICO' then coalesce(nullif(new.anuncio,''),new.tratamiento,'') else coalesce(new.tratamiento,'') end;
  select count(*) into v_prior_count from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts;
  if v_prior_count=1 then select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts order by t.lead_ts desc,t.lead_id desc limit 1;
  elsif v_prior_count>1 and nullif(trim(v_eff_trat),'')is not null then select count(*) into v_match_count from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts and regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(v_eff_trat),'[^A-Z0-9]+','','g');if v_match_count>=1 then select t.lead_id,t.tratamiento,t.anuncio into v_lead_id,v_lead_trat,v_lead_anuncio from public.aos_marketing_touchpoints_v2(null,null)t where t.numero_limpio=v_num and not t.es_duplicado_tecnico_probable and t.lead_ts<=v_call_ts and regexp_replace(upper(coalesce(t.tratamiento,'')),'[^A-Z0-9]+','','g')=regexp_replace(upper(v_eff_trat),'[^A-Z0-9]+','','g') order by t.lead_ts desc,t.lead_id desc limit 1;end if;end if;
  if v_policy_authorized and upper(coalesce(new.tipo_gestion,''))='REACTIVACION' then new.lead_id_origen:=null;new.origen:='PACIENTE_EXISTENTE';return new;end if;
  if v_lead_id is not null then new.lead_id_origen:=v_lead_id;new.origen:='MARKETING';new.anuncio:=coalesce(nullif(new.anuncio,''),v_lead_anuncio);if nullif(trim(coalesce(new.tratamiento,'')),'')is null or upper(coalesce(new.tratamiento,''))='ORGANICO' then new.tratamiento:=v_lead_trat;end if;
  else select count(*) into v_any_leads from public.aos_leads l where l.numero_limpio=v_num;if v_any_leads=0 then new.origen:='ORGANICO';if upper(coalesce(new.tratamiento,''))<>'ORGANICO' then new.anuncio:=coalesce(nullif(new.anuncio,''),nullif(new.tratamiento,''));new.tratamiento:='ORGANICO';end if;else new.origen:=coalesce(nullif(new.origen,''),'MARKETING_UNRESOLVED');end if;end if;
  return new;
end
$function$;

-- Cleanup remains legacy-only; explicit Loop 6 policy semantics are protected.
create or replace function public.aos_hotfix_manual_agenda_cleanup_v1()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp'
as $function$
declare v_call_ts timestamptz;v_agenda_ts timestamptz;v_num text;
begin
  if tg_table_name='aos_agenda_citas' then
    if upper(coalesce(new.origen_cita,''))<>'CITA_MANUAL' then return new;end if;
    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');v_agenda_ts:=coalesce(new.ts_creado,now());
    delete from public.aos_llamadas l where l.numero_limpio=v_num and upper(coalesce(l.asesor,''))=upper(coalesce(new.asesor,'')) and upper(coalesce(l.tipo_gestion,'LLAMADA')) not in ('LLAMADA_MANUAL_COMERCIAL','CALLBACK_INBOUND','INFERIDA_HISTORICA','REACTIVACION','SEGUIMIENTO_PACIENTE','FOLLOWUP_CONVERSION','RECUPERACION_NO_SHOW','RECUPERACION_APOYO','RECUPERACION_SEGUIMIENTO') and (upper(coalesce(l.estado,''))='CITA CONFIRMADA' or (upper(coalesce(l.estado,''))='SEGUIMIENTO' and upper(coalesce(l.sub_estado,''))='CITA YA EXISTENTE')) and abs(extract(epoch from(public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)-v_agenda_ts)))<=10;return new;
  end if;
  if tg_table_name='aos_llamadas' then
    if upper(coalesce(new.tipo_gestion,'LLAMADA')) in ('LLAMADA_MANUAL_COMERCIAL','CALLBACK_INBOUND','INFERIDA_HISTORICA','REACTIVACION','SEGUIMIENTO_PACIENTE','FOLLOWUP_CONVERSION','RECUPERACION_NO_SHOW','RECUPERACION_APOYO','RECUPERACION_SEGUIMIENTO') then return new;end if;
    if not(upper(coalesce(new.estado,''))='CITA CONFIRMADA' or(upper(coalesce(new.estado,''))='SEGUIMIENTO' and upper(coalesce(new.sub_estado,''))='CITA YA EXISTENTE'))then return new;end if;
    v_num:=regexp_replace(coalesce(nullif(new.numero_limpio,''),new.numero,''),'[^0-9]','','g');v_call_ts:=public.aos_llamada_event_ts(new.fecha,new.hora_llamada,new.created_at,new.ult_ts,new.ts_log);
    if exists(select 1 from public.aos_agenda_citas a where a.numero_limpio=v_num and upper(coalesce(a.asesor,''))=upper(coalesce(new.asesor,'')) and upper(coalesce(a.origen_cita,''))='CITA_MANUAL' and abs(extract(epoch from(coalesce(a.ts_creado,a.fecha_cita::timestamptz)-v_call_ts)))<=10)then delete from public.aos_llamadas where id=new.id;end if;return new;
  end if;
  return new;
end
$function$;

revoke all on function public.aos_callcenter_credit_context_v2(text,timestamptz) from public,anon,authenticated;
revoke all on function public.aos_callcenter_policy_log_v1(uuid,text,text,text,text,text,text,text,text,text,jsonb) from public,anon,authenticated;
