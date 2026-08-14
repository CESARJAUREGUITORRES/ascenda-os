-- ASCENDA OS CIA V3 — Phase 15 compatibility hardening
-- Keep active legacy agent reads working while rejecting arbitrary caller SQL.

revoke insert,update,delete on table public.aos_agente_tareas from anon,authenticated;
grant select on table public.aos_agente_tareas to anon,authenticated;

create or replace function public.aos_execute_agent_query(p_query text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
set statement_timeout to '3000ms'
as $$
declare
  v_result jsonb;
  v_query text:=btrim(coalesce(p_query,''));
  v_upper text;
  v_task_id text;
  v_agent_id text;
begin
  if v_query='' or length(v_query)>12000 then
    return jsonb_build_object('ok',false,'error','QUERY_NOT_ALLOWLISTED');
  end if;
  v_upper:=upper(v_query);
  if v_upper not like 'SELECT%' or position(';' in v_query)>0 or v_query like '%--%' or v_query like '%/*%' or v_query like '%*/%' then
    return jsonb_build_object('ok',false,'error','QUERY_NOT_ALLOWLISTED');
  end if;
  if v_upper like '%PG_CATALOG%' or v_upper like '%INFORMATION_SCHEMA%' or v_upper like '%SUPABASE_MIGRATIONS%' or v_upper like '%AUTH.%' then
    return jsonb_build_object('ok',false,'error','QUERY_NOT_ALLOWLISTED');
  end if;

  select t.id,t.agente_id into v_task_id,v_agent_id
  from public.aos_agente_tareas t
  where t.activa=true
    and lower(coalesce(t.tipo,''))='sql_query'
    and btrim(coalesce(t.input_config->>'query',''))=v_query
  order by t.id
  limit 1;

  if v_task_id is null then
    return jsonb_build_object('ok',false,'error','QUERY_NOT_ALLOWLISTED');
  end if;

  execute 'select coalesce(jsonb_agg(row_to_json(aos_q)::jsonb),''[]''::jsonb) from (select * from ('||v_query||') aos_inner limit 100) aos_q'
  into v_result;

  return jsonb_build_object('ok',true,'data',coalesce(v_result,'[]'::jsonb),'count',jsonb_array_length(coalesce(v_result,'[]'::jsonb)),'guard','F15_CONFIG_ALLOWLIST_V1','task_id',v_task_id,'agent_id',v_agent_id);
exception when query_canceled then
  return jsonb_build_object('ok',false,'error','QUERY_TIMEOUT','guard','F15_CONFIG_ALLOWLIST_V1');
when others then
  return jsonb_build_object('ok',false,'error','QUERY_FAILED','sqlstate',sqlstate,'guard','F15_CONFIG_ALLOWLIST_V1');
end $$;

comment on function public.aos_execute_agent_query(text) is 'LEGACY F15_CONFIG_ALLOWLIST_V1: exact-match active aos_agente_tareas sql_query only; arbitrary caller SQL rejected. Compatibility surface pending broader KronIA V2/K1 migration.';
