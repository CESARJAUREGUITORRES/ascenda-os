-- ASCENDA CIA Phase 6 — extend existing ADMIN gateway with audience library actions.

create or replace function public.aos_cia_admin_gateway_v1(
  p_token text,
  p_action text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  auth jsonb;
  a text:=upper(btrim(coalesce(p_action,'')));
  started timestamptz:=clock_timestamp();
  outj jsonb;
  uid uuid;
  uname text;
  lim integer;
  offv integer;
  aid uuid;
  aid_text text;
  expected_ver integer;
begin
  auth:=public.aos_cia_verify_admin_session_v1(p_token);
  if not coalesce((auth->>'ok')::boolean,false) then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  uid:=(auth->>'user_id')::uuid;
  uname:=auth->>'usuario';

  if pg_column_size(coalesce(p_payload,'{}'::jsonb))>65536 then
    outj:=jsonb_build_object('ok',false,'error','PAYLOAD_TOO_LARGE');

  elsif a='BOOTSTRAP' then
    select jsonb_build_object(
      'ok',true,
      'registry',coalesce((select jsonb_agg(to_jsonb(r) order by r.category,r.label) from public.aos_audience_filter_registry r where r.active and r.ui_visible),'[]'::jsonb),
      'presets',coalesce((select jsonb_agg(to_jsonb(p) order by p.category,p.name) from public.aos_audience_presets p where p.active),'[]'::jsonb),
      'summary',jsonb_build_object(
        'contacts',(select count(*) from public.aos_cia_contact_identity_v1),
        'segments',coalesce((select jsonb_object_agg(value_tier,n) from (select value_tier,count(*) n from public.aos_cia_segment_runtime_cache_v2 group by value_tier) s),'{}'::jsonb),
        'identity_conflicts',(select count(*) from public.aos_cia_contact_identity_v1 where identity_conflict),
        'audiences_active',(select count(*) from public.aos_audiencias where estado='ACTIVE'),
        'audiences_archived',(select count(*) from public.aos_audiencias where estado='ARCHIVED')
      ),
      'freshness',jsonb_build_object(
        'segment_cache_refreshed_at',(select max(cache_refreshed_at) from public.aos_cia_segment_runtime_cache_v2),
        'email_cache_refreshed_at',(select max(cache_refreshed_at) from public.aos_cia_email_runtime_cache_v2),
        'operational_facts','LIVE'
      ),
      'resolver_version',2,
      'phase',6
    ) into outj;

  elsif a='VALIDATE' then
    outj:=jsonb_build_object('ok',true,'validation',public.aos_cia_audience_validate_v1(p_payload->'filter'));
  elsif a='COUNT' then
    outj:=public.aos_cia_audience_count_v2(p_payload->'filter');
  elsif a='PREVIEW' then
    lim:=greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100));
    offv:=greatest(0,coalesce((p_payload->>'offset')::integer,0));
    outj:=public.aos_cia_audience_preview_v2(p_payload->'filter',lim,offv);
  elsif a='EXPLAIN' then
    outj:=public.aos_cia_audience_explain_v2(p_payload->'filter',p_payload->>'contact_key');
  elsif a='REFRESH_SEGMENTS' then
    outj:=public.aos_cia_refresh_segment_cache_v2();
  elsif a='REFRESH_EMAIL' then
    outj:=public.aos_cia_refresh_email_cache_v2();

  elsif a='LIST_AUDIENCES' then
    lim:=greatest(1,least(coalesce((p_payload->>'limit')::integer,50),100));
    offv:=greatest(0,coalesce((p_payload->>'offset')::integer,0));
    outj:=public.aos_cia_audience_library_list_v1(coalesce((p_payload->>'include_archived')::boolean,false),lim,offv);

  elsif a in ('GET_AUDIENCE','UPDATE_AUDIENCE','ARCHIVE_AUDIENCE','RESTORE_AUDIENCE') then
    aid_text:=coalesce(p_payload->>'audience_id','');
    if aid_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
      outj:=jsonb_build_object('ok',false,'error','INVALID_AUDIENCE_ID');
    else
      aid:=aid_text::uuid;
      if a='GET_AUDIENCE' then
        outj:=public.aos_cia_audience_library_get_v1(aid);
      elsif a='ARCHIVE_AUDIENCE' then
        outj:=public.aos_cia_audience_library_archive_v1(uid,aid);
      elsif a='RESTORE_AUDIENCE' then
        outj:=public.aos_cia_audience_library_restore_v1(uid,aid);
      else
        if coalesce(p_payload->>'expected_version','') !~ '^[0-9]+$' then
          outj:=jsonb_build_object('ok',false,'error','EXPECTED_VERSION_REQUIRED');
        else
          expected_ver:=(p_payload->>'expected_version')::integer;
          outj:=public.aos_cia_audience_library_update_v1(
            uid,aid,expected_ver,p_payload->>'name',p_payload->>'description',p_payload->'filter',p_payload->>'reason'
          );
        end if;
      end if;
    end if;

  elsif a='CREATE_AUDIENCE' then
    outj:=public.aos_cia_audience_library_create_v1(
      uid,p_payload->>'name',p_payload->>'description',p_payload->'filter',p_payload->>'reason'
    );

  elsif a='DUPLICATE_AUDIENCE' then
    aid_text:=coalesce(p_payload->>'source_audience_id','');
    if aid_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
      outj:=jsonb_build_object('ok',false,'error','INVALID_AUDIENCE_ID');
    else
      aid:=aid_text::uuid;
      outj:=public.aos_cia_audience_library_duplicate_v1(uid,aid,p_payload->>'name',p_payload->>'description');
    end if;

  else
    outj:=jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED');
  end if;

  insert into public.aos_cia_gateway_audit(user_id,usuario,action,ok,duration_ms,meta)
  values(
    uid,uname,a,coalesce((outj->>'ok')::boolean,false),
    greatest(0,round(extract(epoch from(clock_timestamp()-started))*1000)::integer),
    jsonb_build_object(
      'resolver_version',2,'phase',6,
      'audience_id',coalesce(outj#>>'{audience,id}',p_payload->>'audience_id',p_payload->>'source_audience_id')
    )
  );
  return outj;
exception when others then
  if uid is not null then
    insert into public.aos_cia_gateway_audit(user_id,usuario,action,ok,duration_ms,meta)
    values(uid,coalesce(uname,'?'),a,false,greatest(0,round(extract(epoch from(clock_timestamp()-started))*1000)::integer),jsonb_build_object('error_code',sqlstate,'phase',6));
  end if;
  return jsonb_build_object('ok',false,'error','GATEWAY_ERROR','code',sqlstate);
end;
$$;

revoke all on function public.aos_cia_admin_gateway_v1(text,text,jsonb) from public;
grant execute on function public.aos_cia_admin_gateway_v1(text,text,jsonb) to anon, authenticated, service_role;
