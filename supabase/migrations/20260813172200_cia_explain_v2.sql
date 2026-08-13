-- CIA Phase 5 — domain-aware explain V2.
begin;

create or replace function public.aos_cia_contact_exists_fast_v2(p_contact_key text)
returns boolean language sql stable security invoker as $$
select exists(select 1 from public.aos_pacientes where numero_limpio in(p_contact_key,'51'||p_contact_key) limit 1)
 or exists(select 1 from public.aos_leads where numero_limpio in(p_contact_key,'51'||p_contact_key) limit 1)
 or exists(select 1 from public.aos_llamadas where numero_limpio in(p_contact_key,'51'||p_contact_key) limit 1)
 or exists(select 1 from public.aos_agenda_citas where numero_limpio in(p_contact_key,'51'||p_contact_key) limit 1)
 or exists(select 1 from public.aos_ventas where numero_limpio in(p_contact_key,'51'||p_contact_key) limit 1);
$$;

create or replace function public.aos_cia_audience_observe_special_fast_v2(p_contact_key text,p_rule jsonb)
returns jsonb language plpgsql stable security invoker as $$
declare f text:=p_rule->>'field';sp text;observed jsonb;has_event boolean;lead_at timestamptz;call_at timestamptz;
begin
 select special_key into sp from public.aos_cia_filter_execution_map_v2 where field_key=f;
 if sp is null then return null;end if;
 if sp='EXISTS_AS_LEAD' then select exists(select 1 from public.aos_leads where numero_limpio in(p_contact_key,'51'||p_contact_key)) into has_event;observed:=to_jsonb(has_event);
 elsif sp='CALLS_NEVER' then select exists(select 1 from public.aos_llamadas where numero_limpio in(p_contact_key,'51'||p_contact_key)) into has_event;observed:=to_jsonb(not has_event);
 elsif sp='APPOINTMENTS_NEVER' then select exists(select 1 from public.aos_agenda_citas where numero_limpio in(p_contact_key,'51'||p_contact_key)) into has_event;observed:=to_jsonb(not has_event);
 elsif sp='SALES_NEVER' then select exists(select 1 from public.aos_ventas where numero_limpio in(p_contact_key,'51'||p_contact_key)) into has_event;observed:=to_jsonb(not has_event);
 elsif sp in('LEAD_CALLED_SINCE','LEAD_UNWORKED') then
   select coalesce(hora_ingreso,created_at,fecha::timestamp at time zone 'America/Lima') into lead_at
   from public.aos_leads where numero_limpio in(p_contact_key,'51'||p_contact_key)
   order by coalesce(hora_ingreso,created_at,fecha::timestamp at time zone 'America/Lima') desc,id desc limit 1;
   if lead_at is null then observed:=null;
   else select max(created_at) into call_at from public.aos_llamadas where numero_limpio in(p_contact_key,'51'||p_contact_key);
     observed:=case when sp='LEAD_CALLED_SINCE' then to_jsonb(call_at is not null and call_at>=lead_at) else to_jsonb(call_at is null or call_at<lead_at) end;
   end if;
 else return null;end if;
 return jsonb_build_object('found',true,'source_key','SPECIAL','observed',observed,'row',jsonb_build_object(f,observed));
end;$$;

create or replace function public.aos_cia_audience_observe_leaf_base_v2(p_contact_key text,p_rule jsonb)
returns jsonb language plpgsql stable security invoker as $$
declare f text:=p_rule->>'field';sk text;sp text;rowj jsonb;observed jsonb;unresolved integer:=0;i record;
begin
 select source_key,special_key into sk,sp from public.aos_cia_filter_execution_map_v2 where field_key=f;
 if sk is null then return jsonb_build_object('found',false,'source_key',null,'observed',null);end if;
 if sp in('EXISTS_AS_LEAD','CALLS_NEVER','APPOINTMENTS_NEVER','SALES_NEVER') then
   select * into i from public.aos_cia_contact_identity_v1 where contact_key=p_contact_key;
   if not found then return jsonb_build_object('found',false,'source_key','IDENTITY','observed',null);end if;
   observed:=case sp when 'EXISTS_AS_LEAD' then to_jsonb(i.has_lead) when 'CALLS_NEVER' then to_jsonb(not i.has_call)
     when 'APPOINTMENTS_NEVER' then to_jsonb(not i.has_appointment) when 'SALES_NEVER' then to_jsonb(not i.has_sale) end;
   return jsonb_build_object('found',true,'source_key','IDENTITY','observed',observed,'row',jsonb_build_object(f,observed));
 elsif sp in('LEAD_CALLED_SINCE','LEAD_UNWORKED') then
   select to_jsonb(x) into rowj from public.aos_cia_lead_call_state_v2 x where x.contact_key=p_contact_key;
   if rowj is null then return jsonb_build_object('found',true,'source_key','LEAD_CALL','observed',null,'row','{}'::jsonb);end if;
   observed:=case sp when 'LEAD_CALLED_SINCE' then rowj->'called_since_latest_entry' else rowj->'unworked_since_latest_entry' end;
   return jsonb_build_object('found',true,'source_key','LEAD_CALL','observed',observed,'row',jsonb_build_object(f,observed));
 elsif sp='CRM_BRANCH' then select jsonb_build_object('crm_branch',x.branch) into rowj from public.aos_cia_branch_fast_v2 x where x.contact_key=p_contact_key;
 elsif sk='IDENTITY' then select to_jsonb(x) into rowj from public.aos_cia_contact_identity_v1 x where x.contact_key=p_contact_key;
 elsif sk='PROFILE' then select to_jsonb(x) into rowj from public.aos_cia_profile_adapter_v2 x where x.contact_key=p_contact_key;
 elsif sk='LEAD' then select to_jsonb(x) into rowj from public.aos_cia_lead_adapter_v2 x where x.contact_key=p_contact_key;
 elsif sk='CALL' then select to_jsonb(x) into rowj from public.aos_cia_call_adapter_v2 x where x.contact_key=p_contact_key;
 elsif sk='APPOINTMENT' then select to_jsonb(x) into rowj from public.aos_cia_appointment_adapter_v2 x where x.contact_key=p_contact_key;
 elsif sk='SALE' then select to_jsonb(x) into rowj from public.aos_cia_sale_adapter_v2 x where x.contact_key=p_contact_key;
 elsif sk='FOLLOWUP' then select to_jsonb(x) into rowj from public.aos_cia_followup_adapter_v2 x where x.contact_key=p_contact_key;
 elsif sk='EMAIL' then select to_jsonb(x) into rowj from public.aos_cia_email_adapter_v2 x where x.contact_key=p_contact_key;
 elsif sk='SEGMENT' then select to_jsonb(x) into rowj from public.aos_cia_segment_adapter_v2 x where x.contact_key=p_contact_key;
 elsif sk='PURCHASE' then select to_jsonb(x) into rowj from public.aos_cia_purchase_adapter_v2 x where x.contact_key=p_contact_key;
 end if;
 if rowj is null and sk in('LEAD','CALL','APPOINTMENT','SALE','FOLLOWUP') then select default_row into rowj from public.aos_cia_domain_defaults_v2 where source_key=sk;end if;
 if rowj is null then rowj:='{}'::jsonb;end if;
 observed:=public.aos_cia_audience_observed_value_v1(rowj,f);
 unresolved:=case when f in('sales.products','sales.product_categories') then coalesce((rowj->>'product_unresolved_count')::integer,0)
   when f='sales.service_categories' then coalesce((rowj->>'service_category_unresolved_count')::integer,0)
   when f='sales.services' then coalesce((rowj->>'service_unresolved_count')::integer,0) else 0 end;
 return jsonb_build_object('found',true,'source_key',sk,'observed',observed,'unresolved_evidence',unresolved,'row',rowj);
end;$$;

create or replace function public.aos_cia_audience_observe_leaf_v2(p_contact_key text,p_rule jsonb)
returns jsonb language plpgsql stable security invoker as $$
declare v jsonb;begin
 v:=public.aos_cia_audience_observe_special_fast_v2(p_contact_key,p_rule);
 if v is not null then return v;end if;
 return public.aos_cia_audience_observe_leaf_base_v2(p_contact_key,p_rule);
end;$$;

create or replace function public.aos_cia_audience_trace_node_v2(p_contact_key text,p_node jsonb,p_depth integer default 1)
returns jsonb language plpgsql stable security invoker as $$
declare r jsonb;children jsonb:='[]'::jsonb;child jsonb;f text;op text;obs_info jsonb;observed jsonb;rowj jsonb;
 matched boolean:=false;state text;reason text;unresolved integer:=0;present boolean:=false;
 any_match boolean:=false;any_unknown boolean:=false;any_miss boolean:=false;
begin
 if p_depth>2 then return jsonb_build_object('kind','group','evaluation_state','MISS','reason_code','MAX_DEPTH');end if;
 if p_node?'field' then
   f:=p_node->>'field';op:=p_node->>'operator';obs_info:=public.aos_cia_audience_observe_leaf_v2(p_contact_key,p_node);
   observed:=obs_info->'observed';rowj:=coalesce(obs_info->'row','{}'::jsonb);unresolved:=coalesce((obs_info->>'unresolved_evidence')::integer,0);
   matched:=public.aos_cia_audience_rule_match_v1(rowj,p_node);
   if op='never_contains' and jsonb_typeof(observed)='array' then
     present:=exists(select 1 from jsonb_array_elements_text(observed)x where upper(btrim(x))=upper(btrim(p_node->>'value')));
     state:=case when present then 'MISS' when unresolved>0 then 'UNKNOWN' when matched then 'MATCH' else 'MISS' end;
   elsif(observed is null or observed='null'::jsonb)and op not in('is_unknown','exists','not_exists') then state:='UNKNOWN';
   else state:=case when matched then 'MATCH' else 'MISS' end;end if;
   reason:=state||'_'||regexp_replace(upper(f||'_'||op),'[^A-Z0-9]+','_','g');
   return jsonb_build_object('kind','rule','field',f,'operator',op,'expected',p_node->'value','observed',observed,
    'matched',state='MATCH','evaluation_state',state,'reason_code',reason,'source_key',obs_info->>'source_key',
    'unresolved_evidence',case when op='never_contains' then unresolved else null end);
 end if;
 op:=upper(coalesce(p_node->>'op',''));
 for r in select value from jsonb_array_elements(coalesce(p_node->'rules','[]'::jsonb)) loop
   child:=public.aos_cia_audience_trace_node_v2(p_contact_key,r,case when r?'field' then p_depth else p_depth+1 end);
   children:=children||jsonb_build_array(child);any_match:=any_match or coalesce(child->>'evaluation_state','')='MATCH';
   any_unknown:=any_unknown or coalesce(child->>'evaluation_state','')='UNKNOWN';any_miss:=any_miss or coalesce(child->>'evaluation_state','')='MISS';
 end loop;
 if op='AND' then state:=case when any_miss then 'MISS' when any_unknown then 'UNKNOWN' else 'MATCH' end;
 elsif op='OR' then state:=case when any_match then 'MATCH' when any_unknown then 'UNKNOWN' else 'MISS' end;else state:='MISS';end if;
 return jsonb_build_object('kind','group','op',op,'matched',state='MATCH','evaluation_state',state,'children',children);
end;$$;

create or replace function public.aos_cia_audience_explain_v2(p_filter jsonb,p_contact_key text)
returns jsonb language plpgsql stable security invoker as $$
declare v jsonb;trace jsonb;seg_fresh timestamptz;email_fresh timestamptz;
begin
 v:=public.aos_cia_audience_validate_v1(p_filter);if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v);end if;
 if not public.aos_cia_contact_exists_fast_v2(p_contact_key) then return jsonb_build_object('ok',false,'error','CONTACT_NOT_FOUND','contact_key',p_contact_key);end if;
 trace:=public.aos_cia_audience_trace_node_v2(p_contact_key,p_filter->'root',1);
 select max(cache_refreshed_at)into seg_fresh from public.aos_cia_segment_runtime_cache_v2;select max(cache_refreshed_at)into email_fresh from public.aos_cia_email_runtime_cache_v2;
 return jsonb_build_object('ok',true,'contact_key',p_contact_key,'included',(trace->>'evaluation_state')='MATCH','evaluation_state',trace->>'evaluation_state',
  'trace',trace,'registry_version',1,'resolver_version',2,'segment_cache_refreshed_at',seg_fresh,'email_cache_refreshed_at',email_fresh,'observed_at',statement_timestamp());
end;$$;

revoke all on function public.aos_cia_contact_exists_fast_v2(text),public.aos_cia_audience_observe_special_fast_v2(text,jsonb),
 public.aos_cia_audience_observe_leaf_base_v2(text,jsonb),public.aos_cia_audience_observe_leaf_v2(text,jsonb),
 public.aos_cia_audience_trace_node_v2(text,jsonb,integer),public.aos_cia_audience_explain_v2(jsonb,text)
from public,anon,authenticated;
grant execute on function public.aos_cia_contact_exists_fast_v2(text),public.aos_cia_audience_observe_special_fast_v2(text,jsonb),
 public.aos_cia_audience_observe_leaf_base_v2(text,jsonb),public.aos_cia_audience_observe_leaf_v2(text,jsonb),
 public.aos_cia_audience_trace_node_v2(text,jsonb,integer),public.aos_cia_audience_explain_v2(jsonb,text) to service_role;

commit;
