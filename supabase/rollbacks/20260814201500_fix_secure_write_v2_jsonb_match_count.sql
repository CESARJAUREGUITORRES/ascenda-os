-- Security-preserving recovery for 20260814201500.
-- Do not restore the invalid jsonb_object_length implementation.
begin;
revoke execute on function public.aos_secure_write_v2(text,text,text,jsonb,jsonb) from anon,authenticated;
grant execute on function public.aos_secure_write_v2(text,text,text,jsonb,jsonb) to service_role;
comment on function public.aos_secure_write_v2(text,text,text,jsonb,jsonb) is
  'RECOVERY_FAIL_CLOSED: browser execution disabled pending validated redeploy; service_role preserved.';
commit;
