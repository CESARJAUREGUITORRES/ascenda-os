-- CIA Audience Catalog V2
-- Adds curated live audience presets and governed catalog/export actions.
-- Existing Audience/Activation/Assignment truth remains authoritative.

begin;

with seed(preset_key,name,description,category,dsl) as (
  values
    ('ALL_LEADS','Todos los leads','Contactos que existen como lead','LEAD','{"version":1,"root":{"op":"AND","rules":[{"field":"contact.exists_as_lead","operator":"is_true"}]}}'::jsonb),
    ('LEAD_SERVICE_INTEREST','Interés actual en servicios','Leads cuyo último interés es un servicio','LEAD','{"version":1,"root":{"op":"AND","rules":[{"field":"lead.latest_interest_type","operator":"eq","value":"SERVICIO"}]}}'::jsonb),
    ('LEAD_PRODUCT_INTEREST','Interés actual en productos','Leads cuyo último interés es un producto','LEAD','{"version":1,"root":{"op":"AND","rules":[{"field":"lead.latest_interest_type","operator":"eq","value":"PRODUCTO"}]}}'::jsonb),

    ('NEVER_CALLED_CONTACTS','Nunca llamados','Contactos sin ninguna llamada registrada','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.never_called","operator":"is_true"}]}}'::jsonb),
    ('CALLED_NO_EFFECTIVE_CONTACT','Llamados sin contacto efectivo','Tienen llamadas, pero ninguna conversación efectiva','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.total","operator":"gt","value":0},{"field":"calls.effective_contact_count","operator":"eq","value":0}]}}'::jsonb),
    ('EFFECTIVE_CONTACTS','Con contacto efectivo','Contactos con al menos una comunicación efectiva','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.effective_contact_count","operator":"gt","value":0}]}}'::jsonb),
    ('CALLED_TODAY','Llamados hoy','Contactos que ya recibieron una llamada hoy','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.called_today","operator":"is_true"}]}}'::jsonb),
    ('CALL_STALE_7D','Sin llamada en más de 7 días','Contactos cuya última llamada fue hace más de 7 días','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.days_since_last","operator":"gt","value":7}]}}'::jsonb),
    ('CALL_STALE_30D','Sin llamada en más de 30 días','Contactos cuya última llamada fue hace más de 30 días','CALL','{"version":1,"root":{"op":"AND","rules":[{"field":"calls.days_since_last","operator":"gt","value":30}]}}'::jsonb),

    ('NEVER_APPOINTED','Nunca tuvieron cita','Contactos sin historial de citas','APPOINTMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.never_had","operator":"is_true"}]}}'::jsonb),
    ('HAS_FUTURE_APPOINTMENT','Con cita futura','Contactos que ya tienen una próxima cita','APPOINTMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.has_future","operator":"is_true"}]}}'::jsonb),
    ('EVER_NO_SHOW','Con historial de no-show','Contactos que alguna vez faltaron a una cita','APPOINTMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.ever_no_show","operator":"is_true"}]}}'::jsonb),
    ('ATTENDED_APPOINTMENT','Con asistencia registrada','Contactos que asistieron al menos a una cita','APPOINTMENT','{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.attended_count","operator":"gt","value":0}]}}'::jsonb),

    ('NEVER_BOUGHT','Nunca compraron','Contactos sin compra registrada','SALE','{"version":1,"root":{"op":"AND","rules":[{"field":"sales.never_bought","operator":"is_true"}]}}'::jsonb),
    ('RECENT_BUYERS_30D','Compraron en los últimos 30 días','Clientes con una compra reciente','SALE','{"version":1,"root":{"op":"AND","rules":[{"field":"sales.days_since_last","operator":"lte","value":30}]}}'::jsonb),
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
    ('AGE_65_PLUS','Edad 65+','Contactos de 65 años a más','DEMOGRAPHIC','{"version":1,"root":{"op":"AND","rules":[{"field":"crm.age_band","operator":"eq","value":"65_PLUS"}]}}'::jsonb)
)
insert into public.aos_audience_presets(preset_key,name,description,category,dsl,registry_version,active)
select s.preset_key,s.name,s.description,s.category,s.dsl,1,true
from seed s
where not exists (
  select 1 from public.aos_audience_presets p where p.preset_key=s.preset_key
);

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
begin
  if v_action not in ('CATALOG_META','PREVIEW_ALL','EXPORT_CSV') then
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
      'preset_key',p.preset_key,'name',p.name,'description',p.description,
      'category',p.category,'dsl',p.dsl,'registry_version',p.registry_version
    ) order by p.category,p.name),'[]'::jsonb)
    into v_presets
    from public.aos_audience_presets p
    where p.active=true;

    select coalesce(jsonb_agg(jsonb_build_object(
      'field_key',r.field_key,'label',r.label,'category',r.category,
      'data_type',r.data_type,'allowed_operators',r.allowed_operators,
      'enum_values',r.enum_values,'description',r.description
    ) order by r.category,r.label),'[]'::jsonb)
    into v_filters
    from public.aos_audience_filter_registry r
    where r.active=true and r.ui_visible=true;

    select coalesce(jsonb_agg(jsonb_build_object('category',x.category,'field_count',x.field_count) order by x.category),'[]'::jsonb)
    into v_categories
    from (
      select r.category,count(*)::integer field_count
      from public.aos_audience_filter_registry r
      where r.active=true and r.ui_visible=true
      group by r.category
    ) x;

    return jsonb_build_object(
      'ok',true,
      'total_contacts',(select count(*)::integer from public.aos_cia_contact_identity_v1),
      'preset_count',jsonb_array_length(v_presets),
      'presets',v_presets,
      'filters',v_filters,
      'categories',v_categories,
      'freshness',jsonb_build_object(
        'segments',(select max(cache_refreshed_at) from public.aos_cia_segment_runtime_cache_v2),
        'email',(select max(cache_refreshed_at) from public.aos_cia_email_runtime_cache_v2)
      ),
      'observed_at',statement_timestamp()
    );
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
      'count',(select count(*)::integer from public.aos_cia_contact_identity_v1),
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
      v_count := (select count(*)::integer from public.aos_cia_contact_identity_v1);
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

  return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
exception when others then
  return jsonb_build_object('ok',false,'error','CONTROL_CENTER_V3_ERROR','code',sqlstate);
end
$function$;

revoke all on function public.aos_cia_control_center_app_v3(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v3(text,text,jsonb) to anon,authenticated;

comment on function public.aos_cia_control_center_app_v3(text,text,jsonb)
is 'CIA Audience Catalog V2 gateway. Delegates all existing behavior to V2; adds catalog metadata, full-base preview and explicit governed CSV export.';

select pg_notify('pgrst','reload schema');

commit;
