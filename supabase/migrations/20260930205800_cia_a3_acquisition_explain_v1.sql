begin;

-- CIA A3 · make governed EXPLAIN/trace observe Acquisition facts too.
create or replace function public.aos_cia_audience_observe_leaf_v2(
  p_contact_key text,
  p_rule jsonb
)
returns jsonb
language plpgsql
stable
as $function$
declare
  v jsonb;
  sk text;
  rowj jsonb;
  observed jsonb;
begin
  select source_key into sk
  from public.aos_cia_filter_execution_map_v2
  where field_key=p_rule->>'field';

  if sk='ACQUISITION' then
    select to_jsonb(a) into rowj
    from public.aos_cia_acquisition_adapter_v1 a
    where a.contact_key=p_contact_key;
    if rowj is null then rowj:='{}'::jsonb; end if;
    observed:=public.aos_cia_audience_observed_value_v1(rowj,p_rule->>'field');
    return jsonb_build_object(
      'found',true,
      'source_key','ACQUISITION',
      'observed',observed,
      'row',rowj
    );
  end if;

  v:=public.aos_cia_audience_observe_special_fast_v2(p_contact_key,p_rule);
  if v is not null then return v; end if;
  return public.aos_cia_audience_observe_leaf_base_v2(p_contact_key,p_rule);
end;
$function$;

commit;
