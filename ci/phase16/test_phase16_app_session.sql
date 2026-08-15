-- F16 synthetic Auth V3 session verification tests.

do $test$
declare j jsonb;
begin
  j := public.aos_cia_verify_app_session_v1('synthetic-app-token-valid-000000000000000001');
  if coalesce((j->>'ok')::boolean,false) is not true
     or j->>'user_id' <> '00000000-0000-0000-0000-000000000002'
     or j->>'rol' <> 'ASESOR' then
    raise exception 'F16_APP_SESSION_TEST_FAIL: valid current session rejected %',j;
  end if;

  j := public.aos_cia_verify_app_session_v1('synthetic-app-token-revoked-00000000000001');
  if coalesce((j->>'ok')::boolean,true) is true then
    raise exception 'F16_APP_SESSION_TEST_FAIL: revoked session accepted %',j;
  end if;

  j := public.aos_cia_verify_app_session_v1('synthetic-app-token-expired-00000000000001');
  if coalesce((j->>'ok')::boolean,true) is true then
    raise exception 'F16_APP_SESSION_TEST_FAIL: expired session accepted %',j;
  end if;

  j := public.aos_cia_verify_app_session_v1('wrong-token-that-is-long-enough-to-pass-length-only');
  if coalesce((j->>'ok')::boolean,true) is true then
    raise exception 'F16_APP_SESSION_TEST_FAIL: invalid token accepted %',j;
  end if;

  if has_function_privilege('anon','public.aos_cia_verify_app_session_v1(text)','EXECUTE')
     or has_function_privilege('authenticated','public.aos_cia_verify_app_session_v1(text)','EXECUTE') then
    raise exception 'F16_APP_SESSION_TEST_FAIL: app-session verifier leaked to browser role';
  end if;
  if not has_function_privilege('service_role','public.aos_cia_verify_app_session_v1(text)','EXECUTE') then
    raise exception 'F16_APP_SESSION_TEST_FAIL: service role cannot verify app sessions';
  end if;
end
$test$;

select 'CIA_PHASE16_APP_SESSION_VERIFIER=PASS' as result;
