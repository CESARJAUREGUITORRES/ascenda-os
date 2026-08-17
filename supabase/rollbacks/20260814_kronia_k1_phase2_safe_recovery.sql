-- ASCENDA OS — K1 / Phase 2 security-preserving emergency recovery.
--
-- This is intentionally NOT a vulnerability-restoring rollback. If the K1
-- runtime must be reverted to the previous Phase 2 artifact, core Auth V3 and
-- business modules remain available, while KronIA/Team/Config may operate in a
-- degraded mode until K1 is redeployed. Plaintext credentials and browser-trust
-- boundaries are never restored.

begin;

-- Canonical Auth V3 stays operational; credential store remains private.
alter table public.aos_auth_credentials enable row level security;
revoke all on table public.aos_auth_credentials from public,anon,authenticated;
grant all on table public.aos_auth_credentials to service_role;
update public.aos_rrhh set password_hash=null where password_hash is not null;

-- Session/challenge proof stores remain private.
revoke all on table public.aos_app_sessions_v3 from public,anon,authenticated;
revoke all on table public.aos_login_challenges_v3 from public,anon,authenticated;
revoke all on table public.aos_auth_codes from public,anon,authenticated;
grant all on table public.aos_app_sessions_v3 to service_role;
grant all on table public.aos_login_challenges_v3 to service_role;
grant all on table public.aos_auth_codes to service_role;

-- Identity and configuration cannot become browser-writable during recovery.
revoke insert,update,delete on table public.aos_usuarios from anon,authenticated;
revoke insert,update,delete on table public.aos_rrhh from anon,authenticated;
revoke insert,update,delete on table public.aos_configuracion from anon,authenticated;

-- Integration secret material remains server-only.
alter table public.aos_integration_secrets_v1 enable row level security;
alter table public.aos_integration_secrets_v1 force row level security;
revoke all on table public.aos_integration_secrets_v1 from public,anon,authenticated;
grant select,insert,update on table public.aos_integration_secrets_v1 to service_role;
update public.aos_integraciones set api_key='',api_secret='' where coalesce(api_key,'')<>'' or coalesce(api_secret,'')<>'';
revoke all on table public.aos_integraciones from anon,authenticated;
grant select(id,tipo,nombre,cuenta,estado,principal,categoria,icono,descripcion,uso_para,orden,url_docs,url_signup,multi_cuenta,logo_url,created_at,updated_at)
  on public.aos_integraciones to anon,authenticated;
grant all on table public.aos_integraciones to service_role;

-- Authoritative logs remain server-owned.
revoke all on table public.aos_kronia_tokens from anon,authenticated;
revoke all on table public.aos_kronia_acciones from anon,authenticated;
revoke all on table public.aos_kronia_conversaciones from anon,authenticated;
revoke all on table public.aos_agente_logs from anon,authenticated;
revoke all on table public.aos_agente_acciones from anon,authenticated;
revoke all on table public.aos_log_auditoria from anon,authenticated;
revoke all on table public.aos_security_log from anon,authenticated;

-- Never restore raw browser-callable business/KronIA authority.
do $acl$
declare r regprocedure;
begin
  foreach r in array array[
    'public.aos_editar_venta(bigint,jsonb,text,text,text)'::regprocedure,
    'public.aos_kronia_agregar_nota_paciente(text,text,text)'::regprocedure,
    'public.aos_kronia_buscar_cita(text,text,text)'::regprocedure,
    'public.aos_kronia_buscar_paciente(text)'::regprocedure,
    'public.aos_kronia_buscar_venta(text,text,text)'::regprocedure,
    'public.aos_kronia_editar_cita(bigint,jsonb,text,text)'::regprocedure,
    'public.aos_kronia_editar_paciente(text,jsonb,text)'::regprocedure,
    'public.aos_kronia_explorar(text,text,jsonb)'::regprocedure,
    'public.aos_kronia_marcar_estado_cita(bigint,text,text,text)'::regprocedure,
    'public.aos_kronia_reprogramar_seguimiento(text,text,text,text,text)'::regprocedure
  ] loop execute format('revoke all on function %s from public,anon,authenticated',r); end loop;
end
$acl$;

-- Historical password-only/admin functions stay retired.
revoke execute on function public.aos_login(text,text) from public,anon,authenticated;
revoke execute on function public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text) from public,anon,authenticated;
revoke execute on function public.aos_admin_cambiar_password(uuid,text) from public,anon,authenticated;
revoke execute on function public.aos_admin_cambiar_password(text,text,text,text) from public,anon,authenticated;
revoke execute on function public.aos_cambiar_password(text,text,text) from public,anon,authenticated;


-- Sensitive identity reads remain least-privilege during recovery.
revoke all on table public.aos_usuarios from anon,authenticated;
grant select(id,codigo_asesor,nombre,apellidos,rol,cargo,area,sede,activo,cuenta_activada,two_factor,paneles_acceso,avatar_url,nivel_jerarquia,acceso_geo,sedes_permitidas,cmp,servicios)
  on public.aos_usuarios to anon,authenticated;
revoke all on table public.aos_rrhh from anon,authenticated;
grant select(codigo_asesor,nombre,apellido,puesto,sede,estado) on public.aos_rrhh to anon,authenticated;
revoke all on table public.aos_team_full from public,anon,authenticated;
grant select on table public.aos_team_full to service_role;

commit;
