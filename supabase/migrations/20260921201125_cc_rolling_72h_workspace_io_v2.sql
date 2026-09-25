-- ASCENDA OS · Call Center rolling ownership 72h + CIA Workspace fast catalog I/O V2
-- 2026-09-21
begin;

create or replace function public.aos_callcenter_credit_context_v2(
  p_numero text,
  p_event_ts timestamptz default pg_catalog.now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
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
  v_owner_last_activity timestamptz;
  v_owner_followup boolean:=false;
begin
  v_state:=public.aos_callcenter_patient_state_fast_v3(v_num,v_event);
  if coalesce((v_state->>'ok')::boolean,false)=false then
    return v_state;
  end if;

  select q.ts,q.kind
    into v_last_qual_ts,v_last_qual_type
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
  order by q.ts desc nulls last
  limit 1;

  if v_last_qual_ts is not null then
    v_reactivation_from:=v_last_qual_ts+interval '15 days';
  end if;

  select a.id,a.asesor,a.id_asesor,a.fecha_cita,a.hora_cita,a.estado_cita,a.lead_id_origen,
         public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) slot
    into v_active
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('PENDIENTE','CITA CONFIRMADA')
    and a.fecha_cita>=v_day
  order by public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) asc,
           a.ts_creado asc nulls last
  limit 1;

  select a.id,a.asesor,a.id_asesor,a.fecha_cita,a.hora_cita,a.estado_cita,a.lead_id_origen,
         public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) slot
    into v_no_show
  from public.aos_agenda_citas a
  where a.numero_limpio=v_num
    and upper(coalesce(a.estado_cita,'')) in ('NO ASISTIO','NO ASISTIÓ')
    and public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita)<v_event
  order by public.aos_callcenter_agenda_slot_v1(a.fecha_cita,a.hora_cita) desc,
           a.ts_creado desc nulls last
  limit 1;

  if v_no_show.id is not null then
    v_no_show_slot:=v_no_show.slot;

    select max(x.ts)
      into v_owner_last_activity
    from (
      select public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log) ts
      from public.aos_llamadas l
      where l.numero_limpio=v_num
        and upper(coalesce(l.asesor,''))=upper(coalesce(v_no_show.asesor,''))
        and public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)>v_no_show_slot
        and public.aos_llamada_event_ts(l.fecha,l.hora_llamada,l.created_at,l.ult_ts,l.ts_log)<v_event

      union all

      select greatest(
        coalesce(public.aos_callcenter_try_timestamptz_v1(s."TS_CREADO"),'-infinity'::timestamptz),
        coalesce(public.aos_callcenter_try_timestamptz_v1(s."TS_ACTUALIZADO"),'-infinity'::timestamptz)
      )
      from public.aos_seguimientos s
      where pg_catalog.regexp_replace(coalesce(s."NUMERO",''),'[^0-9]','','g')=v_num
        and upper(coalesce(s."ASESOR",''))=upper(coalesce(v_no_show.asesor,''))
        and greatest(
          coalesce(public.aos_callcenter_try_timestamptz_v1(s."TS_CREADO"),'-infinity'::timestamptz),
          coalesce(public.aos_callcenter_try_timestamptz_v1(s."TS_ACTUALIZADO"),'-infinity'::timestamptz)
        )>v_no_show_slot
        and greatest(
          coalesce(public.aos_callcenter_try_timestamptz_v1(s."TS_CREADO"),'-infinity'::timestamptz),
          coalesce(public.aos_callcenter_try_timestamptz_v1(s."TS_ACTUALIZADO"),'-infinity'::timestamptz)
        )<v_event
    ) x;

    v_protected_until:=greatest(v_no_show_slot,coalesce(v_owner_last_activity,v_no_show_slot))+interval '72 hours';
    v_owner_followup:=v_owner_last_activity is not null and v_event<v_protected_until;
  end if;

  return v_state||pg_catalog.jsonb_build_object(
    'creditPolicy',pg_catalog.jsonb_build_object(
      'lastQualifyingTs',v_last_qual_ts,
      'lastQualifyingType',v_last_qual_type,
      'reactivationEligibleFrom',v_reactivation_from,
      'reactivationEligible',case
        when coalesce((v_state->>'converted')::boolean,false)
             and v_reactivation_from is not null
        then v_event>=v_reactivation_from
        else false
      end,
      'activeAppointment',case when v_active.id is null then null else
        pg_catalog.jsonb_build_object(
          'id',v_active.id,'advisor',v_active.asesor,'advisorId',v_active.id_asesor,
          'date',v_active.fecha_cita,'time',v_active.hora_cita,'status',v_active.estado_cita,
          'slot',v_active.slot,'leadId',v_active.lead_id_origen
        ) end,
      'lastNoShow',case when v_no_show.id is null then null else
        pg_catalog.jsonb_build_object(
          'id',v_no_show.id,'advisor',v_no_show.asesor,'advisorId',v_no_show.id_asesor,
          'date',v_no_show.fecha_cita,'time',v_no_show.hora_cita,'slot',v_no_show_slot,
          'leadId',v_no_show.lead_id_origen,'protectedUntil',v_protected_until,
          'ownerLastActivityAt',v_owner_last_activity,
          'ownerFollowupAfterNoShow',v_owner_followup,
          'ownershipRule','ROLLING_72H'
        ) end
    )
  );
end
$function$;


comment on function public.aos_callcenter_credit_context_v2(text,timestamptz) is
  'Call Center credit context with rolling 72h ownership lease after NO ASISTIO. Each recorded owner action renews protection for 72h; inactivity beyond 72h releases recovery to another advisor.';


create or replace function public.aos_cia_workspace_catalog_members_v1(p_preset_key text)
returns setof public.aos_cia_contact_runtime_cache_v1
language sql
stable
security definer
set search_path to ''
as $function$
  select c.*
  from public.aos_cia_contact_runtime_cache_v1 c
  where case upper(coalesce(p_preset_key,''))
    when 'ATTENDED_APPOINTMENT' then coalesce(c.attended_count,0)>0
    when 'EVER_NO_SHOW' then coalesce(c.ever_no_show,false)
    when 'HAS_FUTURE_APPOINTMENT' then coalesce(c.has_future_appointment,false)
    when 'NEVER_APPOINTED' then coalesce(c.appointments_never_had,false)
    when 'NO_SHOW_NO_FUTURE' then coalesce(c.ever_no_show,false) and not coalesce(c.has_future_appointment,false)
    when 'CALL_STALE_30D' then coalesce(c.days_since_last_call,0)>30
    when 'CALL_STALE_7D' then coalesce(c.days_since_last_call,0)>7
    when 'CALLED_NO_EFFECTIVE_CONTACT' then coalesce(c.call_count,0)>0 and coalesce(c.effective_contact_count,0)=0
    when 'CALLED_TODAY' then coalesce(c.called_today,false)
    when 'EFFECTIVE_CONTACTS' then coalesce(c.effective_contact_count,0)>0
    when 'NEVER_CALLED_CONTACTS' then coalesce(c.calls_never_called,false)
    when 'IDENTITY_CONFLICT' then coalesce(c.identity_conflict,false)
    when 'PATIENTS' then coalesce(c.exists_as_patient,false)
    when 'AGE_18_24' then c.age_band='18_24'
    when 'AGE_25_34' then c.age_band='25_34'
    when 'AGE_35_44' then c.age_band='35_44'
    when 'AGE_45_54' then c.age_band='45_54'
    when 'AGE_55_64' then c.age_band='55_64'
    when 'AGE_65_PLUS' then c.age_band='65_PLUS'
    when 'SEX_FEMALE' then c.sex='F'
    when 'SEX_MALE' then c.sex='M'
    when 'EMAIL_BOUNCED' then coalesce(c.email_bounced_count,0)>0
    when 'EMAIL_CLICKED' then coalesce(c.email_clicked_count,0)>0
    when 'EMAIL_OPENED' then coalesce(c.email_opened_count,0)>0
    when 'EMAIL_VALID' then coalesce(c.email_valid,false)
    when 'NEVER_EMAILED_KNOWN' then coalesce(c.email_never_sent,false)
    when 'FOLLOWUP_OVERDUE' then coalesce(c.overdue_followup_count,0)>0
    when 'PENDING_FOLLOWUPS' then coalesce(c.pending_followup_count,0)>0
    when 'ALL_LEADS' then coalesce(c.exists_as_lead,false)
    when 'LEAD_PRODUCT_INTEREST' then c.latest_interest_type='PRODUCTO'
    when 'LEAD_SERVICE_INTEREST' then c.latest_interest_type='SERVICIO'
    when 'LEADS_UNWORKED' then coalesce(c.lead_unworked_since_latest_entry,false)
    when 'LEADS_UNWORKED_7D' then coalesce(c.lead_unworked_since_latest_entry,false) and coalesce(c.days_since_last_lead,999999)<=7
    when 'DORMANT_BUYERS_90D' then coalesce(c.days_since_last_sale,0)>90
    when 'NEVER_BOUGHT' then coalesce(c.sales_never_bought,false)
    when 'PRODUCT_BUYERS' then coalesce(c.traits,'{}'::text[]) @> array['PRODUCT_BUYER']::text[]
    when 'RECENT_BUYERS_30D' then coalesce(c.days_since_last_sale,999999)<=30
    when 'SERVICE_BUYERS' then coalesce(c.traits,'{}'::text[]) @> array['SERVICE_BUYER']::text[]
    when 'ACTIVE_CUSTOMERS' then c.lifecycle='ACTIVE_CUSTOMER'
    when 'ACTIVE_PROSPECTS' then c.lifecycle in ('ACTIVE_PROSPECT','APPOINTMENT_READY_PROSPECT')
    when 'COLD_PROSPECTS' then c.lifecycle='COLD_PROSPECT'
    when 'DIAMOND_CUSTOMERS' then c.value_tier='DIAMANTE'
    when 'GOLD_CUSTOMERS' then c.value_tier='GOLD'
    when 'HIGH_VALUE_COOLING' then c.value_tier in ('GOLD','DIAMANTE') and c.lifecycle in ('COOLING_CUSTOMER','INACTIVE_CUSTOMER')
    when 'INACTIVE_CUSTOMERS' then c.lifecycle='INACTIVE_CUSTOMER'
    when 'NEW_CUSTOMERS' then c.lifecycle='NEW_CUSTOMER'
    when 'WARM_PROSPECTS' then c.lifecycle='WARM_PROSPECT'
    else false
  end
$function$;

revoke all on function public.aos_cia_workspace_catalog_members_v1(text) from public,anon,authenticated;


create or replace function public.aos_cia_workspace_preview_app_v2(
  p_app_token text,
  p_preset_key text default null,
  p_all_contacts boolean default false,
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_auth jsonb;v_uid uuid;v_role text;v_assurance text;v_panels text[];
  v_key text:=upper(coalesce(p_preset_key,''));v_limit integer;v_offset integer;v_count integer;v_items jsonb;
begin

  v_auth:=public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_uid:=(v_auth->>'user_id')::uuid;
  v_role:=upper(coalesce(v_auth->>'rol',''));
  v_assurance:=upper(coalesce(v_auth->>'assurance_level',''));
  select coalesce(u.paneles_acceso,'{}'::text[]) into v_panels
  from public.aos_usuarios u where u.id=v_uid and u.activo=true;
  if v_role<>'ADMIN' or v_assurance<>'PASSWORD_2FA'
     or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;

  v_limit:=greatest(1,least(coalesce(p_limit,25),100));
  v_offset:=greatest(0,coalesce(p_offset,0));
  if not coalesce(p_all_contacts,false)
     and not exists(select 1 from public.aos_audience_presets p where p.active=true and p.preset_key=v_key) then
    return jsonb_build_object('ok',false,'error','UNKNOWN_CATALOG_AUDIENCE');
  end if;

  if coalesce(p_all_contacts,false) then
    select coalesce((select count_cache::integer from public.aos_audience_preset_runtime_cache_v1 where preset_key='__ALL__'),
                    (select count(*)::integer from public.aos_cia_contact_runtime_cache_v1))
      into v_count;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.contact_key),'[]'::jsonb)
      into v_items
    from (
      select c.contact_key,
             nullif(trim(concat_ws(' ',c.canonical_names,c.canonical_surnames)),'') name,
             c.canonical_email email,c.crm_branch branch,c.district,c.sex,c.age_band,c.patient_state,
             c.value_tier,c.lifecycle,c.engagement,c.latest_interest,c.latest_call_status,c.last_call_at,
             c.next_appointment_at,c.sale_count,c.revenue_lifetime,c.overdue_followup_count overdue_followups
      from public.aos_cia_contact_runtime_cache_v1 c
      order by c.contact_key limit v_limit offset v_offset
    ) q;
  else
    select coalesce((select count_cache::integer from public.aos_audience_preset_runtime_cache_v1 where preset_key=v_key),
                    (select count(*)::integer from public.aos_cia_workspace_catalog_members_v1(v_key)))
      into v_count;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.contact_key),'[]'::jsonb)
      into v_items
    from (
      select c.contact_key,
             nullif(trim(concat_ws(' ',c.canonical_names,c.canonical_surnames)),'') name,
             c.canonical_email email,c.crm_branch branch,c.district,c.sex,c.age_band,c.patient_state,
             c.value_tier,c.lifecycle,c.engagement,c.latest_interest,c.latest_call_status,c.last_call_at,
             c.next_appointment_at,c.sale_count,c.revenue_lifetime,c.overdue_followup_count overdue_followups
      from public.aos_cia_workspace_catalog_members_v1(v_key) c
      order by c.contact_key limit v_limit offset v_offset
    ) q;
  end if;

  return jsonb_build_object('ok',true,'count',v_count,'limit',v_limit,'offset',v_offset,'items',v_items,
                            'source','CATALOG_RUNTIME_FAST_V2','observed_at',statement_timestamp());
exception when others then
  return jsonb_build_object('ok',false,'error','WORKSPACE_PREVIEW_V2_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_workspace_preview_app_v2(text,text,boolean,integer,integer) from public;
grant execute on function public.aos_cia_workspace_preview_app_v2(text,text,boolean,integer,integer) to anon,authenticated;


create or replace function public.aos_cia_workspace_export_app_v2(
  p_app_token text,
  p_preset_key text default null,
  p_all_contacts boolean default false,
  p_filename text default 'audiencia'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_auth jsonb;v_uid uuid;v_role text;v_assurance text;v_panels text[];
  v_key text:=upper(coalesce(p_preset_key,''));v_count integer;v_csv text;v_name text;
begin

  v_auth:=public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_uid:=(v_auth->>'user_id')::uuid;
  v_role:=upper(coalesce(v_auth->>'rol',''));
  v_assurance:=upper(coalesce(v_auth->>'assurance_level',''));
  select coalesce(u.paneles_acceso,'{}'::text[]) into v_panels
  from public.aos_usuarios u where u.id=v_uid and u.activo=true;
  if v_role<>'ADMIN' or v_assurance<>'PASSWORD_2FA'
     or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;

  if not coalesce(p_all_contacts,false)
     and not exists(select 1 from public.aos_audience_presets p where p.active=true and p.preset_key=v_key) then
    return jsonb_build_object('ok',false,'error','UNKNOWN_CATALOG_AUDIENCE');
  end if;

  create temporary table if not exists pg_temp.cia_export_rows on commit drop as
    select c.* from public.aos_cia_contact_runtime_cache_v1 c where false;
  truncate pg_temp.cia_export_rows;

  if coalesce(p_all_contacts,false) then
    insert into pg_temp.cia_export_rows select * from public.aos_cia_contact_runtime_cache_v1;
  else
    insert into pg_temp.cia_export_rows select * from public.aos_cia_workspace_catalog_members_v1(v_key);
  end if;

  select count(*)::integer into v_count from pg_temp.cia_export_rows;
  if v_count>20000 then
    return jsonb_build_object('ok',false,'error','EXPORT_LIMIT_EXCEEDED','row_count',v_count,'max_rows',20000);
  end if;

  select
    'telefono,nombres,apellidos,email,sede,distrito,sexo,rango_edad,estado_paciente,nivel_valor,lifecycle,engagement,ultimo_interes,ultima_llamada,estado_ultima_llamada,proxima_cita,compras,facturacion,seguimientos_vencidos'||chr(10)||
    coalesce(string_agg(
      '"'||replace(coalesce(c.contact_key,''),'"','""')||'",'||
      '"'||replace(coalesce(c.canonical_names,''),'"','""')||'",'||
      '"'||replace(coalesce(c.canonical_surnames,''),'"','""')||'",'||
      '"'||replace(coalesce(c.canonical_email,''),'"','""')||'",'||
      '"'||replace(coalesce(c.crm_branch,''),'"','""')||'",'||
      '"'||replace(coalesce(c.district,''),'"','""')||'",'||
      '"'||replace(coalesce(c.sex,''),'"','""')||'",'||
      '"'||replace(coalesce(c.age_band,''),'"','""')||'",'||
      '"'||replace(coalesce(c.patient_state,''),'"','""')||'",'||
      '"'||replace(coalesce(c.value_tier,''),'"','""')||'",'||
      '"'||replace(coalesce(c.lifecycle,''),'"','""')||'",'||
      '"'||replace(coalesce(c.engagement,''),'"','""')||'",'||
      '"'||replace(coalesce(c.latest_interest,''),'"','""')||'",'||
      '"'||replace(coalesce(c.last_call_at::text,''),'"','""')||'",'||
      '"'||replace(coalesce(c.latest_call_status,''),'"','""')||'",'||
      '"'||replace(coalesce(c.next_appointment_at::text,''),'"','""')||'",'||
      coalesce(c.sale_count,0)::text||','||coalesce(c.revenue_lifetime,0)::text||','||coalesce(c.overdue_followup_count,0)::text,
      chr(10) order by c.contact_key
    ),'')
  into v_csv
  from pg_temp.cia_export_rows c;

  v_name:=coalesce(nullif(regexp_replace(lower(coalesce(p_filename,'audiencia')),'[^a-z0-9_-]+','-','g'),''),'audiencia');
  return jsonb_build_object('ok',true,'row_count',v_count,
    'filename',v_name||'-'||to_char(statement_timestamp(),'YYYYMMDD-HH24MI')||'.csv',
    'csv',v_csv,'source','CATALOG_RUNTIME_FAST_V2','observed_at',statement_timestamp());
exception when others then
  return jsonb_build_object('ok',false,'error','WORKSPACE_EXPORT_V2_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_workspace_export_app_v2(text,text,boolean,text) from public;
grant execute on function public.aos_cia_workspace_export_app_v2(text,text,boolean,text) to anon,authenticated;


create or replace function public.aos_cia_distribution_preview_app_v2(
  p_app_token text,
  p_preset_key text,
  p_source_limit integer default 100,
  p_all_available boolean default false,
  p_targets jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_auth jsonb;v_uid uuid;v_role text;v_assurance text;v_panels text[];
  v_key text:=upper(coalesce(p_preset_key,''));v_targets jsonb:=coalesce(p_targets,'[]'::jsonb);
  v_target_count integer;v_valid_count integer;v_distinct_count integer;v_candidate_count integer;
  v_requested integer;v_base integer;v_remainder integer;v_idx integer:=0;v_quota integer;v_assigned integer:=0;
  v_quotas jsonb:='[]'::jsonb;e record;
begin

  v_auth:=public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_uid:=(v_auth->>'user_id')::uuid;
  v_role:=upper(coalesce(v_auth->>'rol',''));
  v_assurance:=upper(coalesce(v_auth->>'assurance_level',''));
  select coalesce(u.paneles_acceso,'{}'::text[]) into v_panels
  from public.aos_usuarios u where u.id=v_uid and u.activo=true;
  if v_role<>'ADMIN' or v_assurance<>'PASSWORD_2FA'
     or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;

  if not exists(select 1 from public.aos_audience_presets p where p.active=true and p.preset_key=v_key) then
    return jsonb_build_object('ok',false,'error','UNKNOWN_CATALOG_AUDIENCE');
  end if;
  if jsonb_typeof(v_targets)<>'array' then return jsonb_build_object('ok',false,'error','INVALID_TARGETS'); end if;
  v_target_count:=jsonb_array_length(v_targets);
  if v_target_count<1 or v_target_count>50 then return jsonb_build_object('ok',false,'error','INVALID_TARGET_COUNT'); end if;
  if not coalesce(p_all_available,false) and (p_source_limit is null or p_source_limit<1 or p_source_limit>100000) then
    return jsonb_build_object('ok',false,'error','INVALID_SOURCE_LIMIT');
  end if;

  begin
    select count(distinct (x.value->>'advisor_user_id')::uuid),
           count(*) filter(where u.id is not null and u.activo=true and lower(coalesce(u.rol,''))='asesor'
                           and coalesce(u.paneles_acceso,'{}'::text[]) @> array['advisor-calls']::text[])
      into v_distinct_count,v_valid_count
    from jsonb_array_elements(v_targets) x(value)
    left join public.aos_usuarios u on u.id=(x.value->>'advisor_user_id')::uuid;
  exception when others then
    return jsonb_build_object('ok',false,'error','INVALID_TARGET_PAYLOAD');
  end;
  if v_distinct_count<>v_target_count then return jsonb_build_object('ok',false,'error','DUPLICATE_TARGET'); end if;
  if v_valid_count<>v_target_count then return jsonb_build_object('ok',false,'error','INVALID_CALL_ADVISOR'); end if;

  select coalesce(c.count_cache,0)::integer into v_candidate_count
  from public.aos_audience_preset_runtime_cache_v1 c where c.preset_key=v_key;
  if v_candidate_count is null then
    select count(*)::integer into v_candidate_count from public.aos_cia_workspace_catalog_members_v1(v_key);
  end if;
  v_requested:=case when coalesce(p_all_available,false) then v_candidate_count else least(p_source_limit,v_candidate_count) end;
  v_base:=floor(v_requested::numeric/v_target_count)::integer;
  v_remainder:=v_requested-(v_base*v_target_count);

  for e in
    select x.value,x.ordinality
    from jsonb_array_elements(v_targets) with ordinality x(value,ordinality)
    order by coalesce(nullif(x.value->>'priority','')::integer,(x.ordinality*10)::integer),x.ordinality
  loop
    v_idx:=v_idx+1;v_quota:=v_base+case when v_idx<=v_remainder then 1 else 0 end;v_assigned:=v_assigned+v_quota;
    v_quotas:=v_quotas||jsonb_build_array(jsonb_build_object(
      'advisor_user_id',e.value->>'advisor_user_id',
      'priority',coalesce(nullif(e.value->>'priority','')::integer,(e.ordinality*10)::integer),
      'projected_quantity',v_quota
    ));
  end loop;

  return jsonb_build_object('ok',true,'strategy','EQUAL',
    'quantity_mode',case when coalesce(p_all_available,false) then 'ALL_AVAILABLE' else 'FIXED' end,
    'candidate_count',v_candidate_count,'requested_count',v_requested,
    'source_limit',case when coalesce(p_all_available,false) then null else p_source_limit end,
    'projected_assigned',v_assigned,'remaining_after_plan',greatest(v_candidate_count-v_assigned,0),
    'target_count',v_target_count,'quotas',v_quotas,
    'execution',jsonb_build_object('enabled',false,'reason','HUMAN_CANARY_REQUIRED'),
    'source','CATALOG_COUNT_CACHE_V2','observed_at',statement_timestamp());
exception when others then
  return jsonb_build_object('ok',false,'error','DISTRIBUTION_PREVIEW_V2_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_distribution_preview_app_v2(text,text,integer,boolean,jsonb) from public;
grant execute on function public.aos_cia_distribution_preview_app_v2(text,text,integer,boolean,jsonb) to anon,authenticated;


select pg_notify('pgrst','reload schema');
commit;
