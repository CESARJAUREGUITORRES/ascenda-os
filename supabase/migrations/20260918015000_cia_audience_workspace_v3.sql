-- ASCENDA OS · CIA Audience Workspace V3
-- Catalog-first control plane built on canonical facts + Audience -> Activation -> Assignment.
-- No parallel CRM, no automatic sends, no routing enablement.

begin;

with seed(preset_key,name,description,category,dsl) as (
  values
    ('ALL_LEADS','Todos los leads','Contactos que existen como lead','LEAD','{"version":1,"root":{"op":"AND","rules":[{"field":"contact.exists_as_lead","operator":"is_true"}]}}'::jsonb),
    ('LEAD_SERVICE_INTEREST','Interés actual en servicios','Último interés identificado como servicio','LEAD','{"version":1,"root":{"op":"AND","rules":[{"field":"lead.latest_interest_type","operator":"eq","value":"SERVICIO"}]}}'::jsonb),
    ('LEAD_PRODUCT_INTEREST','Interés actual en productos','Último interés identificado como producto','LEAD','{"version":1,"root":{"op":"AND","rules":[{"field":"lead.latest_interest_type","operator":"eq","value":"PRODUCTO"}]}}'::jsonb),

    ('NEVER_CALLED_CONTACTS','Nunca llamados','Contactos sin ninguna llamada registrada','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.never_called","operator":"is_true"}]}}'::jsonb),
    ('CALLED_NO_EFFECTIVE_CONTACT','Llamados sin contacto efectivo','Tienen llamadas, pero ninguna conversación efectiva','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.total","operator":"gt","value":0},{"field":"calls.effective_contact_count","operator":"eq","value":0}]}}'::jsonb),
    ('EFFECTIVE_CONTACTS','Con contacto efectivo','Contactos con al menos una comunicación efectiva','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.effective_contact_count","operator":"gt","value":0}]}}'::jsonb),
    ('CALLED_TODAY','Llamados hoy','Contactos que ya recibieron una llamada hoy','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.called_today","operator":"is_true"}]}}'::jsonb),
    ('CALL_STALE_7D','Sin llamada en más de 7 días','La última llamada fue hace más de 7 días','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.days_since_last","operator":"gt","value":7}]}}'::jsonb),
    ('CALL_STALE_30D','Sin llamada en más de 30 días','La última llamada fue hace más de 30 días','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.days_since_last","operator":"gt","value":30}]}}'::jsonb),

    ('NEVER_APPOINTED','Nunca tuvieron cita','Contactos sin historial de citas','APPOINTMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.never_had","operator":"is_true"}]}}'::jsonb),
    ('HAS_FUTURE_APPOINTMENT','Con cita futura','Contactos que ya tienen una próxima cita','APPOINTMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.has_future","operator":"is_true"}]}}'::jsonb),
    ('EVER_NO_SHOW','Con historial de no-show','Contactos que alguna vez faltaron a una cita','APPOINTMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.ever_no_show","operator":"is_true"}]}}'::jsonb),
    ('ATTENDED_APPOINTMENT','Con asistencia registrada','Contactos que asistieron al menos a una cita','APPOINTMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.attended_count","operator":"gt","value":0}]}}'::jsonb),

    ('NEVER_BOUGHT','Nunca compraron','Contactos sin compra registrada','SALE','{"version":1,"root":{"op":"AND","rules":[{"field":"sales.never_bought","operator":"is_true"}]}}'::jsonb),
    ('RECENT_BUYERS_30D','Compraron en los últimos 30 días','Clientes con compra reciente','SALE','{"version":1,"root":{"op":"AND","rules":[{"field":"sales.days_since_last","operator":"lte","value":30}]}}'::jsonb),
    ('DORMANT_BUYERS_90D','Sin comprar hace más de 90 días','Clientes cuya última compra fue hace más de 90 días','SALE','{"version":1,"root":{"op":"AND","rules":[{"field":"sales.days_since_last","operator":"gt","value":90}]}}'::jsonb),

    ('PENDING_FOLLOWUPS','Seguimientos pendientes','Contactos con uno o más seguimientos pendientes','FOLLOWUP','{"version":1,"root":{"op":"AND","rules":[{"field":"followups.pending_count","operator":"gt","value":0}]}}'::jsonb),

    ('EMAIL_VALID','Con email válido','Contactos con email identificado como válido','EMAIL','{"version":1,"root":{"op":"AND","rules":[{"field":"contact.email_valid","operator":"is_true"}]}}'::jsonb),
    ('EMAIL_OPENED','Abrieron algún email','Contactos con al menos una apertura registrada','EMAIL','{"version":1,"root":{"op":"AND","rules":[{"field":"email.opened_count","operator":"gt","value":0}]}}'::jsonb),
    ('EMAIL_CLICKED','Hicieron clic en algún email','Contactos con al menos un clic registrado','EMAIL','{"version":1,"root":{"op":"AND","rules":[{"field":"email.clicked_count","operator":"gt","value":0}]}}'::jsonb),
    ('EMAIL_BOUNCED','Con rebote de email','Contactos con al menos un rebote registrado','EMAIL','{"version":1,"root":{"op":"AND","rules":[{"field":"email.bounced_count","operator":"gt","value":0}]}}'::jsonb),

    ('PATIENTS','Pacientes identificados','Contactos que existen como paciente','CONTACT','{"version":1,"root":{"op":"AND","rules":[{"field":"contact.exists_as_patient","operator":"is_true"}]}}'::jsonb),
    ('IDENTITY_CONFLICT','Identidad por revisar','Contactos con conflicto de identidad detectado','CONTACT','{"version":1,"root":{"op":"AND","rules":[{"field":"contact.identity_conflict","operator":"is_true"}]}}'::jsonb),

    ('ACTIVE_CUSTOMERS','Clientes activos','Clientes con lifecycle ACTIVE_CUSTOMER','SEGMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.lifecycle","operator":"eq","value":"ACTIVE_CUSTOMER"}]}}'::jsonb),
    ('NEW_CUSTOMERS','Clientes nuevos','Clientes con lifecycle NEW_CUSTOMER','SEGMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.lifecycle","operator":"eq","value":"NEW_CUSTOMER"}]}}'::jsonb),
    ('WARM_PROSPECTS','Prospectos tibios','Prospectos con lifecycle WARM_PROSPECT','SEGMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.lifecycle","operator":"eq","value":"WARM_PROSPECT"}]}}'::jsonb),
    ('COLD_PROSPECTS','Prospectos fríos','Prospectos con lifecycle COLD_PROSPECT','SEGMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.lifecycle","operator":"eq","value":"COLD_PROSPECT"}]}}'::jsonb),
    ('GOLD_CUSTOMERS','Clientes Gold','Contactos clasificados en nivel Gold','SEGMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.value_tier","operator":"eq","value":"GOLD"}]}}'::jsonb),
    ('DIAMOND_CUSTOMERS','Clientes Diamante','Contactos clasificados en nivel Diamante','SEGMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"segment.value_tier","operator":"eq","value":"DIAMANTE"}]}}'::jsonb),

    ('AGE_18_24','Edad 18–24','Contactos entre 18 y 24 años','DEMOGRAPHIC','{"version":1,"root":{"op":"AND","rules":[{"field":"crm.age_band","operator":"eq","value":"18_24"}]}}'::jsonb),
    ('AGE_25_34','Edad 25–34','Contactos entre 25 y 34 años','DEMOGRAPHIC','{"version":1,"root":{"op":"AND","rules":[{"field":"crm.age_band","operator":"eq","value":"25_34"}]}}'::jsonb),
    ('AGE_35_44','Edad 35–44','Contactos entre 35 y 44 años','DEMOGRAPHIC','{"version":1,"root":{"op":"AND","rules":[{"field":"crm.age_band","operator":"eq","value":"35_44"}]}}'::jsonb),
    ('AGE_45_54','Edad 45–54','Contactos entre 45 y 54 años','DEMOGRAPHIC','{"version":1,"root":{"op":"AND","rules":[{"field":"crm.age_band","operator":"eq","value":"45_54"}]}}'::jsonb),
    ('AGE_55_64','Edad 55–64','Contactos entre 55 y 64 años','DEMOGRAPHIC','{"version":1,"root":{"op":"AND","rules":[{"field":"crm.age_band","operator":"eq","value":"55_64"}]}}'::jsonb),
    ('AGE_65_PLUS','Edad 65+','Contactos de 65 años a más','DEMOGRAPHIC','{"version":1,"root":{"op":"AND","rules":[{"field":"crm.age_band","operator":"eq","value":"65_PLUS"}]}}'::jsonb),
    ('SEX_FEMALE','Mujeres','Contactos identificados con sexo F','DEMOGRAPHIC','{"version":1,"root":{"op":"AND","rules":[{"field":"crm.sex","operator":"eq","value":"F"}]}}'::jsonb),
    ('SEX_MALE','Hombres','Contactos identificados con sexo M','DEMOGRAPHIC','{"version":1,"root":{"op":"AND","rules":[{"field":"crm.sex","operator":"eq","value":"M"}]}}'::jsonb)
)
insert into public.aos_audience_presets(preset_key,name,description,category,dsl,registry_version,active)
select s.preset_key,s.name,s.description,s.category,s.dsl,1,true
from seed s
on conflict (preset_key) do nothing;

create table if not exists public.aos_audience_preset_runtime_cache_v1 (
  preset_key text primary key,
  count_cache bigint,
  refreshed_at timestamptz,
  duration_ms integer,
  status text not null default 'EMPTY',
  error_code text,
  updated_at timestamptz not null default statement_timestamp()
);

revoke all on table public.aos_audience_preset_runtime_cache_v1 from public,anon,authenticated;

create or replace function public.aos_cia_catalog_refresh_counts_v1()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_started timestamptz := clock_timestamp();
  v_finished timestamptz;
  v_counts jsonb;
  v_key text;
  v_value text;
  v_duration integer;
begin
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
  from public.aos_cia_audience_source_v1;

  v_finished := clock_timestamp();
  v_duration := greatest(0,round(extract(epoch from(v_finished-v_started))*1000)::integer);

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
    'refreshed_at',v_finished,
    'duration_ms',v_duration
  );
exception when others then
  return jsonb_build_object('ok',false,'error','CATALOG_REFRESH_FAILED','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_catalog_refresh_counts_v1() from public,anon,authenticated;

create or replace function public.aos_cia_control_center_app_v3(
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
  v_action text := upper(btrim(coalesce(p_action,'')));
  v_payload jsonb := coalesce(p_payload,'{}'::jsonb);
  v_auth jsonb;
  v_uid uuid;
  v_role text;
  v_assurance text;
  v_panels text[];
  v_presets jsonb;
  v_filters jsonb;
  v_categories jsonb;
  v_items jsonb;
  v_filter jsonb;
  v_validation jsonb;
  v_keys text[];
  v_count integer;
  v_csv text;
  v_all boolean := false;
  v_activity jsonb;
begin
  if v_action not in ('CATALOG_META','REFRESH_CATALOG','PREVIEW_ALL','EXPORT_CSV','ACTIVITY_SUMMARY') then
    return public.aos_cia_control_center_app_v2(p_app_token,v_action,v_payload);
  end if;

  v_auth := public.aos_cia_verify_app_session_v1(p_app_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_uid := (v_auth->>'user_id')::uuid;
  v_role := upper(coalesce(v_auth->>'rol',''));
  v_assurance := upper(coalesce(v_auth->>'assurance_level',''));

  select coalesce(u.paneles_acceso,'{}'::text[]) into v_panels
  from public.aos_usuarios u where u.id=v_uid and u.activo=true;

  if v_role <> 'ADMIN' or v_assurance <> 'PASSWORD_2FA' or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;
  if jsonb_typeof(v_payload) <> 'object' or pg_column_size(v_payload) > 65536 then
    return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD');
  end if;

  if v_action='CATALOG_META' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'preset_key',p.preset_key,
      'name',p.name,
      'description',p.description,
      'category',p.category,
      'dsl',p.dsl,
      'registry_version',p.registry_version,
      'count_cache',c.count_cache,
      'count_refreshed_at',c.refreshed_at,
      'count_status',coalesce(c.status,'EMPTY')
    ) order by p.category,p.name),'[]'::jsonb)
    into v_presets
    from public.aos_audience_presets p
    left join public.aos_audience_preset_runtime_cache_v1 c on c.preset_key=p.preset_key
    where p.active=true;

    select coalesce(jsonb_agg(jsonb_build_object(
      'field_key',r.field_key,'label',r.label,'category',r.category,
      'data_type',r.data_type,'allowed_operators',r.allowed_operators,
      'enum_values',r.enum_values,'description',r.description
    ) order by r.category,r.label),'[]'::jsonb)
    into v_filters
    from public.aos_audience_filter_registry r
    where r.active=true and r.ui_visible=true;

    select coalesce(jsonb_agg(jsonb_build_object(
      'category',x.category,'field_count',x.field_count
    ) order by x.category),'[]'::jsonb)
    into v_categories
    from (
      select r.category,count(*)::integer field_count
      from public.aos_audience_filter_registry r
      where r.active=true and r.ui_visible=true
      group by r.category
    ) x;

    return jsonb_build_object(
      'ok',true,
      'total_contacts',coalesce(
        (select count_cache::integer from public.aos_audience_preset_runtime_cache_v1 where preset_key='__ALL__'),
        (select count(*)::integer from public.aos_cia_segment_runtime_cache_v2)
      ),
      'preset_count',jsonb_array_length(v_presets),
      'presets',v_presets,
      'filters',v_filters,
      'categories',v_categories,
      'catalog_refreshed_at',(select refreshed_at from public.aos_audience_preset_runtime_cache_v1 where preset_key='__ALL__'),
      'freshness',jsonb_build_object(
        'segments',(select max(cache_refreshed_at) from public.aos_cia_segment_runtime_cache_v2),
        'email',(select max(cache_refreshed_at) from public.aos_cia_email_runtime_cache_v2)
      ),
      'observed_at',statement_timestamp()
    );
  end if;

  if v_action='REFRESH_CATALOG' then
    return public.aos_cia_catalog_refresh_counts_v1();
  end if;

  if v_action='PREVIEW_ALL' then
    select coalesce(jsonb_agg(to_jsonb(q) order by q.contact_key),'[]'::jsonb)
    into v_items
    from (
      select
        s.contact_key,
        nullif(trim(concat_ws(' ',s.canonical_names,s.canonical_surnames)),'') as name,
        s.canonical_email as email,
        s.crm_branch as branch,
        s.district,
        s.sex,
        s.age_band,
        s.value_tier,
        s.lifecycle,
        s.engagement,
        s.latest_interest,
        s.latest_call_status,
        s.next_appointment_at,
        s.sale_count,
        s.revenue_lifetime
      from public.aos_cia_audience_source_v1 s
      order by s.contact_key
      limit greatest(1,least(coalesce(nullif(v_payload->>'limit','')::integer,25),100))
      offset greatest(0,coalesce(nullif(v_payload->>'offset','')::integer,0))
    ) q;

    return jsonb_build_object(
      'ok',true,
      'count',coalesce(
        (select count_cache::integer from public.aos_audience_preset_runtime_cache_v1 where preset_key='__ALL__'),
        jsonb_array_length(v_items)
      ),
      'items',v_items,
      'observed_at',statement_timestamp()
    );
  end if;

  if v_action='EXPORT_CSV' then
    v_all := coalesce((v_payload->>'all_contacts')::boolean,false);
    if not v_all then
      v_filter := v_payload->'filter';
      v_validation := public.aos_cia_audience_validate_v1(v_filter);
      if not coalesce((v_validation->>'valid')::boolean,false) then
        return jsonb_build_object('ok',false,'error','INVALID_AUDIENCE_FILTER','validation',v_validation);
      end if;
      v_keys := public.aos_cia_audience_resolve_node_v2(v_filter->'root',1);
      v_count := cardinality(v_keys);
    else
      v_count := coalesce(
        (select count_cache::integer from public.aos_audience_preset_runtime_cache_v1 where preset_key='__ALL__'),
        (select count(*)::integer from public.aos_cia_segment_runtime_cache_v2)
      );
    end if;

    if v_count > 20000 then
      return jsonb_build_object('ok',false,'error','EXPORT_LIMIT_EXCEEDED','row_count',v_count,'max_rows',20000);
    end if;

    select
      'telefono,nombres,apellidos,email,sede,distrito,sexo,rango_edad,lifecycle,nivel_valor,engagement,ultimo_interes,ultima_llamada,estado_ultima_llamada,proxima_cita,compras,facturacion,seguimientos_vencidos' || chr(10) ||
      coalesce(string_agg(
        '"'||replace(coalesce(s.contact_key,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.canonical_names,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.canonical_surnames,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.canonical_email,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.crm_branch,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.district,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.sex,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.age_band,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.lifecycle,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.value_tier,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.engagement,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.latest_interest,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.last_call_at::text,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.latest_call_status,''),'"','""')||'",' ||
        '"'||replace(coalesce(s.next_appointment_at::text,''),'"','""')||'",' ||
        coalesce(s.sale_count,0)::text||',' ||
        coalesce(s.revenue_lifetime,0)::text||',' ||
        coalesce(s.overdue_followup_count,0)::text,
        chr(10) order by s.contact_key
      ),'')
    into v_csv
    from public.aos_cia_audience_source_v1 s
    where v_all or s.contact_key=any(v_keys);

    return jsonb_build_object(
      'ok',true,
      'row_count',v_count,
      'filename',coalesce(nullif(v_payload->>'filename',''),'audiencia')||'-'||to_char(statement_timestamp(),'YYYYMMDD-HH24MI')||'.csv',
      'csv',v_csv,
      'observed_at',statement_timestamp()
    );
  end if;

  if v_action='ACTIVITY_SUMMARY' then
    select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc),'[]'::jsonb)
    into v_activity
    from (
      select
        x.id as activation_id,
        a.nombre as audience_name,
        s.estado as activation_state,
        x.created_at,
        p.id as plan_id,
        p.state as plan_state,
        p.strategy,
        p.source_limit,
        count(ass.id)::integer as assignment_count,
        count(ass.id) filter(where ass.state='IN_PROGRESS')::integer as in_progress,
        count(ass.id) filter(where ass.state='COMPLETED')::integer as completed,
        count(ass.id) filter(where ass.state='RELEASED')::integer as released,
        count(ass.id) filter(where ass.state='EXPIRED')::integer as expired
      from public.aos_audiencia_activaciones x
      join public.aos_audiencias a on a.id=x.audiencia_id
      left join public.aos_audiencia_activacion_estado s on s.activacion_id=x.id
      left join public.aos_cia_assignment_plans p on p.activation_id=x.id
      left join public.aos_cia_assignments ass on ass.plan_id=p.id
      group by x.id,a.nombre,s.estado,x.created_at,p.id,p.state,p.strategy,p.source_limit
      order by x.created_at desc
      limit 50
    ) q;

    return jsonb_build_object('ok',true,'items',v_activity,'observed_at',statement_timestamp());
  end if;

  return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
exception when others then
  return jsonb_build_object('ok',false,'error','CONTROL_CENTER_V3_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_control_center_app_v3(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v3(text,text,jsonb) to anon,authenticated;

comment on function public.aos_cia_control_center_app_v3(text,text,jsonb)
is 'CIA Workspace V3 gateway. Catalog metadata/count cache/export/activity are additive; existing audience/canary actions delegate to V2.';

create or replace function public.aos_cia_catalog_assignment_stale_guard_v1()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_name text;
  v_saved_filter jsonb;
  v_preset_filter jsonb;
  v_preset_key text;
begin
  if not coalesce(new.metadata,'{}'::jsonb) @> jsonb_build_object('pack','B','canary',1) then
    return new;
  end if;

  select a.nombre,v.filter_dsl
    into v_name,v_saved_filter
  from public.aos_audiencia_activaciones x
  join public.aos_audiencias a on a.id=x.audiencia_id
  join public.aos_audiencia_versiones v on v.id=x.audiencia_version_id
  where x.id=new.activation_id;

  select p.preset_key,p.dsl
    into v_preset_key,v_preset_filter
  from public.aos_audience_presets p
  where p.active=true and p.name=v_name
  order by p.registry_version desc,p.updated_at desc
  limit 1;

  if v_preset_key is not null and v_saved_filter is distinct from v_preset_filter then
    raise exception 'CATALOG_AUDIENCE_STALE: %',v_preset_key using errcode='P0001';
  end if;

  return new;
end
$function$;

revoke all on function public.aos_cia_catalog_assignment_stale_guard_v1() from public,anon,authenticated;

drop trigger if exists trg_aos_cia_catalog_assignment_stale_guard_v1 on public.aos_cia_assignment_plans;
create trigger trg_aos_cia_catalog_assignment_stale_guard_v1
before insert on public.aos_cia_assignment_plans
for each row execute function public.aos_cia_catalog_assignment_stale_guard_v1();

select pg_notify('pgrst','reload schema');

commit;
