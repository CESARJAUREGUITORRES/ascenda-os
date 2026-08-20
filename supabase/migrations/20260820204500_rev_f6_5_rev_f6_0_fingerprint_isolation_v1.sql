-- REV-F6.5 terminal hardening — isolate REV-F6.0 certification fingerprint from mutable CIA compatibility churn.
-- Full F6.0 contract remains visible. Only mutable aos_cia_contact_identity_v1 cardinality/freshness is excluded from the certification hash.

begin;

create or replace function public.aos_rev_f6_data_contract_fingerprint_isolated_v1(p_contract jsonb)
returns text
language plpgsql
immutable
set search_path=''
as $$
declare
  v_contract jsonb := coalesce(p_contract,'{}'::jsonb);
begin
  v_contract := v_contract
    #- array['compatibility_identity','rows']
    #- array['compatibility_identity','with_canonical_patient']
    #- array['compatibility_identity','identity_conflicts']
    #- array['freshness_sources','cia_identity_updated_at'];
  return md5(v_contract::text);
end;
$$;
comment on function public.aos_rev_f6_data_contract_fingerprint_isolated_v1(jsonb) is
'REV-F6 terminal fingerprint projection. Excludes only mutable CIA compatibility cardinality/freshness from the REV certification hash; full compatibility metrics remain visible in the contract.';
revoke all on function public.aos_rev_f6_data_contract_fingerprint_isolated_v1(jsonb) from public,anon,authenticated;
grant execute on function public.aos_rev_f6_data_contract_fingerprint_isolated_v1(jsonb) to service_role;

do $$
begin
  if to_regprocedure('public.aos_rev_f6_data_contract_v1_legacy_dynamic_fp()') is null then
    if to_regprocedure('public.aos_rev_f6_data_contract_v1()') is null then
      raise exception 'REV-F6.5 fingerprint isolation requires certified F6.0 contract';
    end if;
    alter function public.aos_rev_f6_data_contract_v1() rename to aos_rev_f6_data_contract_v1_legacy_dynamic_fp;
  end if;
end $$;

revoke all on function public.aos_rev_f6_data_contract_v1_legacy_dynamic_fp() from public,anon,authenticated;
grant execute on function public.aos_rev_f6_data_contract_v1_legacy_dynamic_fp() to service_role;

create or replace function public.aos_rev_f6_data_contract_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_full jsonb;
  v_contract jsonb;
  v_fp text;
begin
  v_full := public.aos_rev_f6_data_contract_v1_legacy_dynamic_fp();
  v_contract := v_full->'contract';
  if v_contract is null or jsonb_typeof(v_contract)<>'object' then
    raise exception 'REV-F6.5 INVALID_F6_0_CONTRACT_PAYLOAD';
  end if;
  v_fp := public.aos_rev_f6_data_contract_fingerprint_isolated_v1(v_contract);
  v_full := jsonb_set(v_full,'{contract_fingerprint}',to_jsonb(v_fp),true);
  v_full := jsonb_set(
    v_full,
    '{fingerprint_semantic}',
    to_jsonb('REVENUE_TRUTH_EXCLUDES_MUTABLE_CIA_COMPATIBILITY_CARDINALITY'::text),
    true
  );
  return v_full;
end;
$$;
comment on function public.aos_rev_f6_data_contract_v1() is
'REV-F6.0 governed wrapper. Full contract includes CIA compatibility metrics for observability, while certification fingerprint is isolated from mutable CIA/WA contact-universe cardinality and freshness.';
revoke all on function public.aos_rev_f6_data_contract_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_f6_data_contract_v1() to service_role;

select pg_notify('pgrst','reload schema');
commit;
