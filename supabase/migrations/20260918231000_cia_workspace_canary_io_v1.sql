-- ASCENDA OS · CIA Workspace reliability patch V1
-- Fixes: fast preview/CSV paths + missing activation context bind before one-contact canary plan.
-- Preserves fail-closed rollout: no mass distribution action is introduced.

begin;

create table if not exists public.aos_cia_contact_runtime_cache_v1 (
  contact_key text primary key,
  identity_conflict boolean,
  canonical_names text,
  canonical_surnames text,
  canonical_email text,
  patient_state text,
  crm_branch text,
  district text,
  sex text,
  age_band text,
  value_tier text,
  lifecycle text,
  engagement text,
  traits text[],
  latest_interest text,
  latest_interest_type text,
  last_call_at timestamptz,
  latest_call_status text,
  next_appointment_at date,
  sale_count integer,
  revenue_lifetime numeric,
  overdue_followup_count integer,
  pending_followup_count integer,
  exists_as_lead boolean,
  lead_unworked_since_latest_entry boolean,
  days_since_last_lead integer,
  calls_never_called boolean,
  call_count integer,
  effective_contact_count integer,
  called_today boolean,
  days_since_last_call integer,
  appointments_never_had boolean,
  has_future_appointment boolean,
  ever_no_show boolean,
  attended_count integer,
  sales_never_bought boolean,
  days_since_last_sale integer,
  email_valid boolean,
  email_never_sent boolean,
  email_opened_count integer,
  email_clicked_count integer,
  email_bounced_count integer,
  exists_as_patient boolean,
  cache_refreshed_at timestamptz not null default statement_timestamp()
);

create index if not exists idx_cia_contact_runtime_lifecycle_v1
  on public.aos_cia_contact_runtime_cache_v1(lifecycle);
create index if not exists idx_cia_contact_runtime_value_v1
  on public.aos_cia_contact_runtime_cache_v1(value_tier);
create index if not exists idx_cia_contact_runtime_branch_v1
  on public.aos_cia_contact_runtime_cache_v1(crm_branch);
create index if not exists idx_cia_contact_runtime_no_show_v1
  on public.aos_cia_contact_runtime_cache_v1(ever_no_show,has_future_appointment);

revoke all on table public.aos_cia_contact_runtime_cache_v1 from public,anon,authenticated;

create or replace function public.aos_cia_contact_runtime_refresh_v1()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_started timestamptz:=clock_timestamp();
  v_now timestamptz:=statement_timestamp();
  v_rows integer:=0;
  v_deleted integer:=0;
begin
  insert into public.aos_cia_contact_runtime_cache_v1(
    contact_key,identity_conflict,canonical_names,canonical_surnames,canonical_email,patient_state,
    crm_branch,district,sex,age_band,value_tier,lifecycle,engagement,traits,
    latest_interest,latest_interest_type,last_call_at,latest_call_status,next_appointment_at,
    sale_count,revenue_lifetime,overdue_followup_count,pending_followup_count,
    exists_as_lead,lead_unworked_since_latest_entry,days_since_last_lead,
    calls_never_called,call_count,effective_contact_count,called_today,days_since_last_call,
    appointments_never_had,has_future_appointment,ever_no_show,attended_count,
    sales_never_bought,days_since_last_sale,email_valid,email_never_sent,
    email_opened_count,email_clicked_count,email_bounced_count,exists_as_patient,cache_refreshed_at
  )
  select
    s.contact_key,s.identity_conflict,s.canonical_names,s.canonical_surnames,s.canonical_email,s.patient_state,
    s.crm_branch,s.district,s.sex,s.age_band,s.value_tier,s.lifecycle,s.engagement,s.traits,
    s.latest_interest,s.latest_interest_type,s.last_call_at,s.latest_call_status,s.next_appointment_at,
    s.sale_count,s.revenue_lifetime,s.overdue_followup_count,s.pending_followup_count,
    s.exists_as_lead,s.lead_unworked_since_latest_entry,s.days_since_last_lead,
    s.calls_never_called,s.call_count,s.effective_contact_count,s.called_today,s.days_since_last_call,
    s.appointments_never_had,s.has_future_appointment,s.ever_no_show,s.attended_count,
    s.sales_never_bought,s.days_since_last_sale,s.email_valid,s.email_never_sent,
    s.email_opened_count,s.email_clicked_count,s.email_bounced_count,s.exists_as_patient,v_now
  from public.aos_cia_audience_source_v1 s
  on conflict(contact_key) do update set
    identity_conflict=excluded.identity_conflict,
    canonical_names=excluded.canonical_names,
    canonical_surnames=excluded.canonical_surnames,
    canonical_email=excluded.canonical_email,
    patient_state=excluded.patient_state,
    crm_branch=excluded.crm_branch,
    district=excluded.district,
    sex=excluded.sex,
    age_band=excluded.age_band,
    value_tier=excluded.value_tier,
    lifecycle=excluded.lifecycle,
    engagement=excluded.engagement,
    traits=excluded.traits,
    latest_interest=excluded.latest_interest,
    latest_interest_type=excluded.latest_interest_type,
    last_call_at=excluded.last_call_at,
    latest_call_status=excluded.latest_call_status,
    next_appointment_at=excluded.next_appointment_at,
    sale_count=excluded.sale_count,
    revenue_lifetime=excluded.revenue_lifetime,
    overdue_followup_count=excluded.overdue_followup_count,
    pending_followup_count=excluded.pending_followup_count,
    exists_as_lead=excluded.exists_as_lead,
    lead_unworked_since_latest_entry=excluded.lead_unworked_since_latest_entry,
    days_since_last_lead=excluded.days_since_last_lead,
    calls_never_called=excluded.calls_never_called,
    call_count=excluded.call_count,
    effective_contact_count=excluded.effective_contact_count,
    called_today=excluded.called_today,
    days_since_last_call=excluded.days_since_last_call,
    appointments_never_had=excluded.appointments_never_had,
    has_future_appointment=excluded.has_future_appointment,
    ever_no_show=excluded.ever_no_show,
    attended_count=excluded.attended_count,
    sales_never_bought=excluded.sales_never_bought,
    days_since_last_sale=excluded.days_since_last_sale,
    email_valid=excluded.email_valid,
    email_never_sent=excluded.email_never_sent,
    email_opened_count=excluded.email_opened_count,
    email_clicked_count=excluded.email_clicked_count,
    email_bounced_count=excluded.email_bounced_count,
    exists_as_patient=excluded.exists_as_patient,
    cache_refreshed_at=excluded.cache_refreshed_at;

  get diagnostics v_rows=row_count;

  delete from public.aos_cia_contact_runtime_cache_v1
  where cache_refreshed_at < v_now;
  get diagnostics v_deleted=row_count;

  return jsonb_build_object(
    'ok',true,
    'rows',v_rows,
    'deleted',v_deleted,
    'refreshed_at',v_now,
    'duration_ms',greatest(0,round(extract(epoch from(clock_timestamp()-v_started))*1000)::integer)
  );
exception when others then
  return jsonb_build_object('ok',false,'error','CONTACT_RUNTIME_REFRESH_FAILED','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_contact_runtime_refresh_v1() from public,anon,authenticated;

create or replace function public.aos_cia_catalog_refresh_counts_v1()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_started timestamptz:=clock_timestamp();
  v_finished timestamptz;
  v_counts jsonb;
  v_key text;
  v_value text;
  v_duration integer;
  v_contacts jsonb;
begin
  v_contacts:=public.aos_cia_contact_runtime_refresh_v1();
  if not coalesce((v_contacts->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','CATALOG_CONTACT_REFRESH_FAILED','detail',v_contacts);
  end if;

  select jsonb_build_object(
    '__ALL__',count(*),
    'ALL_LEADS',count(*) filter(where exists_as_lead),
    'LEAD_SERVICE_INTEREST',count(*) filter(where latest_interest_type='SERVICIO'),
    'LEAD_PRODUCT_INTEREST',count(*) filter(where latest_interest_type='PRODUCTO'),
    'LEADS_UNWORKED',count(*) filter(where lead_unworked_since_latest_entry),
    'LEADS_UNWORKED_7D',count(*) filter(where lead_unworked_since_latest_entry and days_since_last_lead<=7),

    'NEVER_CALLED_CONTACTS',count(*) filter(where calls_never_called),
    'CALLED_NO_EFFECTIVE_CONTACT',count(*) filter(where call_count>0 and effective_contact_count=0),
    'EFFECTIVE_CONTACTS',count(*) filter(where effective_contact_count>0),
    'CALLED_TODAY',count(*) filter(where called_today),
    'CALL_STALE_7D',count(*) filter(where days_since_last_call>7),
    'CALL_STALE_30D',count(*) filter(where days_since_last_call>30),

    'NEVER_APPOINTED',count(*) filter(where appointments_never_had),
    'HAS_FUTURE_APPOINTMENT',count(*) filter(where has_future_appointment),
    'EVER_NO_SHOW',count(*) filter(where ever_no_show),
    'ATTENDED_APPOINTMENT',count(*) filter(where attended_count>0),
    'NO_SHOW_NO_FUTURE',count(*) filter(where ever_no_show and not has_future_appointment),

    'NEVER_BOUGHT',count(*) filter(where sales_never_bought),
    'RECENT_BUYERS_30D',count(*) filter(where days_since_last_sale<=30),
    'DORMANT_BUYERS_90D',count(*) filter(where days_since_last_sale>90),
    'PRODUCT_BUYERS',count(*) filter(where traits @> array['PRODUCT_BUYER']::text[]),
    'SERVICE_BUYERS',count(*) filter(where traits @> array['SERVICE_BUYER']::text[]),

    'PENDING_FOLLOWUPS',count(*) filter(where pending_followup_count>0),
    'FOLLOWUP_OVERDUE',count(*) filter(where overdue_followup_count>0),

    'EMAIL_VALID',count(*) filter(where email_valid),
    'EMAIL_OPENED',count(*) filter(where email_opened_count>0),
    'EMAIL_CLICKED',count(*) filter(where email_clicked_count>0),
    'EMAIL_BOUNCED',count(*) filter(where email_bounced_count>0),
    'NEVER_EMAILED_KNOWN',count(*) filter(where email_never_sent),

    'PATIENTS',count(*) filter(where exists_as_patient),
    'IDENTITY_CONFLICT',count(*) filter(where identity_conflict),

    'ACTIVE_CUSTOMERS',count(*) filter(where lifecycle='ACTIVE_CUSTOMER'),
    'NEW_CUSTOMERS',count(*) filter(where lifecycle='NEW_CUSTOMER'),
    'WARM_PROSPECTS',count(*) filter(where lifecycle='WARM_PROSPECT'),
    'COLD_PROSPECTS',count(*) filter(where lifecycle='COLD_PROSPECT'),
    'GOLD_CUSTOMERS',count(*) filter(where value_tier='GOLD'),
    'DIAMOND_CUSTOMERS',count(*) filter(where value_tier='DIAMANTE'),
    'INACTIVE_CUSTOMERS',count(*) filter(where lifecycle='INACTIVE_CUSTOMER'),
    'HIGH_VALUE_COOLING',count(*) filter(where value_tier in ('GOLD','DIAMANTE') and lifecycle in ('COOLING_CUSTOMER','INACTIVE_CUSTOMER')),
    'ACTIVE_PROSPECTS',count(*) filter(where lifecycle in ('ACTIVE_PROSPECT','APPOINTMENT_READY_PROSPECT')),

    'AGE_18_24',count(*) filter(where age_band='18_24'),
    'AGE_25_34',count(*) filter(where age_band='25_34'),
    'AGE_35_44',count(*) filter(where age_band='35_44'),
    'AGE_45_54',count(*) filter(where age_band='45_54'),
    'AGE_55_64',count(*) filter(where age_band='55_64'),
    'AGE_65_PLUS',count(*) filter(where age_band='65_PLUS'),
    'SEX_FEMALE',count(*) filter(where sex='F'),
    'SEX_MALE',count(*) filter(where sex='M')
  )
  into v_counts
  from public.aos_cia_contact_runtime_cache_v1;

  v_finished:=clock_timestamp();
  v_duration:=greatest(0,round(extract(epoch from(v_finished-v_started))*1000)::integer);

  for v_key,v_value in select key,value from jsonb_each_text(v_counts)
  loop
    insert into public.aos_audience_preset_runtime_cache_v1(
      preset_key,count_cache,refreshed_at,duration_ms,status,error_code,updated_at
    ) values(
      v_key,v_value::bigint,v_finished,v_duration,'READY',null,v_finished
    )
    on conflict(preset_key) do update
      set count_cache=excluded.count_cache,
          refreshed_at=excluded.refreshed_at,
          duration_ms=excluded.duration_ms,
          status='READY',
          error_code=null,
          updated_at=excluded.updated_at;
  end loop;

  return jsonb_build_object(
    'ok',true,
    'counts',v_counts,
    'contact_cache',v_contacts,
    'refreshed_at',v_finished,
    'duration_ms',v_duration
  );
exception when others then
  return jsonb_build_object('ok',false,'error','CATALOG_REFRESH_FAILED','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_catalog_refresh_counts_v1() from public,anon,authenticated;

create or replace function public.aos_cia_control_center_app_v5(
  p_app_token text,
  p_action text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_started timestamptz:=clock_timestamp();
  v_action text:=upper(btrim(coalesce(p_action,'')));
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_auth jsonb;
  v_uid uuid;
  v_name text;
  v_role text;
  v_assurance text;
  v_panels text[];
  v_all boolean:=false;
  v_filter jsonb;
  v_validation jsonb;
  v_keys text[];
  v_limit integer;
  v_offset integer;
  v_count integer:=0;
  v_items jsonb;
  v_csv text;
  v_out jsonb;
  v_session jsonb;
  v_cia_token text;
  v_activation jsonb;
  v_context jsonb;
  v_plan_create jsonb;
  v_plan_transition jsonb;
  v_advisor_route jsonb;
  v_global_route jsonb;
  v_activation_id uuid;
  v_plan_id uuid;
  v_advisor_id uuid;
  v_audience_id uuid;
  v_version integer;
  v_requested_limit integer;
  v_key text;
begin
  if v_action not in ('PREVIEW_CATALOG','EXPORT_CSV_FAST','START_CANARY_ASSIGNMENT') then
    return public.aos_cia_control_center_app_v4(p_app_token,v_action,v_payload);
  end if;

  v_auth:=public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;

  v_uid:=(v_auth->>'user_id')::uuid;
  v_name:=coalesce(v_auth->>'nombre','');
  v_role:=upper(coalesce(v_auth->>'rol',''));
  v_assurance:=upper(coalesce(v_auth->>'assurance_level',''));

  select coalesce(u.paneles_acceso,'{}'::text[])
    into v_panels
  from public.aos_usuarios u
  where u.id=v_uid and u.activo=true;

  if v_role<>'ADMIN'
     or v_assurance<>'PASSWORD_2FA'
     or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;

  if jsonb_typeof(v_payload)<>'object' or pg_column_size(v_payload)>65536 then
    return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
  end if;

  if v_action in ('PREVIEW_CATALOG','EXPORT_CSV_FAST') then
    v_all:=coalesce((v_payload->>'all_contacts')::boolean,false);
    if not v_all then
      v_filter:=v_payload->'filter';
      v_validation:=public.aos_cia_audience_validate_v1(v_filter);
      if not coalesce((v_validation->>'valid')::boolean,false) then
        v_out:=jsonb_build_object('ok',false,'error','INVALID_AUDIENCE_FILTER','validation',v_validation);
      else
        v_keys:=public.aos_cia_audience_resolve_node_v2(v_filter->'root',1);
        v_count:=cardinality(v_keys);
      end if;
    else
      select count(*)::integer into v_count from public.aos_cia_contact_runtime_cache_v1;
    end if;
  end if;

  if v_out is null and v_action='PREVIEW_CATALOG' then
    v_limit:=greatest(1,least(coalesce(nullif(v_payload->>'limit','')::integer,25),100));
    v_offset:=greatest(0,coalesce(nullif(v_payload->>'offset','')::integer,0));

    select coalesce(jsonb_agg(jsonb_build_object(
      'contact_key',q.contact_key,
      'name',nullif(trim(concat_ws(' ',q.canonical_names,q.canonical_surnames)),''),
      'email',q.canonical_email,
      'branch',q.crm_branch,
      'district',q.district,
      'sex',q.sex,
      'age_band',q.age_band,
      'patient_state',q.patient_state,
      'value_tier',q.value_tier,
      'lifecycle',q.lifecycle,
      'engagement',q.engagement,
      'latest_interest',q.latest_interest,
      'latest_call_status',q.latest_call_status,
      'last_call_at',q.last_call_at,
      'next_appointment_at',q.next_appointment_at,
      'sale_count',q.sale_count,
      'revenue_lifetime',q.revenue_lifetime,
      'overdue_followups',q.overdue_followup_count,
      'cache_refreshed_at',q.cache_refreshed_at
    ) order by q.contact_key),'[]'::jsonb)
    into v_items
    from (
      select c.*
      from public.aos_cia_contact_runtime_cache_v1 c
      where v_all or c.contact_key=any(v_keys)
      order by c.contact_key
      limit v_limit offset v_offset
    ) q;

    v_out:=jsonb_build_object(
      'ok',true,
      'count',v_count,
      'limit',v_limit,
      'offset',v_offset,
      'items',v_items,
      'source','CONTACT_RUNTIME_CACHE_V1',
      'observed_at',statement_timestamp()
    );

  elsif v_out is null and v_action='EXPORT_CSV_FAST' then
    if v_count>20000 then
      v_out:=jsonb_build_object('ok',false,'error','EXPORT_LIMIT_EXCEEDED','row_count',v_count,'max_rows',20000);
    else
      select
        'telefono,nombres,apellidos,email,sede,distrito,sexo,rango_edad,estado_paciente,nivel_valor,lifecycle,engagement,ultimo_interes,ultima_llamada,estado_ultima_llamada,proxima_cita,compras,facturacion,seguimientos_vencidos' || chr(10) ||
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
          coalesce(c.sale_count,0)::text||','||
          coalesce(c.revenue_lifetime,0)::text||','||
          coalesce(c.overdue_followup_count,0)::text,
          chr(10) order by c.contact_key
        ),'')
      into v_csv
      from public.aos_cia_contact_runtime_cache_v1 c
      where v_all or c.contact_key=any(v_keys);

      v_out:=jsonb_build_object(
        'ok',true,
        'row_count',v_count,
        'filename',coalesce(nullif(v_payload->>'filename',''),'audiencia')||'-'||to_char(statement_timestamp(),'YYYYMMDD-HH24MI')||'.csv',
        'csv',v_csv,
        'source','CONTACT_RUNTIME_CACHE_V1',
        'observed_at',statement_timestamp()
      );
    end if;

  elsif v_action='START_CANARY_ASSIGNMENT' then
    begin
      v_audience_id:=nullif(v_payload->>'audience_id','')::uuid;
      v_version:=nullif(v_payload->>'version','')::integer;
      v_advisor_id:=nullif(v_payload->>'advisor_user_id','')::uuid;
      v_requested_limit:=coalesce(nullif(v_payload->>'source_limit','')::integer,1);
    exception when others then
      v_out:=jsonb_build_object('ok',false,'error','INVALID_CANARY_PAYLOAD');
    end;

    if v_out is null and v_requested_limit<>1 then
      v_out:=jsonb_build_object('ok',false,'error','CANARY_SOURCE_LIMIT_MUST_BE_ONE');
    end if;

    if v_out is null and exists(
      select 1 from public.aos_cia_assignment_plans p
      where p.state in ('DRAFT','ACTIVE','PAUSED')
        and p.metadata @> jsonb_build_object('pack','B','canary',1)
    ) then
      v_out:=jsonb_build_object('ok',false,'error','CANARY_ALREADY_ACTIVE');
    end if;

    if v_out is null and (
      coalesce((select c.global_enabled from public.aos_cia_call_routing_control c where c.id=1),false)
      or exists(select 1 from public.aos_cia_call_routing_advisors r where r.mode<>'V2_ONLY')
    ) then
      v_out:=jsonb_build_object('ok',false,'error','ROUTING_NOT_BASELINE');
    end if;

    if v_out is null and not exists(
      select 1 from public.aos_usuarios u
      where u.id=v_advisor_id
        and u.activo=true
        and lower(coalesce(u.rol,''))='asesor'
        and coalesce(u.paneles_acceso,'{}'::text[]) @> array['advisor-calls']::text[]
    ) then
      v_out:=jsonb_build_object('ok',false,'error','INVALID_CALL_ADVISOR');
    end if;

    if v_out is null then
      v_session:=public.aos_cia_issue_admin_session_v1(v_name);
      if not coalesce((v_session->>'ok')::boolean,false) then
        v_out:=jsonb_build_object('ok',false,'error','CIA_SESSION_EXCHANGE_FAILED');
      else
        v_cia_token:=v_session->>'token';
      end if;
    end if;

    if v_out is null then
      v_activation:=public.aos_cia_activation_create_admin_v1(
        v_cia_token,v_audience_id,v_version,
        left(coalesce(nullif(v_payload->>'name',''),'Prueba segura Call Center'),120),
        'HUMAN_CANARY_PACK_B','CALL','BATCH',true,
        jsonb_build_object('pack','B','canary',1,'owner_user_id',v_uid,'reversible',true)
      );

      if not coalesce((v_activation->>'ok')::boolean,false) then
        v_out:=v_activation;
      else
        v_activation_id:=(v_activation->>'activation_id')::uuid;

        v_context:=public.aos_cia_activation_context_bind_admin_v1(
          v_cia_token,v_activation_id,null,null
        );

        if not coalesce((v_context->>'ok')::boolean,false) then
          perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
          v_out:=jsonb_build_object('ok',false,'error','CONTEXT_BIND_FAILED','detail',v_context);
        else
          v_key:='pack-b-canary-'||v_activation_id::text;

          v_plan_create:=public.aos_cia_assignment_plan_create_admin_v1(
            v_cia_token,v_activation_id,'ONE',
            jsonb_build_array(jsonb_build_object('advisor_user_id',v_advisor_id)),
            'ACTIVATION',1,480,120,'NONE',null,true,true,v_key,
            jsonb_build_object('pack','B','canary',1,'owner_user_id',v_uid,'reversible',true)
          );

          if not coalesce((v_plan_create->>'ok')::boolean,false) then
            perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
            v_out:=v_plan_create;
          else
            v_plan_id:=(v_plan_create->>'plan_id')::uuid;
            v_plan_transition:=public.aos_cia_assignment_plan_transition_admin_v1(v_cia_token,v_plan_id,'ACTIVATE');

            if not coalesce((v_plan_transition->>'ok')::boolean,false) then
              perform public.aos_cia_assignment_plan_transition_admin_v1(v_cia_token,v_plan_id,'CANCEL');
              perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
              v_out:=v_plan_transition;
            else
              v_advisor_route:=public.aos_cia_call_routing_admin_v1(
                v_cia_token,'SET_ADVISOR',
                jsonb_build_object(
                  'advisor_user_id',v_advisor_id,
                  'mode','V3_CANARY',
                  'metadata',jsonb_build_object('pack','B','canary',1,'plan_id',v_plan_id)
                )
              );

              if not coalesce((v_advisor_route->>'ok')::boolean,false) then
                perform public.aos_cia_assignment_plan_transition_admin_v1(v_cia_token,v_plan_id,'CANCEL');
                perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
                v_out:=v_advisor_route;
              else
                v_global_route:=public.aos_cia_call_routing_admin_v1(
                  v_cia_token,'SET_GLOBAL',
                  jsonb_build_object(
                    'enabled',true,
                    'metadata',jsonb_build_object('pack','B','canary',1,'plan_id',v_plan_id)
                  )
                );

                if not coalesce((v_global_route->>'ok')::boolean,false) then
                  perform public.aos_cia_call_routing_admin_v1(
                    v_cia_token,'CLEAR_ADVISOR',
                    jsonb_build_object('advisor_user_id',v_advisor_id)
                  );
                  perform public.aos_cia_assignment_plan_transition_admin_v1(v_cia_token,v_plan_id,'CANCEL');
                  perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
                  v_out:=v_global_route;
                else
                  v_out:=jsonb_build_object(
                    'ok',true,
                    'activation',v_activation,
                    'context',v_context,
                    'plan',jsonb_build_object(
                      'plan_id',v_plan_id,
                      'state','ACTIVE',
                      'source_available_now',v_plan_create->'source_available_now'
                    ),
                    'routing',jsonb_build_object('advisor',v_advisor_route,'global',v_global_route),
                    'source_limit',1,
                    'reversible',true,
                    'instruction','OPEN_CALL_CENTER_AS_SELECTED_ADVISOR'
                  );
                end if;
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end if;

  if v_cia_token is not null then
    update public.aos_cia_admin_sessions
    set revoked=true
    where token_hash=encode(extensions.digest(v_cia_token,'sha256'),'hex');
  end if;

  insert into public.aos_cia_gateway_audit(user_id,usuario,action,ok,duration_ms,meta)
  values(
    v_uid,v_name,v_action,coalesce((v_out->>'ok')::boolean,false),
    greatest(0,round(extract(epoch from(clock_timestamp()-v_started))*1000)::integer),
    jsonb_build_object(
      'gateway_version',5,
      'audience_id',coalesce(v_payload->>'audience_id',''),
      'all_contacts',v_all,
      'row_count',coalesce(v_out->>'row_count',v_out->>'count')
    )
  );

  return coalesce(v_out,jsonb_build_object('ok',false,'error','EMPTY_RESULT'));
exception
  when invalid_text_representation or numeric_value_out_of_range then
    if v_cia_token is not null then
      update public.aos_cia_admin_sessions
      set revoked=true
      where token_hash=encode(extensions.digest(v_cia_token,'sha256'),'hex');
    end if;
    return jsonb_build_object('ok',false,'error','INVALID_WORKSPACE_PAYLOAD');
  when others then
    if v_cia_token is not null then
      update public.aos_cia_admin_sessions
      set revoked=true
      where token_hash=encode(extensions.digest(v_cia_token,'sha256'),'hex');
    end if;
    return jsonb_build_object('ok',false,'error','CONTROL_CENTER_V5_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_control_center_app_v5(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v5(text,text,jsonb) to anon,authenticated;

comment on function public.aos_cia_control_center_app_v5(text,text,jsonb)
is 'CIA Workspace reliability gateway. Fast cached preview/CSV and one-contact canary with required CALL context binding. Bulk distribution remains unavailable.';

select public.aos_cia_contact_runtime_refresh_v1();
select public.aos_cia_catalog_refresh_counts_v1();

select pg_notify('pgrst','reload schema');

commit;
