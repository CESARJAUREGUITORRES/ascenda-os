BEGIN;

SELECT plan(26);

INSERT INTO public.aos_usuarios
  (codigo_asesor,nombre,email,rol,paneles_acceso,nivel_jerarquia,area,cargo,two_factor,activo)
VALUES
  ('SIOWNER','SI OWNER','owner@example.invalid','admin',
   ARRAY['admin-home','admin-sales-intelligence'],1,'DIRECCION','DIRECTOR GENERAL',true,true),
  ('SIADMIN','SI ADMIN','admin@example.invalid','admin',
   ARRAY['admin-home'],2,'ADMINISTRACION','COORDINADOR',true,true),
  ('SIFORGE','SI FORGE','forge@example.invalid','admin',
   ARRAY['admin-sales-intelligence'],4,'OPERACIONES','OPERATIVO',true,true);

INSERT INTO public.aos_sales_intelligence_access(user_id,enabled,granted_by)
SELECT id,true,id FROM public.aos_usuarios WHERE codigo_asesor='SIOWNER';

INSERT INTO public.aos_metas_ventas(periodo,meta)
VALUES ('2026-01',1000);

INSERT INTO public.aos_ventas(fecha,tratamiento,monto,asesor,sede,tipo)
VALUES
  ('2026-01-10','SERVICIO A',100,'ASESOR TEST','SAN ISIDRO','SERVICIO'),
  ('2026-01-11','PRODUCTO A',50,'ASESOR TEST','PUEBLO LIBRE','PRODUCTO');

INSERT INTO public.aos_auth_codes(usuario,email,codigo,usado,expira_at)
VALUES ('SI OWNER','owner@example.invalid','111111',true,now()+interval '5 minutes');

CREATE TEMP TABLE _si_owner_claim AS
SELECT public.aos_sales_intelligence_claim_session('SI OWNER','111111') AS j;

SELECT is((SELECT (j->>'ok')::boolean FROM _si_owner_claim),true,'authorized owner claims SI session');
SELECT ok((SELECT length(j->>'token')>=64 FROM _si_owner_claim),'opaque token has sufficient entropy');
SELECT is((SELECT count(*) FROM public.aos_cia_admin_sessions WHERE source_auth_code_id is not null),1::bigint,'2FA proof creates exactly one session');
SELECT is((public.aos_sales_intelligence_claim_session('SI OWNER','111111')->>'ok')::boolean,false,'2FA proof cannot be claimed twice');
SELECT is((public.aos_sales_intelligence_gateway('invalid-token',2026,'','')->>'ok')::boolean,false,'invalid token is rejected');

CREATE TEMP TABLE _si_all AS
SELECT public.aos_sales_intelligence_gateway(
  (SELECT j->>'token' FROM _si_owner_claim),2026,'',''
) AS j;
CREATE TEMP TABLE _si_si AS
SELECT public.aos_sales_intelligence_gateway(
  (SELECT j->>'token' FROM _si_owner_claim),2026,'SAN ISIDRO',''
) AS j;
CREATE TEMP TABLE _si_pl AS
SELECT public.aos_sales_intelligence_gateway(
  (SELECT j->>'token' FROM _si_owner_claim),2026,'PUEBLO LIBRE',''
) AS j;

SELECT is((SELECT (j->>'hasData')::boolean FROM _si_all),true,'authorized gateway returns data');
SELECT is((SELECT (j->>'ventasYTD')::bigint FROM _si_all),2::bigint,'all-sites sale count is correct');
SELECT is((SELECT (j->>'ventasYTD')::bigint FROM _si_si),1::bigint,'San Isidro filter is correct');
SELECT is((SELECT (j->>'ventasYTD')::bigint FROM _si_pl),1::bigint,'Pueblo Libre filter is correct');
SELECT is(
  (SELECT (j->>'factYTD')::numeric FROM _si_si)+(SELECT (j->>'factYTD')::numeric FROM _si_pl),
  (SELECT (j->>'factYTD')::numeric FROM _si_all),
  'site amounts reconcile with all-sites total'
);

CREATE TEMP TABLE _si_grant AS
SELECT public.aos_sales_intelligence_set_access(
  (SELECT j->>'token' FROM _si_owner_claim),
  (SELECT id FROM public.aos_usuarios WHERE codigo_asesor='SIADMIN'),
  true
) AS j;

SELECT is((SELECT (j->>'ok')::boolean FROM _si_grant),true,'level-1 owner grants target admin');
SELECT is((SELECT enabled FROM public.aos_sales_intelligence_access sia JOIN public.aos_usuarios u ON u.id=sia.user_id WHERE u.codigo_asesor='SIADMIN'),true,'authoritative access row is enabled');
SELECT ok((SELECT paneles_acceso @> ARRAY['admin-sales-intelligence']::text[] FROM public.aos_usuarios WHERE codigo_asesor='SIADMIN'),'panel mirror is added');

INSERT INTO public.aos_auth_codes(usuario,email,codigo,usado,expira_at)
VALUES ('SI ADMIN','admin@example.invalid','222222',true,now()+interval '5 minutes');
CREATE TEMP TABLE _si_target_claim AS
SELECT public.aos_sales_intelligence_claim_session('SI ADMIN','222222') AS j;
SELECT is((SELECT (j->>'ok')::boolean FROM _si_target_claim),true,'granted target claims own SI session');

CREATE TEMP TABLE _si_revoke AS
SELECT public.aos_sales_intelligence_set_access(
  (SELECT j->>'token' FROM _si_owner_claim),
  (SELECT id FROM public.aos_usuarios WHERE codigo_asesor='SIADMIN'),
  false
) AS j;
SELECT is((SELECT (j->>'ok')::boolean FROM _si_revoke),true,'owner revokes target admin');
SELECT is((SELECT bool_and(revoked) FROM public.aos_cia_admin_sessions s JOIN public.aos_usuarios u ON u.id=s.user_id WHERE u.codigo_asesor='SIADMIN'),true,'revocation invalidates target sessions');
SELECT ok(not (SELECT paneles_acceso @> ARRAY['admin-sales-intelligence']::text[] FROM public.aos_usuarios WHERE codigo_asesor='SIADMIN'),'panel mirror is removed');

INSERT INTO public.aos_auth_codes(usuario,email,codigo,usado,expira_at)
VALUES ('SI FORGE','forge@example.invalid','333333',true,now()+interval '5 minutes');
SELECT is((public.aos_sales_intelligence_claim_session('SI FORGE','333333')->>'ok')::boolean,false,'forged client panel cannot create authoritative access');

SELECT ok(not has_table_privilege('anon','public.aos_sales_intelligence_access','SELECT'),'anon cannot read authoritative grants');
SELECT ok(not has_function_privilege('anon','public.aos_sales_intelligence_summary(integer,text,text)','EXECUTE'),'anon cannot execute raw financial RPC');
SELECT ok(not has_function_privilege('authenticated','public.aos_sales_intelligence_summary(integer,text,text)','EXECUTE'),'authenticated cannot execute raw financial RPC');
SELECT ok(has_function_privilege('anon','public.aos_sales_intelligence_gateway(text,integer,text,text)','EXECUTE'),'anon may call only the token-validating gateway');
SELECT ok(has_function_privilege('anon','public.aos_sales_intelligence_set_access(text,uuid,boolean)','EXECUTE'),'anon may call access manager only with an owner token');
SELECT is((
  SELECT count(*)
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  CROSS JOIN LATERAL aclexplode(p.proacl) a
  WHERE n.nspname='public'
    AND p.proname in (
      'aos_sales_intelligence_claim_session',
      'aos_sales_intelligence_gateway',
      'aos_sales_intelligence_set_access'
    )
    AND a.grantee=0
    AND a.privilege_type='EXECUTE'
),0::bigint,'PUBLIC execute is revoked on protected functions');
SELECT is((
  SELECT count(*)
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname in (
      'aos_sales_intelligence_claim_session',
      'aos_sales_intelligence_gateway',
      'aos_sales_intelligence_set_access',
      'aos_sales_intelligence_guard_user'
    )
    AND coalesce(array_to_string(p.proconfig,','),'') like '%search_path=""%'
),4::bigint,'all SI security-definer functions use an empty search_path');

DO $
DECLARE
  v_token text;
  v_target uuid;
BEGIN
  SELECT j->>'token' INTO v_token FROM _si_owner_claim;
  SELECT id INTO v_target FROM public.aos_usuarios WHERE codigo_asesor='SIADMIN';
  PERFORM public.aos_sales_intelligence_set_access(v_token,v_target,true);
END;
$;
UPDATE public.aos_usuarios SET two_factor=false WHERE codigo_asesor='SIADMIN';
SELECT is((SELECT enabled FROM public.aos_sales_intelligence_access sia JOIN public.aos_usuarios u ON u.id=sia.user_id WHERE u.codigo_asesor='SIADMIN'),false,'demotion or 2FA removal automatically disables access');

SELECT * FROM finish();
ROLLBACK;
