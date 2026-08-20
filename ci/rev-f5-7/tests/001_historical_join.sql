\set ON_ERROR_STOP on

-- REV-F5.7 regression contract. Run after migrations and builder execution.
do $$
begin
  if to_regclass('public.aos_f5_historical_join_v1') is null then raise exception 'F5_7_BRIDGE_TABLE_MISSING'; end if;
  if to_regprocedure('public.aos_f5_build_historical_join_v1()') is null then raise exception 'F5_7_BUILDER_MISSING'; end if;
  if to_regprocedure('public.aos_f5_historical_join_summary_v1()') is null then raise exception 'F5_7_SUMMARY_MISSING'; end if;

  if (select count(*) from public.aos_f5_historical_join_v1) <> (select count(*) from public.aos_ventas) then
    raise exception 'F5_7_SALE_COVERAGE_MISMATCH';
  end if;

  if exists(
    select 1 from public.aos_f5_historical_join_v1
    where patient_link_status='MATCH'
      and (canonical_patient_id is null or patient_link_method<>'DNI_NAME_EXACT')
  ) then raise exception 'F5_7_UNSAFE_MATCH'; end if;

  if exists(
    select 1 from public.aos_f5_historical_join_v1
    where patient_link_method='PHONE_NAME_SUPPORT_ONLY' and patient_link_status='MATCH'
  ) then raise exception 'F5_7_PHONE_ONLY_MATCH'; end if;

  if exists(
    select 1 from public.aos_f5_historical_join_v1
    where patient_link_status<>'MATCH' and canonical_patient_id is not null
  ) then raise exception 'F5_7_REVIEW_TARGET_LEAK'; end if;

  if exists(
    select 1 from public.aos_f5_historical_join_v1
    where product_resolution_status='RESOLVED' and product_key is null
  ) then raise exception 'F5_7_RESOLVED_PRODUCT_WITHOUT_KEY'; end if;

  if exists(
    select 1 from public.aos_f5_historical_join_v1
    where cartera_link_status='F4_LINKED' and cartera_row_count=0
  ) then raise exception 'F5_7_F4_LINK_WITHOUT_EVIDENCE'; end if;

  if exists(
    select 1 from public.aos_f5_historical_join_v1
    where cartera_link_status='NO_F4_RECONCILIATION_EVIDENCE' and cartera_row_count<>0
  ) then raise exception 'F5_7_F4_UNLINKED_WITH_ROWS'; end if;
end
$$;

-- Browser roles must never execute/read this bridge directly.
do $$
begin
  if has_table_privilege('anon','public.aos_f5_historical_join_v1','SELECT') then raise exception 'F5_7_ANON_TABLE_LEAK'; end if;
  if has_table_privilege('authenticated','public.aos_f5_historical_join_v1','SELECT') then raise exception 'F5_7_AUTH_TABLE_LEAK'; end if;
  if has_function_privilege('anon','public.aos_f5_build_historical_join_v1()','EXECUTE') then raise exception 'F5_7_ANON_EXEC_LEAK'; end if;
  if has_function_privilege('authenticated','public.aos_f5_build_historical_join_v1()','EXECUTE') then raise exception 'F5_7_AUTH_EXEC_LEAK'; end if;
end
$$;
