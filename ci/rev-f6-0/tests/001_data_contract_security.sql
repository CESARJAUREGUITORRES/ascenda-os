\set ON_ERROR_STOP on

do $$
declare
  d1 jsonb; d2 jsonb; h jsonb; def text;
begin
  if to_regprocedure('public.aos_rev_f6_data_contract_v1()') is null then raise exception 'F6_0_DATA_CONTRACT_MISSING'; end if;
  if to_regprocedure('public.aos_patient_history_summary_v1(text,text)') is null then raise exception 'F6_0_HISTORY_SUMMARY_MISSING'; end if;

  if has_function_privilege('anon','public.aos_paciente_360(text)','EXECUTE') then raise exception 'F6_0_LEGACY_ANON_OPEN'; end if;
  if has_function_privilege('authenticated','public.aos_paciente_360(text)','EXECUTE') then raise exception 'F6_0_LEGACY_AUTH_OPEN'; end if;
  if not has_function_privilege('service_role','public.aos_paciente_360(text)','EXECUTE') then raise exception 'F6_0_LEGACY_SERVICE_CLOSED'; end if;

  if has_function_privilege('anon','public.aos_rev_f6_data_contract_v1()','EXECUTE') then raise exception 'F6_0_CONTRACT_ANON_OPEN'; end if;
  if has_function_privilege('authenticated','public.aos_rev_f6_data_contract_v1()','EXECUTE') then raise exception 'F6_0_CONTRACT_AUTH_OPEN'; end if;
  if not has_function_privilege('service_role','public.aos_rev_f6_data_contract_v1()','EXECUTE') then raise exception 'F6_0_CONTRACT_SERVICE_CLOSED'; end if;

  if not has_function_privilege('anon','public.aos_patient_history_summary_v1(text,text)','EXECUTE') then raise exception 'F6_0_SUMMARY_ANON_RPC_MISSING'; end if;
  if not has_function_privilege('authenticated','public.aos_patient_history_summary_v1(text,text)','EXECUTE') then raise exception 'F6_0_SUMMARY_AUTH_RPC_MISSING'; end if;

  select pg_get_functiondef('public.aos_patient_history_summary_v1(text,text)'::regprocedure) into def;
  if def ilike '%aos_notas_pacientes%' or def ilike '%aos_documentos_pacientes%' then raise exception 'F6_0_SUMMARY_PHI_SOURCE_LEAK'; end if;
  if def ilike '%observacion%' then raise exception 'F6_0_SUMMARY_CALL_OBSERVATION_LEAK'; end if;
  if def not ilike '%aos_app_actor_v3%' then raise exception 'F6_0_SUMMARY_AUTH_V3_MISSING'; end if;

  begin
    perform public.aos_patient_history_summary_v1('invalid','987654321');
    raise exception 'F6_0_INVALID_TOKEN_ACCEPTED';
  exception when others then
    if sqlerrm='F6_0_INVALID_TOKEN_ACCEPTED' then raise; end if;
  end;

  h := public.aos_patient_history_summary_v1('valid-f6-token-000000000000000000000000','987654321');
  if h->>'ok' <> 'true' or h->>'readOnly' <> 'true' then raise exception 'F6_0_SUMMARY_VALID_PATH_FAIL'; end if;
  if h ? 'paciente' or h ? 'notas' or h ? 'documentos' then raise exception 'F6_0_SUMMARY_PHI_KEY_LEAK'; end if;
  if jsonb_array_length(h->'compras') <> 1 or jsonb_array_length(h->'citas') <> 1 or jsonb_array_length(h->'llamadas') <> 1 then raise exception 'F6_0_SUMMARY_COMPATIBILITY_FAIL'; end if;

  d1 := public.aos_rev_f6_data_contract_v1();
  d2 := public.aos_rev_f6_data_contract_v1();
  if d1->>'contract_fingerprint' is null or d1->>'contract_fingerprint' <> d2->>'contract_fingerprint' then raise exception 'F6_0_CONTRACT_NONDETERMINISTIC'; end if;
  if d1#>>'{contract,contract_id}' <> 'REV-F6.0_DATA_CONTRACT_V1' then raise exception 'F6_0_CONTRACT_ID_FAIL'; end if;
  if d1#>>'{contract,truth_layers,product}' not like 'F3%' then raise exception 'F6_0_F3_TRUTH_FAIL'; end if;
  if d1#>>'{contract,truth_layers,financial}' not like 'F4%' then raise exception 'F6_0_F4_TRUTH_FAIL'; end if;
  if d1#>>'{contract,truth_layers,identity_bridge_v2}' <> 'CONTRACT_FROZEN_NOT_MATERIALIZED_AT_F6_0' then raise exception 'F6_0_BRIDGE_STATUS_FAIL'; end if;
  if (d1#>>'{contract,historical_periods,absence_means_zero}')::boolean then raise exception 'F6_0_ABSENCE_ZERO_FAIL'; end if;
  if (d1#>>'{contract,historical_periods,yoy_2024_2026_supported}')::boolean then raise exception 'F6_0_UNSUPPORTED_YOY_FAIL'; end if;
  if (d1#>>'{contract,semantic_guards,ultimo_presupuesto_is_sale_payment_or_debt}')::boolean then raise exception 'F6_0_BUDGET_FINANCE_INFERENCE_FAIL'; end if;
  if (d1#>>'{contract,semantic_guards,adelanto_is_automatic_debt}')::boolean then raise exception 'F6_0_ADELANTO_DEBT_INFERENCE_FAIL'; end if;
  if d1#>'{contract,metric_trust_contract,required_fields}' <> '["coverage", "confidence", "freshness", "sample_size"]'::jsonb then raise exception 'F6_0_METRIC_TRUST_FIELDS_FAIL'; end if;
end
$$;

select 'PASS' as rev_f6_0_data_contract_security;
