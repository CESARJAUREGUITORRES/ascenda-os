\set ON_ERROR_STOP on

begin;

-- Synthetic authority only; fixture contains no production identity/PII.
update public.aos_usuarios
set paneles_acceso = case when paneles_acceso @> array['admin-config']::text[] then paneles_acceso else array_append(paneles_acceso,'admin-config') end
where codigo_asesor='CAROWNER';

insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at)
select encode(extensions.digest('secure-write-p0-token-0000000000000000001','sha256'),'hex'),id,'PASSWORD_2FA',now()+interval '1 hour'
from public.aos_usuarios where codigo_asesor='CAROWNER'
on conflict (token_hash) do update set revoked=false,expires_at=excluded.expires_at;

do $$
declare
  j jsonb;
  def text;
begin
  def:=pg_get_functiondef('public.aos_secure_write_v2(text,text,text,jsonb,jsonb)'::regprocedure);
  if position('jsonb_object_length' in def)>0 then
    raise exception 'P0-SW-01 invalid jsonb_object_length survived';
  end if;
  if position('jsonb_object_keys' in def)=0 then
    raise exception 'P0-SW-02 expected jsonb_object_keys guard missing';
  end if;

  j:=public.aos_secure_write_v2(
    'secure-write-p0-token-0000000000000000001',
    'aos_catalogo_categorias','DELETE','{}'::jsonb,'{}'::jsonb
  );
  if j->>'error'<>'MATCH_REQUIRED' then
    raise exception 'P0-SW-03 empty DELETE match must fail MATCH_REQUIRED, got %',j;
  end if;

  j:=public.aos_secure_write_v2(
    'secure-write-p0-token-0000000000000000001',
    'aos_tabla_no_permitida','DELETE',jsonb_build_object('id','x'),'{}'::jsonb
  );
  if j->>'error'<>'TABLE_NOT_ALLOWED' then
    raise exception 'P0-SW-04 allowlist boundary changed: %',j;
  end if;

  j:=public.aos_secure_write_v2(
    'invalid-token','aos_catalogo_categorias','DELETE',jsonb_build_object('id','x'),'{}'::jsonb
  );
  if j->>'error'<>'UNAUTHORIZED' then
    raise exception 'P0-SW-05 invalid token boundary changed: %',j;
  end if;
end $$;

select 'PHASE2_SECURE_WRITE_JSONB_P0=PASS' as certificate;
rollback;
