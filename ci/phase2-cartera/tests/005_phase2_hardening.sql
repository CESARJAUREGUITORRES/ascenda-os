begin;

select plan(33);

select has_table('public','aos_login_challenges_v3','2FA challenge table exists');
select has_table('public','aos_app_sessions_v3','opaque app session table exists');
select is((select relrowsecurity from pg_class where oid='public.aos_login_challenges_v3'::regclass),true,'2FA challenge table has RLS');
select is(has_table_privilege('anon','public.aos_login_challenges_v3','SELECT'),false,'anon cannot read OTP challenge hashes');
select is(has_table_privilege('anon','public.aos_app_sessions_v3','SELECT'),false,'anon cannot read app sessions');
select is(has_function_privilege('anon','public.aos_login_v3(text,text)','EXECUTE'),true,'v3 login is browser callable');
select is(has_function_privilege('anon','public.aos_verificar_2fa_v3(uuid,text)','EXECUTE'),true,'v3 verifier is browser callable');
select is(has_function_privilege('anon','public.aos_login_v2(text,text)','EXECUTE'),false,'legacy login cannot be called by anon');
select is(has_function_privilege('anon','public.aos_verificar_2fa(text,text)','EXECUTE'),false,'legacy verifier cannot be called by anon');
select is(has_function_privilege('anon','public.aos_sales_intelligence_claim_session(text,text,text,text)','EXECUTE'),false,'weak SI claim path is closed');
select is(has_function_privilege('anon','public.aos_cia_claim_admin_session_v1(text,text)','EXECUTE'),false,'legacy admin-session claim is closed');

insert into public.aos_rrhh(codigo_asesor,nombre,apellido,puesto,sede,usuario,password_hash,estado)
values
 ('HARD-ADMIN','Admin Fase2','Test','ADMIN','SAN ISIDRO','hard.admin','Secret123!','ACTIVO'),
 ('HARD-ADV','Asesor Fase2','Test','ASESOR','SAN ISIDRO','hard.adv','Advisor123!','ACTIVO')
on conflict (codigo_asesor) do update set password_hash=excluded.password_hash,estado='ACTIVO';

insert into public.aos_usuarios(id,codigo_asesor,nombre,email,rol,paneles_acceso,nivel_jerarquia,sedes_permitidas,area,cargo,two_factor,activo)
values
 ('11111111-1111-4111-8111-111111111111','HARD-ADMIN','Admin Fase2','admin.test@example.invalid','admin',array['admin-caja','admin-config','admin-agenda','admin-sales-intelligence','admin-cartera'],1,array['SAN ISIDRO','PUEBLO LIBRE'],'ADMIN','ADMIN',true,true),
 ('22222222-2222-4222-8222-222222222222','HARD-ADV','Asesor Fase2','advisor.test@example.invalid','asesor',array['advisor-attendance'],4,array['SAN ISIDRO'],'COMERCIAL','ASESOR',false,true)
on conflict (id) do update set paneles_acceso=excluded.paneles_acceso,two_factor=excluded.two_factor,activo=true;

create temporary table hard_admin_login as
select public.aos_login_v3('hard.admin','Secret123!') as d;

select is((select (d->>'ok')::boolean from hard_admin_login),true,'2FA v3 login accepts valid legacy credential');
select is((select (d->>'require_2fa')::boolean from hard_admin_login),true,'admin is challenged with independent 2FA');
select is((select d ? 'code' from hard_admin_login),false,'OTP plaintext is never returned');
select is((select d ? 'email_real' from hard_admin_login),false,'real recipient email is never returned');
select ok((select password_hash like '$2%' from public.aos_rrhh where codigo_asesor='HARD-ADMIN'),'successful v3 login upgrades legacy password to bcrypt');

update public.aos_login_challenges_v3 c
set code_hash=encode(extensions.digest(c.id::text||':123456','sha256'),'hex')
where c.id=(select (d->>'challenge_id')::uuid from hard_admin_login);

create temporary table hard_admin_verify as
select public.aos_verificar_2fa_v3((select (d->>'challenge_id')::uuid from hard_admin_login),'123456') as d;
select is((select (d->>'ok')::boolean from hard_admin_verify),true,'correct one-time code verifies');
select ok((select length(d->>'app_token')>=32 from hard_admin_verify),'verification returns an opaque app token');
select is(public.aos_app_actor_v3((select d->>'app_token' from hard_admin_verify),'admin-caja',true),'11111111-1111-4111-8111-111111111111'::uuid,'2FA admin token satisfies strict Caja panel');
select is((select count(*) from public.aos_cia_admin_sessions s where s.user_id='11111111-1111-4111-8111-111111111111' and s.revoked=false),1::bigint,'same strong proof backs existing finance/SI gateway token');
select is((public.aos_verificar_2fa_v3((select (d->>'challenge_id')::uuid from hard_admin_login),'123456')->>'ok')::boolean,false,'OTP challenge cannot be replayed');

create temporary table hard_adv_login as
select public.aos_login_v3('hard.adv','Advisor123!') as d;
select is((select (d->>'require_2fa')::boolean from hard_adv_login),false,'non-2FA operational user receives password assurance only');
select is(public.aos_app_actor_v3((select d->>'app_token' from hard_adv_login),'admin-caja',true),null::uuid,'password-only token cannot enter financial boundary');

select is(has_table_privilege('anon','public.aos_ventas','INSERT'),false,'anon direct sales INSERT is closed');
select is(has_table_privilege('anon','public.aos_catalogo_servicios','UPDATE'),false,'anon direct catalog UPDATE is closed');
select is(has_table_privilege('anon','public.aos_planes_trabajo','DELETE'),false,'anon direct plan DELETE is closed');
select is(has_function_privilege('anon','public.aos_caja_abrir(text,text,numeric,numeric,numeric,date)','EXECUTE'),false,'legacy Caja open is denied');
select is(has_function_privilege('anon','public.aos_caja_abrir_v2(text,text,numeric,numeric,numeric,date)','EXECUTE'),true,'tokenized Caja open transport remains callable');

select is((public.aos_secure_write_v2(
  (select d->>'app_token' from hard_admin_verify),'aos_catalogo_categorias','INSERT','{}'::jsonb,
  '{"nombre":"TEST HARD","tipo":"SERVICIO","rol_profesional":"AMBOS","estado":"ACTIVO"}'::jsonb
)->>'ok')::boolean,true,'authorized admin writes catalog through gateway');
select is(public.aos_secure_write_v2(
  (select d->>'app_token' from hard_adv_login),'aos_catalogo_categorias','INSERT','{}'::jsonb,
  '{"nombre":"NO","tipo":"SERVICIO","estado":"ACTIVO"}'::jsonb
)->>'error','CATALOG_ADMIN_REQUIRED','advisor cannot write admin catalog');
select is((public.aos_secure_write_v2(
  (select d->>'app_token' from hard_adv_login),'aos_planes_trabajo','INSERT','{}'::jsonb,
  '{"id":"plan-hard-1","numero_limpio":"999000000","fecha":"2026-08-14","estado":"ACTIVO","nombre":"Plan test"}'::jsonb
)->>'ok')::boolean,true,'attendance-authorized user writes plan through gateway');
select is(public.aos_secure_write_v2(
  (select d->>'app_token' from hard_admin_verify),'aos_ventas','DELETE','{"id":"1"}'::jsonb,'{}'::jsonb
)->>'error','TABLE_NOT_ALLOWED','generic gateway cannot mutate sales');

select is(public.aos_caja_abrir_v2(
  (select d->>'app_token' from hard_admin_verify),'SAN ISIDRO',100,0,3.70,'2026-08-14'
)->>'actor','Admin Fase2','Caja v2 derives actor identity from token, not browser input');

select * from finish();
rollback;
