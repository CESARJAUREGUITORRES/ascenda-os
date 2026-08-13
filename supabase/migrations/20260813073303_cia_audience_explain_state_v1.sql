-- ASCENDA OS — CIA Phase 4 explain trace with MATCH/MISS/UNKNOWN
begin;
create or replace function public.aos_cia_audience_trace_node_v1(p_row jsonb,p_node jsonb,p_depth integer default 1)
returns jsonb language plpgsql stable as $$
declare
 r jsonb; children jsonb:='[]'::jsonb; child jsonb; f text; op text; observed jsonb;
 matched boolean; state text; reason text; unresolved integer:=0; present boolean:=false;
 any_match boolean:=false; any_unknown boolean:=false; any_miss boolean:=false;
begin
 if p_node ? 'field' then
   f:=p_node->>'field'; op:=p_node->>'operator'; observed:=public.aos_cia_audience_observed_value_v1(p_row,f);
   matched:=public.aos_cia_audience_rule_match_v1(p_row,p_node);
   if op='never_contains' and jsonb_typeof(observed)='array' then
     present:=exists(select 1 from jsonb_array_elements_text(observed)x where upper(btrim(x))=upper(btrim(p_node->>'value')));
     unresolved:=case
       when f in ('sales.products','sales.product_categories') then coalesce((p_row->>'product_unresolved_count')::integer,0)
       when f='sales.service_categories' then coalesce((p_row->>'service_category_unresolved_count')::integer,0)
       when f='sales.services' then coalesce((p_row->>'service_unresolved_count')::integer,0)
       else 0 end;
     state:=case when present then 'MISS' when unresolved>0 then 'UNKNOWN' when matched then 'MATCH' else 'MISS' end;
   elsif (observed is null or observed='null'::jsonb) and op not in ('is_unknown','exists','not_exists') then
     state:='UNKNOWN';
   else state:=case when matched then 'MATCH' else 'MISS' end;
   end if;
   reason:=state||'_'||regexp_replace(upper(f||'_'||op),'[^A-Z0-9]+','_','g');
   return jsonb_build_object('kind','rule','field',f,'operator',op,'expected',p_node->'value','observed',observed,'matched',state='MATCH','evaluation_state',state,'reason_code',reason,
     'unresolved_evidence',case when op='never_contains' then unresolved else null end);
 end if;

 op:=upper(coalesce(p_node->>'op',''));
 for r in select value from jsonb_array_elements(p_node->'rules') loop
   child:=public.aos_cia_audience_trace_node_v1(p_row,r,case when r ? 'field' then p_depth else p_depth+1 end);
   children:=children||jsonb_build_array(child);
   any_match:=any_match or coalesce(child->>'evaluation_state','')='MATCH';
   any_unknown:=any_unknown or coalesce(child->>'evaluation_state','')='UNKNOWN';
   any_miss:=any_miss or coalesce(child->>'evaluation_state','')='MISS';
 end loop;
 if op='AND' then state:=case when any_miss then 'MISS' when any_unknown then 'UNKNOWN' else 'MATCH' end;
 elsif op='OR' then state:=case when any_match then 'MATCH' when any_unknown then 'UNKNOWN' else 'MISS' end;
 else state:='MISS'; end if;
 return jsonb_build_object('kind','group','op',op,'matched',state='MATCH','evaluation_state',state,'children',children);
end;
$$;
revoke all on function public.aos_cia_audience_trace_node_v1(jsonb,jsonb,integer) from public,anon,authenticated;
grant execute on function public.aos_cia_audience_trace_node_v1(jsonb,jsonb,integer) to service_role;
commit;
