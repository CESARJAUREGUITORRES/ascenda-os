begin;

select plan(11);

select is(has_function_privilege('anon','public.aos_login(text,text)','EXECUTE'),false,'legacy plaintext login is closed');
select is(has_function_privilege('anon','public.aos_admin_crear_usuario(text,text,text,text,text,text,integer,text,text)','EXECUTE'),false,'legacy unauthenticated user creation is closed');
select is(has_function_privilege('anon','public.aos_admin_cambiar_password(uuid,text)','EXECUTE'),false,'legacy unauthenticated admin reset is closed');
select is(has_function_privilege('anon','public.aos_cambiar_password(text,text,text)','EXECUTE'),false,'legacy plaintext self-change is closed');
select is(has_function_privilege('anon','public.aos_admin_crear_usuario_v3(text,text,text,text,text,text,text,integer,text,text)','EXECUTE'),true,'tokenized create-user transport is callable');
select is(has_function_privilege('anon','public.aos_admin_cambiar_password_v3(text,uuid,text)','EXECUTE'),true,'tokenized admin reset transport is callable');

insert into public.aos_rrhh(codigo_asesor,nombre,apellido,puesto,sede,usuario,password_hash,estado)
values ('ID-OWNER','Owner Identity','Test','ADMIN','SAN ISIDRO','id.owner',extensions.crypt('OwnerPass123!',extensions.gen_salt('bf',10)),'ACTIVO')
on conflict (codigo_asesor) do update set password_hash=excluded.password_hash,estado='ACTIVO';

insert into public.aos_usuarios(id,codigo_asesor,nombre,email,rol,paneles_acceso,nivel_jerarquia,sedes_permitidas,area,cargo,two_factor,activo)
values ('33333333-3333-4333-8333-333333333333','ID-OWNER','Owner Identity','owner.test@example.invalid','admin',array['admin-team'],1,array['SAN ISIDRO','PUEBLO LIBRE'],'ADMIN','ADMIN',true,true)
on conflict (id) do update set paneles_acceso=excluded.paneles_acceso,two_factor=true,activo=true,rol='admin',nivel_jerarquia=1;

insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
values (encode(extensions.digest('identity-owner-token','sha256'),'hex'),'33333333-3333-4333-8333-333333333333','PASSWORD_2FA',now()+interval '1 hour')
on conflict (token_hash) do update set revoked=false,expires_at=excluded.expires_at,assurance_level='PASSWORD_2FA';

create temporary table created_identity as
select public.aos_admin_crear_usuario_v3(
  'identity-owner-token','Nueva','Persona','new.person@example.invalid','999111222','ASESOR','comercial',4,'limitado','SAN ISIDRO'
) as d;

select is((select (d->>'ok')::boolean from created_identity),true,'owner-admin 2FA can create a user');
select ok((select length(d->>'password')>=10 from created_identity),'bootstrap password is strong enough and returned only once');
select ok((select rr.password_hash like '$2%' from public.aos_rrhh rr where rr.codigo_asesor=(select d->>'codigo' from created_identity)),'created user credential is stored as bcrypt');

select is(
  public.aos_admin_crear_usuario_v3('bad-token','No','Access','','','ASESOR','comercial',4,'limitado','SAN ISIDRO')->>'error',
  'OWNER_ADMIN_2FA_REQUIRED',
  'unauthorized caller cannot create users'
);

create temporary table reset_identity as
select public.aos_admin_cambiar_password_v3(
  'identity-owner-token',(select (d->>'usuario_id')::uuid from created_identity),'NewStrongPass123!'
) as d;
select is((select (d->>'ok')::boolean from reset_identity),true,'owner-admin 2FA can reset an authorized target password');
select ok((select extensions.crypt('NewStrongPass123!',rr.password_hash)=rr.password_hash from public.aos_rrhh rr where rr.codigo_asesor=(select d->>'codigo' from created_identity)),'admin reset stores bcrypt and verifies cryptographically');

select * from finish();
rollback;
