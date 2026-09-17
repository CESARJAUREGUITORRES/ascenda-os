begin;

create table if not exists public.aos_cia_queue_config_audit_v1 (
  id uuid primary key default gen_random_uuid(),
  asesor text not null,
  actor_user_id uuid not null references public.aos_usuarios(id),
  actor_name text not null,
  old_config jsonb not null,
  new_config jsonb not null,
  changed_at timestamptz not null default now()
);

alter table public.aos_cia_queue_config_audit_v1 enable row level security;
revoke all on table public.aos_cia_queue_config_audit_v1 from public, anon, authenticated;
create index if not exists aos_cia_queue_config_audit_v1_asesor_changed_idx
  on public.aos_cia_queue_config_audit_v1 (asesor, changed_at desc);

create or replace function public.aos_cia_queue_config_list_admin_v1(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_auth jsonb;
  v_user_id uuid;
  v_role text;
  v_panels text[];
  v_assurance text;
begin
  v_auth := public.aos_cia_verify_app_session_v1(p_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_user_id := (v_auth->>'user_id')::uuid;
  v_role := upper(coalesce(v_auth->>'rol',''));
  v_assurance := upper(coalesce(v_auth->>'assurance_level',''));
  select coalesce(u.paneles_acceso,'{}'::text[]) into v_panels from public.aos_usuarios u where u.id=v_user_id and u.activo=true;
  if v_role <> 'ADMIN' or v_assurance <> 'PASSWORD_2FA' or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;
  return jsonb_build_object(
    'ok',true,
    'rows',coalesce((select jsonb_agg(jsonb_build_object(
      'asesor',c.asesor,'tipo_cola',coalesce(c.tipo_cola,'global'),'filtro_valor',coalesce(c.filtro_valor,''),
      'configurado_por',coalesce(c.configurado_por,''),'updated_at',c.updated_at
    ) order by c.asesor) from public.aos_cola_config c),'[]'::jsonb),
    'authority','CIA_QUEUE_GATEWAY_V1'
  );
end
$function$;

create or replace function public.aos_cia_queue_config_set_admin_v1(
  p_token text,
  p_asesor text,
  p_tipo_cola text,
  p_filtro_valor text default ''
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_auth jsonb;
  v_user_id uuid;
  v_name text;
  v_role text;
  v_assurance text;
  v_panels text[];
  v_asesor text := upper(btrim(coalesce(p_asesor,'')));
  v_tipo text := lower(btrim(coalesce(p_tipo_cola,'global')));
  v_filtro text := upper(btrim(coalesce(p_filtro_valor,'')));
  v_old public.aos_cola_config%rowtype;
  v_new public.aos_cola_config%rowtype;
begin
  v_auth := public.aos_cia_verify_app_session_v1(p_token);
  if not coalesce((v_auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  v_user_id := (v_auth->>'user_id')::uuid;
  v_name := coalesce(v_auth->>'nombre','ADMIN');
  v_role := upper(coalesce(v_auth->>'rol',''));
  v_assurance := upper(coalesce(v_auth->>'assurance_level',''));
  select coalesce(u.paneles_acceso,'{}'::text[]) into v_panels from public.aos_usuarios u where u.id=v_user_id and u.activo=true;
  if v_role <> 'ADMIN' or v_assurance <> 'PASSWORD_2FA' or not (v_panels @> array['admin-calls']::text[]) then
    return jsonb_build_object('ok',false,'error','FORBIDDEN_ADMIN_CALLS_2FA_REQUIRED');
  end if;
  if v_asesor='' or char_length(v_asesor)>80 then return jsonb_build_object('ok',false,'error','INVALID_ADVISOR'); end if;
  if v_tipo not in ('global','campana','pacientes_activos','no_asistio','tipificacion','provincia') then
    return jsonb_build_object('ok',false,'error','INVALID_QUEUE_TYPE');
  end if;
  if char_length(v_filtro)>160 then return jsonb_build_object('ok',false,'error','FILTER_TOO_LONG'); end if;
  if v_tipo in ('campana','tipificacion') and v_filtro='' then return jsonb_build_object('ok',false,'error','FILTER_REQUIRED'); end if;
  if v_tipo not in ('campana','tipificacion') then v_filtro := ''; end if;

  select * into v_old from public.aos_cola_config c where upper(c.asesor)=v_asesor for update;
  if not found then return jsonb_build_object('ok',false,'error','QUEUE_ADVISOR_NOT_FOUND'); end if;

  update public.aos_cola_config c
     set tipo_cola=v_tipo,
         filtro_valor=v_filtro,
         configurado_por=v_name,
         updated_at=clock_timestamp()
   where upper(c.asesor)=v_asesor
   returning * into v_new;

  insert into public.aos_cia_queue_config_audit_v1(asesor,actor_user_id,actor_name,old_config,new_config)
  values(v_new.asesor,v_user_id,v_name,to_jsonb(v_old),to_jsonb(v_new));

  return jsonb_build_object('ok',true,'row',to_jsonb(v_new),'authority','CIA_QUEUE_GATEWAY_V1');
end
$function$;

revoke all on function public.aos_cia_queue_config_list_admin_v1(text) from public;
revoke all on function public.aos_cia_queue_config_set_admin_v1(text,text,text,text) from public;
grant execute on function public.aos_cia_queue_config_list_admin_v1(text) to anon, authenticated, service_role;
grant execute on function public.aos_cia_queue_config_set_admin_v1(text,text,text,text) to anon, authenticated, service_role;

commit;
