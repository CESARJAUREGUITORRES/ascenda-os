-- ASCENDA OS — CIA Phase 4 safe negative set semantics
begin;
create or replace function public.aos_cia_audience_rule_match_v1(p_row jsonb,p_rule jsonb)
returns boolean language plpgsql stable as $$
declare
 f text:=p_rule->>'field'; op text:=p_rule->>'operator'; dtype text;
 observed jsonb; v jsonb; ot text; onum numeric; vnum numeric; a numeric; b numeric;
 od timestamptz; d1 timestamptz; d2 timestamptz; unresolved integer:=0;
begin
 dtype:=public.aos_cia_audience_effective_field_type_v1(f);
 observed:=public.aos_cia_audience_observed_value_v1(p_row,f);
 v:=p_rule->'value';
 if op='is_unknown' then return observed is null or observed='null'::jsonb; end if;
 if op='is_true' then return observed='true'::jsonb; end if;
 if op='is_false' then return observed='false'::jsonb; end if;
 if op='exists' then return observed is not null and observed<>'null'::jsonb and not(jsonb_typeof(observed)='string' and btrim(observed#>>'{}')=''); end if;
 if op='not_exists' then return not public.aos_cia_audience_rule_match_v1(p_row,jsonb_build_object('field',f,'operator','exists')); end if;
 if observed is null or observed='null'::jsonb then return false; end if;
 if dtype='set' then
   if jsonb_typeof(observed)<>'array' then return false; end if;
   if op='contains' then return exists(select 1 from jsonb_array_elements_text(observed)x where upper(btrim(x))=upper(btrim(v#>>'{}'))); end if;
   if op='contains_any' then return exists(select 1 from jsonb_array_elements_text(observed)o join jsonb_array_elements_text(v)q on upper(btrim(o))=upper(btrim(q))); end if;
   if op='contains_all' then return not exists(select 1 from jsonb_array_elements_text(v)q where not exists(select 1 from jsonb_array_elements_text(observed)o where upper(btrim(o))=upper(btrim(q)))); end if;
   if op='never_contains' then
     unresolved:=case
       when f in ('sales.products','sales.product_categories') then coalesce((p_row->>'product_unresolved_count')::integer,0)
       when f='sales.service_categories' then coalesce((p_row->>'service_category_unresolved_count')::integer,0)
       when f='sales.services' then coalesce((p_row->>'service_unresolved_count')::integer,0)
       else 0 end;
     if unresolved>0 then return false; end if;
     return not exists(select 1 from jsonb_array_elements_text(observed)x where upper(btrim(x))=upper(btrim(v#>>'{}')));
   end if;
   if op='not_contains' then return not exists(select 1 from jsonb_array_elements_text(observed)x where upper(btrim(x))=upper(btrim(v#>>'{}'))); end if;
   return false;
 end if;
 if dtype in ('integer','numeric') then
   onum:=(observed#>>'{}')::numeric;
   if op='between' then a:=(v->>0)::numeric;b:=(v->>1)::numeric;return onum between least(a,b) and greatest(a,b);end if;
   vnum:=(v#>>'{}')::numeric;
   return case op when 'eq' then onum=vnum when 'neq' then onum<>vnum when 'gt' then onum>vnum when 'gte' then onum>=vnum when 'lt' then onum<vnum when 'lte' then onum<=vnum else false end;
 end if;
 if dtype in ('date','timestamp') then
   od:=(observed#>>'{}')::timestamptz;
   if op='within_last_days' then return od>=((now() at time zone 'America/Lima')::date-((v#>>'{}')::integer))::timestamptz;end if;
   if op='older_than_days' then return od<((now() at time zone 'America/Lima')::date-((v#>>'{}')::integer))::timestamptz;end if;
   if op='between' then d1:=(v->>0)::timestamptz;d2:=(v->>1)::timestamptz;return od between least(d1,d2) and greatest(d1,d2);end if;
   d1:=(v#>>'{}')::timestamptz;
   return case op when 'before' then od<d1 when 'after' then od>d1 else false end;
 end if;
 ot:=upper(btrim(observed#>>'{}'));
 if op='eq' then return ot=upper(btrim(v#>>'{}'));end if;
 if op='neq' then return ot<>upper(btrim(v#>>'{}'));end if;
 if op='contains' then return ot like '%'||upper(btrim(v#>>'{}'))||'%';end if;
 if op='in' then return exists(select 1 from jsonb_array_elements_text(v)x where ot=upper(btrim(x)));end if;
 if op='not_in' then return not exists(select 1 from jsonb_array_elements_text(v)x where ot=upper(btrim(x)));end if;
 return false;
exception when others then return false;
end;
$$;
revoke all on function public.aos_cia_audience_rule_match_v1(jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.aos_cia_audience_rule_match_v1(jsonb,jsonb) to service_role;
commit;
