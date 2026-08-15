begin;
create extension if not exists pgtap;
select no_plan();

select has_table('public','aos_wa_ai_control_v1','WA4 AI control exists');
select has_table('public','aos_wa_ai_runs_v1','WA4 AI runs audit exists');
select has_trigger('public','aos_wa_ai_runs_v1','trg_aos_wa4_ai_run_append_guard_v1','WA4 audit append guard exists');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_ai_control_v1'::regclass),'WA4 control FORCE RLS');
select ok((select relforcerowsecurity from pg_class where oid='public.aos_wa_ai_runs_v1'::regclass),'WA4 runs FORCE RLS');
select ok(not has_table_privilege('anon','public.aos_wa_ai_control_v1','SELECT'),'anon cannot read WA4 control');
select ok(not has_table_privilege('authenticated','public.aos_wa_ai_runs_v1','SELECT'),'authenticated cannot read WA4 runs');
select ok(has_table_privilege('service_role','public.aos_wa_ai_runs_v1','INSERT'),'service role can append WA4 audit');
select is((select provider from public.aos_wa_ai_control_v1 where id=1),'groq','provider is Groq');
select is((select fast_model from public.aos_wa_ai_control_v1 where id=1),'openai/gpt-oss-20b','fast model current');
select is((select reasoning_model from public.aos_wa_ai_control_v1 where id=1),'openai/gpt-oss-120b','reasoning model current');
select is((select safety_model from public.aos_wa_ai_control_v1 where id=1),'openai/gpt-oss-safeguard-20b','safety model current');
select is((select copilot_enabled from public.aos_wa_ai_control_v1 where id=1),false,'copilot defaults OFF');
select is((select auto_reply_enabled from public.aos_wa_ai_control_v1 where id=1),false,'auto reply defaults OFF');
select throws_ok($$update public.aos_wa_ai_control_v1 set auto_reply_enabled=true where id=1$$,'23514',null,'auto reply cannot be enabled in WA4');
select is(public.aos_wa4_authorize_copilot_v1('bad-token-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx','10000000-0000-4000-8000-000000000001')->>'error','WA4_2FA_PANEL_REQUIRED','unknown token rejected');
select is(public.aos_wa4_authorize_copilot_v1('admin-token-111111111111111111111111111111111111','10000000-0000-4000-8000-000000000001')->>'error','WA4_COPILOT_DISABLED','disabled copilot rejects before conversation access');
select is(public.aos_wa4_admin_set_control_v1('44444444-4444-4444-8444-444444444444',true,0.5)->>'error','WA4_ADMIN_REQUIRED','nonadmin cannot enable copilot');
select ok((public.aos_wa4_admin_set_control_v1('11111111-1111-4111-8111-111111111111',true,0.5)->>'ok')::boolean,'admin enables copilot');
select is((select auto_reply_enabled from public.aos_wa_ai_control_v1 where id=1),false,'enabling copilot never enables auto reply');

update public.aos_usuarios set paneles_acceso=array_append(coalesce(paneles_acceso,'{}'::text[]),'whatsapp-agent') where id='44444444-4444-4444-8444-444444444444';
select ok((public.aos_wa3_box_upsert_v1('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','WA4','WA4 Canary','MANUAL','ACTIVE',true,10)->>'ok')::boolean,'WA4 canary box created through WA3');
select ok((public.aos_wa3_box_member_set_v1('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444',true,3,10)->>'ok')::boolean,'agent added through WA3 governance');
insert into public.aos_wa_conversations_v1(id,conversation_key,contact_number,contact_name,state) values ('10000000-0000-4000-8000-000000000001','wa4:conv1','51990000001','WA4 Uno','NEW');
select ok((public.aos_wa3_route_v1('10000000-0000-4000-8000-000000000001','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111','WA4_TEST')->>'ok')::boolean,'WA3 assigns conversation to exact agent');
select is(public.aos_wa4_authorize_copilot_v1('admin-token-111111111111111111111111111111111111','10000000-0000-4000-8000-000000000001')->>'error','WA4_NOT_OWNER','admin cannot bypass exact ownership');
select ok((public.aos_wa4_authorize_copilot_v1('agent-a-token-44444444444444444444444444444444444','10000000-0000-4000-8000-000000000001')->>'ok')::boolean,'exact owner passes WA4 copilot gate');
select is(public.aos_wa4_authorize_copilot_v1('agent-a-token-44444444444444444444444444444444444','10000000-0000-4000-8000-000000000001')->>'auto_reply_enabled','false','authorized copilot still reports auto reply false');
select is(public.aos_wa3_set_mode_v1('10000000-0000-4000-8000-000000000001','44444444-4444-4444-8444-444444444444','AI_COPILOT')->>'state','AI_COPILOT','WA3 permits governed copilot mode');
select ok((public.aos_wa4_authorize_copilot_v1('agent-a-token-44444444444444444444444444444444444','10000000-0000-4000-8000-000000000001')->>'ok')::boolean,'owner remains authorized in AI_COPILOT');
select is(public.aos_wa3_set_mode_v1('10000000-0000-4000-8000-000000000001','44444444-4444-4444-8444-444444444444','AI_ACTIVE')->>'error','WA3_MODE_NOT_ALLOWED','WA4 cannot create AI_ACTIVE');

insert into public.aos_wa_ai_runs_v1(conversation_id,actor_id,task,provider,model,safety_model,outcome,estimated_cost_usd)
values('10000000-0000-4000-8000-000000000001','44444444-4444-4444-8444-444444444444','SALES_COPILOT','groq','openai/gpt-oss-20b','openai/gpt-oss-safeguard-20b','SUGGESTED',0.50000000);
select is(public.aos_wa4_authorize_copilot_v1('agent-a-token-44444444444444444444444444444444444','10000000-0000-4000-8000-000000000001')->>'error','WA4_DAILY_BUDGET_REACHED','daily budget fails closed');
select throws_ok($$update public.aos_wa_ai_runs_v1 set outcome='ERROR' where conversation_id='10000000-0000-4000-8000-000000000001'$$,'55000','WA4_AI_RUN_APPEND_ONLY','AI audit is append-only');
select throws_ok($$delete from public.aos_wa_ai_runs_v1 where conversation_id='10000000-0000-4000-8000-000000000001'$$,'55000','WA4_AI_RUN_APPEND_ONLY','AI audit cannot be deleted');
select ok(has_function_privilege('anon','public.aos_wa4_authorize_copilot_v1(text,uuid)','EXECUTE'),'anon can call tokenized copilot gate');
select ok(not has_function_privilege('anon','public.aos_wa4_admin_set_control_v1(uuid,boolean,numeric)','EXECUTE'),'anon cannot mutate WA4 control');
select ok(has_function_privilege('service_role','public.aos_wa4_admin_set_control_v1(uuid,boolean,numeric)','EXECUTE'),'service role can mutate WA4 control');
select is((select count(*)::bigint from information_schema.columns where table_schema='public' and table_name='aos_wa_ai_runs_v1' and column_name in ('prompt','response','message_body','raw_prompt','raw_response')),0::bigint,'WA4 audit stores no raw prompt/reply columns');

select * from finish();
rollback;
