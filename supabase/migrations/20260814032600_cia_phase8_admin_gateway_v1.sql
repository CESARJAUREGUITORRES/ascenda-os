-- ASCENDA CIA Phase 8 — browser surface. Internal available_keys remains server-side for Phase 9.

create or replace function public.aos_cia_phase8_admin_gateway_v1(p_token text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  auth jsonb;
  act text:=upper(btrim(coalesce(p_action,'')));
  pl jsonb:=coalesce(p_payload,'{}'::jsonb);
  aid uuid;
  ck text;
  ch text;
  lim integer;
  off integer;
  r1 jsonb;
  r2 jsonb;
  universe integer;
  seg_count integer;
  email_count integer;
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  if jsonb_typeof(pl)<>'object' or pg_column_size(pl)>65536 then return jsonb_build_object('ok',false,'error','INVALID_PAYLOAD'); end if;

  if act='BOOTSTRAP' then
    select count(*) into universe from public.aos_cia_profile_fast_v2;
    select count(*) into seg_count from public.aos_cia_segment_runtime_cache_v2;
    select count(*) into email_count from public.aos_cia_email_runtime_cache_v2;
    return jsonb_build_object('ok',true,'policies',(public.aos_cia_context_policy_list_internal_v1(null)->'items'),
      'freshness',jsonb_build_object('universe',universe,'segment_cache',seg_count,'email_cache',email_count,'stale_dependencies',(seg_count<>universe or email_count<>universe)),
      'semantics',jsonb_build_object('unknown_is_assignable',false,'availability_requires_eligibility',true,'phase9_contract','AVAILABLE+ACTIVE only'));
  elsif act='REFRESH_DEPENDENCIES' then
    r1:=public.aos_cia_refresh_segment_cache_v2();
    r2:=public.aos_cia_refresh_email_cache_v2();
    return jsonb_build_object('ok',true,'segment',r1,'email',r2);
  elsif act='LIST_POLICIES' then
    ch:=nullif(upper(btrim(coalesce(pl->>'channel',''))),'');
    return public.aos_cia_context_policy_list_internal_v1(ch);
  elsif act='BIND_CONTEXT' then
    aid:=nullif(pl->>'activation_id','')::uuid;
    if aid is null then return jsonb_build_object('ok',false,'error','ACTIVATION_ID_REQUIRED'); end if;
    return public.aos_cia_activation_context_bind_admin_v1(p_token,aid,nullif(pl->>'policy_key',''),nullif(pl->>'policy_version','')::integer);
  elsif act='SUMMARY' then
    aid:=nullif(pl->>'activation_id','')::uuid;
    if aid is null then return jsonb_build_object('ok',false,'error','ACTIVATION_ID_REQUIRED'); end if;
    return public.aos_cia_activation_context_summary_v1(aid);
  elsif act='PREVIEW' then
    aid:=nullif(pl->>'activation_id','')::uuid;
    if aid is null then return jsonb_build_object('ok',false,'error','ACTIVATION_ID_REQUIRED'); end if;
    lim:=least(greatest(coalesce(nullif(pl->>'limit','')::integer,50),1),100);
    off:=greatest(coalesce(nullif(pl->>'offset','')::integer,0),0);
    return public.aos_cia_activation_context_preview_v1(aid,lim,off);
  elsif act='EXPLAIN' then
    aid:=nullif(pl->>'activation_id','')::uuid;
    ck:=nullif(btrim(coalesce(pl->>'contact_key','')),'');
    if aid is null or ck is null then return jsonb_build_object('ok',false,'error','ACTIVATION_AND_CONTACT_REQUIRED'); end if;
    return public.aos_cia_activation_context_explain_v1(aid,ck);
  end if;
  return jsonb_build_object('ok',false,'error','UNKNOWN_ACTION');
exception when invalid_text_representation then
  return jsonb_build_object('ok',false,'error','INVALID_IDENTIFIER');
end;
$$;
