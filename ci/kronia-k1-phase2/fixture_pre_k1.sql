\set ON_ERROR_STOP on

-- Extend the existing Phase 2 synthetic fixture only. No production PII.
update public.aos_usuarios
set paneles_acceso=array['admin-sales-intelligence','admin-cartera','admin-caja','admin-team','admin-config']::text[],
    rol='admin',nivel_jerarquia=1,two_factor=true,activo=true
where codigo_asesor='CAROWNER';

insert into public.aos_rrhh(codigo_asesor,nombre,apellido,puesto,sede,usuario,password_hash,permisos,estado)
values('K1ADV','K1 ADVISOR','TEST','ASESOR','SAN ISIDRO','k1.advisor','advisor-pass-2026','{}','ACTIVO')
on conflict(codigo_asesor) do nothing;

insert into public.aos_usuarios(codigo_asesor,nombre,email,rol,paneles_acceso,nivel_jerarquia,sedes_permitidas,area,cargo,two_factor,activo)
values('K1ADV','K1 ADVISOR','advisor@example.invalid','asesor',array['ventas']::text[],4,array['SAN ISIDRO']::text[],'VENTAS','ASESOR',false,true)
on conflict(codigo_asesor) do nothing;

-- Known 2FA app token for owner-admin gateway tests. This is a synthetic CI token.
insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at,revoked)
select encode(extensions.digest('k1-owner-app-token-00000000000000000000000001','sha256'),'hex'),id,'PASSWORD_2FA',now()+interval '8 hours',false
from public.aos_usuarios where codigo_asesor='CAROWNER';

-- Advisor token for negative/positive non-admin control-plane tests.
insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at,revoked)
select encode(extensions.digest('k1-advisor-app-token-000000000000000000000001','sha256'),'hex'),id,'PASSWORD',now()+interval '8 hours',false
from public.aos_usuarios where codigo_asesor='K1ADV';
