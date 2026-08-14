BEGIN;

SELECT plan(15);

INSERT INTO public.aos_rrhh
  (codigo_asesor,nombre,apellido,puesto,sede,usuario,permisos,estado)
VALUES
  ('ZCS001','CANARY TEST','USER','ADMINISTRADOR','SAN ISIDRO','canary.test','{"ventas":true}'::jsonb,'ACTIVO');

INSERT INTO public.aos_usuarios
  (codigo_asesor,nombre,email,paneles_acceso,avatar_url,nivel_jerarquia,acceso_geo,sedes_permitidas,area,cargo,two_factor,activo)
VALUES
  ('ZCS001','CANARY TEST','canary@example.invalid',ARRAY['admin-home','admin-sales-intelligence'],'',1,'SIN_RESTRICCION',ARRAY['SAN ISIDRO'],'DIRECCION','DIRECTOR GENERAL',true,true);

INSERT INTO public.aos_auth_codes
  (usuario,email,codigo,usado,expira_at)
VALUES
  ('CANARY TEST','canary@example.invalid','654321',false,now()+interval '5 minutes');

CREATE TEMP TABLE _canary_2fa_result AS
SELECT public.aos_verificar_2fa('CANARY TEST','654321')::jsonb AS j;

SELECT is((SELECT (j->>'ok')::boolean FROM _canary_2fa_result), true, 'valid 2FA succeeds');
SELECT is((SELECT j->>'codigo_asesor' FROM _canary_2fa_result), 'ZCS001', 'advisor code is preserved');
SELECT is((SELECT (j->>'nivel')::integer FROM _canary_2fa_result), 1, 'level 1 is returned');
SELECT is((SELECT j->>'puesto' FROM _canary_2fa_result), 'DIRECTOR GENERAL', 'canonical role context is returned');
SELECT is((SELECT j->>'area' FROM _canary_2fa_result), 'DIRECCION', 'area context is returned');
SELECT is((SELECT j->'paneles_acceso' FROM _canary_2fa_result), '["admin-home", "admin-sales-intelligence"]'::jsonb, 'panel access is returned');
SELECT is((SELECT j->'sedes_permitidas' FROM _canary_2fa_result), '["SAN ISIDRO"]'::jsonb, 'allowed sites are returned');
SELECT is((SELECT usado FROM public.aos_auth_codes WHERE usuario='CANARY TEST' AND codigo='654321'), true, 'one-time code is consumed');
SELECT is((SELECT count(*) FROM public.aos_security_log WHERE usuario='CANARY TEST' AND accion='login'), 1::bigint, 'successful login is audited');
SELECT is((public.aos_verificar_2fa('CANARY TEST','654321')::jsonb->>'ok')::boolean, false, 'consumed code cannot be reused');
SELECT is((public.aos_verificar_2fa('CANARY TEST','000000')::jsonb->>'ok')::boolean, false, 'invalid code is rejected');
SELECT is((SELECT prosecdef FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='aos_verificar_2fa' LIMIT 1), true, '2FA verifier remains SECURITY DEFINER');
SELECT ok((SELECT coalesce(array_to_string(proconfig,','),'') LIKE '%search_path=""%' FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='aos_verificar_2fa' LIMIT 1), 'SECURITY DEFINER has an empty search_path');
SELECT is((
  SELECT count(*)
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  CROSS JOIN LATERAL aclexplode(p.proacl) a
  WHERE n.nspname='public'
    AND p.proname='aos_verificar_2fa'
    AND a.grantee=0
    AND a.privilege_type='EXECUTE'
), 0::bigint, 'PUBLIC execute is revoked');
SELECT ok(has_function_privilege('anon','public.aos_verificar_2fa(text,text)','EXECUTE'), 'current login caller retains explicit execute');

SELECT * FROM finish();
ROLLBACK;
