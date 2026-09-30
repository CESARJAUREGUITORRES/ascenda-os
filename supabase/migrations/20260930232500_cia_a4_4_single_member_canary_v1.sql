begin;

-- CIA A4.4 · single-member human canary.
-- The controlled one-contact test must not materialize the full selected audience.
-- Catalog-equivalent audiences select one currently assignable member and freeze only
-- that member into the canary snapshot. Bulk distribution remains disabled.

create or replace function public.aos_cia_canary_activation_create_one_admin_v1(
  p_token text,
  p_audience_id uuid,
  p_version integer,
  p_contact_key text,
  p_name text default 'Prueba segura Call Center'
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_auth jsonb;
  v_uid uuid;
  v_audience record;
  v_version_row record;
  v_contact text:=btrim(coalesce(p_contact_key,''));
  v_snapshot_id uuid;
  v_activation_id uuid;
  v_now timestamptz:=statement_timestamp();
  v_filter_hash text;
  v_membership_hash text;
  v_identity_conflict boolean:=false;
begin
  v_auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_uid:=(v_auth->>'user_id')::uuid;

  if v_contact !~ '^[0-9]{9}$' then
    return jsonb_build_object('ok',false,'error','INVALID_CANARY_CONTACT');
  end if;

  select a.id,a.estado,a.current_version
    into v_audience
  from public.aos_audiencias a
  where a.id=p_audience_id;

  if v_audience.id is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_NOT_FOUND');
  end if;
  if v_audience.estado<>'ACTIVE' then
    return jsonb_build_object('ok',false,'error','AUDIENCE_ARCHIVED');
  end if;

  select v.id,v.version,v.filter_dsl
    into v_version_row
  from public.aos_audiencia_versiones v
  where v.audiencia_id=p_audience_id
    and v.version=coalesce(p_version,v_audience.current_version);

  if v_version_row.id is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_VERSION_NOT_FOUND');
  end if;

  v_filter_hash:=encode(extensions.digest(v_version_row.filter_dsl::text,'sha256'),'hex');
  v_membership_hash:=encode(extensions.digest(v_contact,'sha256'),'hex');

  select coalesce(c.identity_conflict,false)
    into v_identity_conflict
  from public.aos_cia_contact_runtime_cache_v1 c
  where c.contact_key=v_contact;

  insert into public.aos_audiencia_snapshots(
    audiencia_id,audiencia_version_id,estado,member_count,membership_hash,
    filter_hash,resolved_at,sealed_at,created_by_user_id
  )
  values(
    p_audience_id,v_version_row.id,'READY',1,v_membership_hash,
    v_filter_hash,v_now,clock_timestamp(),v_uid
  )
  returning id into v_snapshot_id;

  insert into public.aos_audiencia_snapshot_miembros(
    snapshot_id,contact_key,identity_status,identity_conflict,resolved_at
  )
  values(
    v_snapshot_id,v_contact,null,coalesce(v_identity_conflict,false),v_now
  );

  insert into public.aos_audiencia_activaciones(
    audiencia_id,audiencia_version_id
  )
  values(p_audience_id,v_version_row.id)
  returning id into v_activation_id;

  insert into public.aos_audiencia_activacion_config(
    activacion_id,snapshot_id,nombre,purpose,channel,mode,
    baseline_count,baseline_resolved_at,metadata,created_by_user_id
  )
  values(
    v_activation_id,v_snapshot_id,left(coalesce(nullif(btrim(p_name),''),'Prueba segura Call Center'),120),
    'HUMAN_CANARY_PACK_B','CALL','BATCH',
    1,v_now,
    jsonb_build_object(
      'context_only',true,
      'phase',9,
      'pack','B',
      'canary',1,
      'single_member_snapshot',true,
      'source_contact_key',v_contact
    ),
    v_uid
  );

  insert into public.aos_audiencia_activacion_estado(
    activacion_id,estado,updated_by_user_id,started_at
  )
  values(v_activation_id,'ACTIVE',v_uid,clock_timestamp());

  return jsonb_build_object(
    'ok',true,
    'activation_id',v_activation_id,
    'snapshot_id',v_snapshot_id,
    'mode','BATCH',
    'state','ACTIVE',
    'baseline_count',1,
    'baseline_resolved_at',v_now,
    'contact_key',v_contact,
    'single_member_snapshot',true
  );
end
$function$;

revoke all on function public.aos_cia_canary_activation_create_one_admin_v1(text,uuid,integer,text,text) from public;

create or replace function public.aos_cia_control_center_app_v9(
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
  v_audience_id uuid;
  v_version integer;
  v_advisor_id uuid;
  v_requested_limit integer;
  v_filter jsonb;
  v_preset_key text;
  v_contact_key text;
  v_session jsonb;
  v_cia_token text;
  v_activation jsonb;
  v_activation_id uuid;
  v_context jsonb;
  v_plan_create jsonb;
  v_plan_id uuid;
  v_plan_transition jsonb;
  v_advisor_route jsonb;
  v_global_route jsonb;
  v_key text;
  v_out jsonb;
begin
  if v_action<>'START_CANARY_ASSIGNMENT' then
    return public.aos_cia_control_center_app_v8(p_app_token,p_action,v_payload);
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

  begin
    v_audience_id:=nullif(v_payload->>'audience_id','')::uuid;
    v_version:=nullif(v_payload->>'version','')::integer;
    v_advisor_id:=nullif(v_payload->>'advisor_user_id','')::uuid;
    v_requested_limit:=coalesce(nullif(v_payload->>'source_limit','')::integer,1);
  exception when others then
    return jsonb_build_object('ok',false,'error','INVALID_CANARY_PAYLOAD');
  end;

  if v_requested_limit<>1 then
    return jsonb_build_object('ok',false,'error','CANARY_SOURCE_LIMIT_MUST_BE_ONE');
  end if;

  if exists(
    select 1
    from public.aos_cia_assignment_plans p
    where p.state in ('DRAFT','ACTIVE','PAUSED')
      and p.metadata @> jsonb_build_object('pack','B','canary',1)
  ) then
    return jsonb_build_object('ok',false,'error','CANARY_ALREADY_ACTIVE');
  end if;

  if coalesce((select c.global_enabled from public.aos_cia_call_routing_control c where c.id=1),false)
     or exists(select 1 from public.aos_cia_call_routing_advisors r where r.mode<>'V2_ONLY') then
    return jsonb_build_object('ok',false,'error','ROUTING_NOT_BASELINE');
  end if;

  if not exists(
    select 1
    from public.aos_usuarios u
    where u.id=v_advisor_id
      and u.activo=true
      and lower(coalesce(u.rol,''))='asesor'
      and coalesce(u.paneles_acceso,'{}'::text[]) @> array['advisor-calls']::text[]
  ) then
    return jsonb_build_object('ok',false,'error','INVALID_CALL_ADVISOR');
  end if;

  select v.filter_dsl
    into v_filter
  from public.aos_audiencias a
  join public.aos_audiencia_versiones v
    on v.audiencia_id=a.id
   and v.version=coalesce(v_version,a.current_version)
  where a.id=v_audience_id
    and a.estado='ACTIVE';

  if v_filter is null then
    return jsonb_build_object('ok',false,'error','AUDIENCE_VERSION_NOT_FOUND');
  end if;

  select p.preset_key
    into v_preset_key
  from public.aos_audience_presets p
  where p.active=true
    and p.dsl=v_filter
  order by p.preset_key
  limit 1;

  -- Custom/non-catalog audiences keep the established governed path.
  if v_preset_key is null then
    return public.aos_cia_control_center_app_v8(p_app_token,p_action,v_payload);
  end if;

  select r.contact_key
    into v_contact_key
  from public.aos_cia_call_preview_rows_v1(v_preset_key,null) r
  where r.is_assignable
  order by r.contact_key
  limit 1;

  if v_contact_key is null then
    return jsonb_build_object(
      'ok',false,
      'error','CANARY_NO_ASSIGNABLE_CONTACTS',
      'preset_key',v_preset_key,
      'routing_unchanged',true
    );
  end if;

  v_session:=public.aos_cia_issue_admin_session_v1(v_name);
  if not coalesce((v_session->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','CIA_SESSION_EXCHANGE_FAILED');
  end if;
  v_cia_token:=v_session->>'token';

  v_activation:=public.aos_cia_canary_activation_create_one_admin_v1(
    v_cia_token,
    v_audience_id,
    v_version,
    v_contact_key,
    left(coalesce(nullif(v_payload->>'name',''),'Prueba segura Call Center'),120)
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
        jsonb_build_object(
          'pack','B',
          'canary',1,
          'owner_user_id',v_uid,
          'reversible',true,
          'single_member_snapshot',true,
          'preset_key',v_preset_key
        )
      );

      if not coalesce((v_plan_create->>'ok')::boolean,false) then
        perform public.aos_cia_activation_transition_admin_v1(v_cia_token,v_activation_id,'CANCEL');
        v_out:=v_plan_create;
      else
        v_plan_id:=(v_plan_create->>'plan_id')::uuid;
        v_plan_transition:=public.aos_cia_assignment_plan_transition_admin_v1(
          v_cia_token,v_plan_id,'ACTIVATE'
        );

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
              'metadata',jsonb_build_object(
                'pack','B','canary',1,'plan_id',v_plan_id,'single_member_snapshot',true
              )
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
                'metadata',jsonb_build_object(
                  'pack','B','canary',1,'plan_id',v_plan_id,'single_member_snapshot',true
                )
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
                'routing',jsonb_build_object(
                  'advisor',v_advisor_route,
                  'global',v_global_route
                ),
                'preset_key',v_preset_key,
                'contact_key',v_contact_key,
                'source_limit',1,
                'single_member_snapshot',true,
                'reversible',true,
                'instruction','OPEN_CALL_CENTER_AS_SELECTED_ADVISOR'
              );
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

  insert into public.aos_cia_gateway_audit(
    user_id,usuario,action,ok,duration_ms,meta
  )
  values(
    v_uid,v_name,v_action,coalesce((v_out->>'ok')::boolean,false),
    greatest(0,round(extract(epoch from(clock_timestamp()-v_started))*1000)::integer),
    jsonb_build_object(
      'gateway_version',9,
      'audience_id',coalesce(v_audience_id::text,''),
      'preset_key',coalesce(v_preset_key,''),
      'single_member_snapshot',true,
      'contact_key',coalesce(v_contact_key,'')
    )
  );

  return coalesce(v_out,jsonb_build_object('ok',false,'error','EMPTY_RESULT'));
exception
  when others then
    if v_cia_token is not null then
      update public.aos_cia_admin_sessions
      set revoked=true
      where token_hash=encode(extensions.digest(v_cia_token,'sha256'),'hex');
    end if;
    return jsonb_build_object(
      'ok',false,
      'error','CONTROL_CENTER_V9_ERROR',
      'code',sqlstate,
      'routing_unchanged',not coalesce((select global_enabled from public.aos_cia_call_routing_control where id=1),false)
    );
end
$function$;

revoke all on function public.aos_cia_control_center_app_v9(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v9(text,text,jsonb) to anon,authenticated,service_role;

comment on function public.aos_cia_control_center_app_v9(text,text,jsonb)
is 'CIA A4.4: one-contact human canary uses a single-member sealed snapshot for catalog audiences; all non-canary actions delegate to V8. Bulk distribution remains disabled.';

select pg_notify('pgrst','reload schema');

commit;
