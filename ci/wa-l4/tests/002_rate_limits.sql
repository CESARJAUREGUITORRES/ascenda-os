\set ON_ERROR_STOP on

-- Prior behavioral test leaves several fresh ALLOW decisions and AUTO_OFF.
-- Re-enter synthetic CI CANARY solely to prove rate gates; no provider exists in this fixture.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','CANARY',false,50,50,1,30,0,0,'CI-RATE-GLOBAL-0001');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L4_GLOBAL_RATE_CONTROL %',r; end if;
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4','PHONE','999111555','text',null,'ci-globalrate-00000001',repeat('a',63)||'b','ALLOW','NOT_REQUIRED',false,null);
 if r->>'reason'<>'WA_L4_GLOBAL_RATE_LIMIT' then raise exception 'L4_GLOBAL_RATE %',r; end if;
end $$;

-- Conversation 4 already has a recent verified-template ALLOW from test 001.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','CANARY',false,50,50,120,1,0,0,'CI-RATE-CONV-00001');
 if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'L4_CONV_RATE_CONTROL %',r; end if;
 r:=public.aos_wa_l4_authorize_autonomous_send_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4','PHONE','999111555','text',null,'ci-convrate-000000001',repeat('b',63)||'c','ALLOW','NOT_REQUIRED',false,null);
 if r->>'reason'<>'WA_L4_CONVERSATION_RATE_LIMIT' then raise exception 'L4_CONVERSATION_RATE %',r; end if;
end $$;

-- Return fixture to exact dormant state.
do $$ declare r jsonb; begin
 r:=public.aos_wa_l4_set_control_v1('11111111-1111-4111-8111-111111111111','AUTO_OFF',false,null,null,null,null,null,null,null);
 if r->>'mode'<>'AUTO_OFF' or coalesce((r->>'kill_switch_engaged')::boolean,false) is not true then raise exception 'L4_AUTO_OFF_MUST_FORCE_KILL %',r; end if;
end $$;
