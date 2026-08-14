begin;

select plan(3);

select is(
  (select count(*) from pg_policies where schemaname='public' and tablename='aos_integraciones' and policyname='anon_integ_read_non_auth_provider'),
  1::bigint,
  'anon integration read policy is replaced by provider-aware boundary'
);

select ok(
  coalesce((select qual from pg_policies where schemaname='public' and tablename='aos_integraciones' and policyname='anon_integ_read_non_auth_provider'),'') ilike '%resend%',
  'Resend auth-provider rows are excluded from anon reads'
);

select ok(
  coalesce((select with_check from pg_policies where schemaname='public' and tablename='aos_integraciones' and policyname='anon_integ_write_non_auth_provider'),'') ilike '%resend%',
  'Resend auth-provider rows are excluded from anon writes'
);

select * from finish();
rollback;
