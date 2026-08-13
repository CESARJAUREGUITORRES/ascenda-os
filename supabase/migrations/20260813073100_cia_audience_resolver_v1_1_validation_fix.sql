-- ASCENDA OS — CIA Phase 4 Audience Resolver V1.1 validation/performance fix
begin;

-- Static type mapping prevents per-contact registry lookups during evaluation.
-- Contract tests verify parity with aos_audience_filter_registry.
create or replace function public.aos_cia_audience_field_type_v1(p_field text)
returns text
language sql
immutable
parallel safe
as $$
select case p_field
  when 'contact.identity_status' then 'enum'
  when 'contact.identity_conflict' then 'boolean'
  when 'contact.email_valid' then 'boolean3'
  when 'contact.exists_as_patient' then 'boolean'
  when 'contact.exists_as_lead' then 'boolean'
  when 'crm.patient_state' then 'text'
  when 'crm.base_label' then 'text'
  when 'crm.base_campaign' then 'text'
  when 'crm.branch' then 'text'
  when 'crm.department' then 'text'
  when 'crm.city' then 'text'
  when 'crm.district' then 'text'
  when 'crm.sex' then 'text'
  when 'crm.age_years' then 'integer'
  when 'crm.age_band' then 'enum'
  when 'lead.count' then 'integer'
  when 'lead.days_since_last' then 'integer'
  when 'lead.latest_interest' then 'text'
  when 'lead.latest_interest_type' then 'enum'
  when 'lead.interests' then 'set'
  when 'lead.ads' then 'set'
  when 'lead.called_since_latest_entry' then 'boolean3'
  when 'lead.unworked_since_latest_entry' then 'boolean3'
  when 'calls.total' then 'integer'
  when 'calls.never_called' then 'boolean'
  when 'calls.days_since_last' then 'integer'
  when 'calls.latest_status' then 'text'
  when 'calls.latest_substatus' then 'text'
  when 'calls.ever_statuses' then 'set'
  when 'calls.called_today' then 'boolean'
  when 'calls.effective_contact_count' then 'integer'
  when 'appointments.total' then 'integer'
  when 'appointments.never_had' then 'boolean'
  when 'appointments.last_at' then 'date'
  when 'appointments.last_status' then 'text'
  when 'appointments.next_at' then 'date'
  when 'appointments.has_future' then 'boolean'
  when 'appointments.no_show_count' then 'integer'
  when 'appointments.ever_no_show' then 'boolean'
  when 'appointments.attended_count' then 'integer'
  when 'appointments.statuses' then 'set'
  when 'sales.total' then 'integer'
  when 'sales.never_bought' then 'boolean'
  when 'sales.revenue_lifetime' then 'numeric'
  when 'sales.days_since_last' then 'integer'
  when 'sales.product_count' then 'integer'
  when 'sales.service_count' then 'integer'
  when 'sales.products' then 'set'
  when 'sales.services' then 'set'
  when 'sales.latest_item_type' then 'enum'
  when 'sales.payment_states' then 'set'
  when 'sales.payment_methods' then 'set'
  when 'followups.pending_count' then 'integer'
  when 'followups.overdue_count' then 'integer'
  when 'followups.next_at' then 'date'
  when 'followups.treatments' then 'set'
  when 'email.sent_count' then 'integer'
  when 'email.never_sent' then 'boolean3'
  when 'email.days_since_last' then 'integer'
  when 'email.opened_count' then 'integer'
  when 'email.clicked_count' then 'integer'
  when 'email.bounced_count' then 'integer'
  when 'segment.value_tier' then 'enum'
  when 'segment.value_score' then 'integer'
  when 'segment.lifecycle' then 'enum'
  when 'segment.engagement' then 'enum'
  when 'segment.traits' then 'set'
  else null
end;
$$;

-- Group depth counts groups only. Leaves within the second group level remain valid.
create or replace function public.aos_cia_audience_validate_node_v1(p_node jsonb, p_depth integer default 1, p_path text default '$.root')
returns jsonb
language plpgsql
stable
as $$
declare
  errors jsonb := '[]'::jsonb;
  r jsonb; idx integer := 0;
  f text; op text; dtype text; ops text[]; enums text[]; v jsonb;
  next_depth integer;
begin
  if p_node ? 'field' then
    f := p_node->>'field'; op := p_node->>'operator'; v := p_node->'value';
    select data_type, allowed_operators, enum_values into dtype, ops, enums
    from public.aos_audience_filter_registry where field_key=f and active=true;
    if dtype is null then
      return jsonb_build_array(jsonb_build_object('code','FIELD_NOT_ALLOWED','path',p_path,'field',f));
    end if;
    if op is null or not (op = any(ops)) then
      return jsonb_build_array(jsonb_build_object('code','OPERATOR_NOT_ALLOWED','path',p_path,'field',f,'operator',op));
    end if;
    if op in ('is_true','is_false','is_unknown','exists','not_exists') then return errors; end if;
    if not (p_node ? 'value') or v is null or v='null'::jsonb then
      return jsonb_build_array(jsonb_build_object('code','VALUE_REQUIRED','path',p_path,'field',f));
    end if;
    if op in ('in','not_in','contains_any','contains_all','between') and jsonb_typeof(v) <> 'array' then
      return jsonb_build_array(jsonb_build_object('code','ARRAY_VALUE_REQUIRED','path',p_path,'field',f));
    end if;
    if op='between' and jsonb_array_length(v) <> 2 then
      return jsonb_build_array(jsonb_build_object('code','BETWEEN_REQUIRES_TWO_VALUES','path',p_path,'field',f));
    end if;
    if op in ('in','not_in','contains_any','contains_all') and jsonb_array_length(v)=0 then
      return jsonb_build_array(jsonb_build_object('code','NONEMPTY_ARRAY_REQUIRED','path',p_path,'field',f));
    end if;
    if dtype in ('integer','numeric') then
      if op='between' then
        if exists (select 1 from jsonb_array_elements_text(v) x where x !~ '^-?\d+(\.\d+)?$') then
          errors := errors || jsonb_build_array(jsonb_build_object('code','NUMERIC_VALUE_REQUIRED','path',p_path,'field',f));
        end if;
      elsif (v#>>'{}') !~ '^-?\d+(\.\d+)?$' then
        errors := errors || jsonb_build_array(jsonb_build_object('code','NUMERIC_VALUE_REQUIRED','path',p_path,'field',f));
      end if;
    end if;
    if op in ('within_last_days','older_than_days') and (v#>>'{}') !~ '^\d+$' then
      errors := errors || jsonb_build_array(jsonb_build_object('code','INTEGER_DAYS_REQUIRED','path',p_path,'field',f));
    end if;
    if dtype in ('date','timestamp') and op in ('before','after') and (v#>>'{}') !~ '^\d{4}-\d{2}-\d{2}' then
      errors := errors || jsonb_build_array(jsonb_build_object('code','ISO_DATE_REQUIRED','path',p_path,'field',f));
    end if;
    if dtype in ('date','timestamp') and op='between' and exists (
      select 1 from jsonb_array_elements_text(v) x where x !~ '^\d{4}-\d{2}-\d{2}'
    ) then
      errors := errors || jsonb_build_array(jsonb_build_object('code','ISO_DATE_REQUIRED','path',p_path,'field',f));
    end if;
    if enums is not null and op in ('eq','neq') and not (upper(v#>>'{}') = any(enums)) then
      errors := errors || jsonb_build_array(jsonb_build_object('code','ENUM_VALUE_NOT_ALLOWED','path',p_path,'field',f,'value',v));
    end if;
    if enums is not null and op in ('in','not_in') and exists (
      select 1 from jsonb_array_elements_text(v) x where not (upper(x) = any(enums))
    ) then
      errors := errors || jsonb_build_array(jsonb_build_object('code','ENUM_VALUE_NOT_ALLOWED','path',p_path,'field',f,'value',v));
    end if;
    return errors;
  end if;

  if p_depth > 2 then
    return jsonb_build_array(jsonb_build_object('code','MAX_DEPTH_EXCEEDED','path',p_path,'detail','Maximum group depth is 2'));
  end if;
  if upper(coalesce(p_node->>'op','')) not in ('AND','OR') then
    errors := errors || jsonb_build_array(jsonb_build_object('code','GROUP_OPERATOR_INVALID','path',p_path));
  end if;
  if jsonb_typeof(p_node->'rules') <> 'array' or jsonb_array_length(coalesce(p_node->'rules','[]'::jsonb))=0 then
    return errors || jsonb_build_array(jsonb_build_object('code','GROUP_RULES_REQUIRED','path',p_path));
  end if;
  for r in select value from jsonb_array_elements(p_node->'rules') loop
    next_depth := case when r ? 'field' then p_depth else p_depth+1 end;
    errors := errors || public.aos_cia_audience_validate_node_v1(r,next_depth,p_path||'.rules['||idx||']');
    idx := idx + 1;
  end loop;
  return errors;
end;
$$;

create or replace function public.aos_cia_audience_eval_node_v1(p_row jsonb, p_node jsonb, p_depth integer default 1)
returns boolean
language plpgsql
stable
as $$
declare r jsonb; op text; next_depth integer;
begin
  if p_node ? 'field' then return public.aos_cia_audience_rule_match_v1(p_row,p_node); end if;
  if p_depth>2 then return false; end if;
  op := upper(coalesce(p_node->>'op',''));
  if op='AND' then
    for r in select value from jsonb_array_elements(p_node->'rules') loop
      next_depth := case when r ? 'field' then p_depth else p_depth+1 end;
      if not public.aos_cia_audience_eval_node_v1(p_row,r,next_depth) then return false; end if;
    end loop;
    return true;
  elsif op='OR' then
    for r in select value from jsonb_array_elements(p_node->'rules') loop
      next_depth := case when r ? 'field' then p_depth else p_depth+1 end;
      if public.aos_cia_audience_eval_node_v1(p_row,r,next_depth) then return true; end if;
    end loop;
    return false;
  end if;
  return false;
end;
$$;

revoke all on function public.aos_cia_audience_field_type_v1(text) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_validate_node_v1(jsonb,integer,text) from public, anon, authenticated;
revoke all on function public.aos_cia_audience_eval_node_v1(jsonb,jsonb,integer) from public, anon, authenticated;
grant execute on function public.aos_cia_audience_field_type_v1(text) to service_role;
grant execute on function public.aos_cia_audience_validate_node_v1(jsonb,integer,text) to service_role;
grant execute on function public.aos_cia_audience_eval_node_v1(jsonb,jsonb,integer) to service_role;

commit;
