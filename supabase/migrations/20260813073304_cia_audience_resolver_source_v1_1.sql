-- ASCENDA OS — CIA Phase 4 resolver contracts on Audience Source V1.1
begin;
create or replace function public.aos_cia_audience_count_v1(p_filter jsonb)
returns jsonb language plpgsql stable as $$
declare v jsonb;n bigint;
begin
 v:=public.aos_cia_audience_validate_v1(p_filter);
 if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v);end if;
 select count(*) into n from public.aos_cia_audience_source_v1_1 s where public.aos_cia_audience_eval_node_v1(to_jsonb(s),p_filter->'root',1);
 return jsonb_build_object('ok',true,'count',n,'registry_version',1,'source_version','1.1','observed_at',statement_timestamp());
end;$$;

create or replace function public.aos_cia_audience_preview_v1(p_filter jsonb,p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql stable as $$
declare v jsonb;lim integer;offv integer;items jsonb;n bigint;
begin
 v:=public.aos_cia_audience_validate_v1(p_filter);
 if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v);end if;
 lim:=greatest(1,least(coalesce(p_limit,50),100));offv:=greatest(0,coalesce(p_offset,0));
 select count(*) into n from public.aos_cia_audience_source_v1_1 s where public.aos_cia_audience_eval_node_v1(to_jsonb(s),p_filter->'root',1);
 select coalesce(jsonb_agg(rowj),'[]'::jsonb) into items from (
  select jsonb_build_object(
   'contact_key',s.contact_key,'identity_status',s.identity_status,'identity_conflict',s.identity_conflict,
   'name',nullif(btrim(concat_ws(' ',s.canonical_names,s.canonical_surnames)),''),'branch',s.crm_branch,'age_band',s.age_band,'patient_state',s.patient_state,
   'value_tier',s.value_tier,'lifecycle',s.lifecycle,'engagement',s.engagement,'traits',s.traits,
   'latest_interest',s.latest_interest,'last_call_at',s.last_call_at,'latest_call_status',s.latest_call_status,
   'has_future_appointment',s.has_future_appointment,'next_appointment_at',s.next_appointment_at,
   'sale_count',s.sale_count,'revenue_lifetime',s.revenue_lifetime,
   'products',s.canonical_products,'product_categories',s.product_categories,'product_unresolved_count',s.product_unresolved_count,
   'services',s.canonical_services,'service_categories',s.service_categories,
   'pending_followups',s.pending_followup_count,'overdue_followups',s.overdue_followup_count,'email_never_sent',s.email_never_sent
  ) rowj
  from public.aos_cia_audience_source_v1_1 s
  where public.aos_cia_audience_eval_node_v1(to_jsonb(s),p_filter->'root',1)
  order by s.contact_key limit lim offset offv
 )q;
 return jsonb_build_object('ok',true,'count',n,'limit',lim,'offset',offv,'registry_version',1,'source_version','1.1','items',items,'observed_at',statement_timestamp());
end;$$;

create or replace function public.aos_cia_audience_explain_v1(p_filter jsonb,p_contact_key text)
returns jsonb language plpgsql stable as $$
declare v jsonb;rowj jsonb;trace jsonb;
begin
 v:=public.aos_cia_audience_validate_v1(p_filter);
 if not coalesce((v->>'valid')::boolean,false) then return jsonb_build_object('ok',false,'validation',v);end if;
 select to_jsonb(s) into rowj from public.aos_cia_audience_source_v1_1 s where s.contact_key=p_contact_key;
 if rowj is null then return jsonb_build_object('ok',false,'error','CONTACT_NOT_FOUND','contact_key',p_contact_key);end if;
 trace:=public.aos_cia_audience_trace_node_v1(rowj,p_filter->'root',1);
 return jsonb_build_object('ok',true,'contact_key',p_contact_key,'included',(trace->>'evaluation_state')='MATCH','evaluation_state',trace->>'evaluation_state','trace',trace,'registry_version',1,'source_version','1.1','observed_at',statement_timestamp());
end;$$;

revoke all on function public.aos_cia_audience_count_v1(jsonb),function public.aos_cia_audience_preview_v1(jsonb,integer,integer),function public.aos_cia_audience_explain_v1(jsonb,text) from public,anon,authenticated;
grant execute on function public.aos_cia_audience_count_v1(jsonb),function public.aos_cia_audience_preview_v1(jsonb,integer,integer),function public.aos_cia_audience_explain_v1(jsonb,text) to service_role;
commit;
