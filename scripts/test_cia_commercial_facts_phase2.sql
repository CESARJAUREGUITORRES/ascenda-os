-- ASCENDA OS — CIA Phase 2 Commercial Facts
-- Contract tests. Run after Phase 1 + Phase 2 migrations exist in target DB.
-- Returns PASS/FAIL rows; no DML.

with checks as (
  -- Consolidated grain = identity grain.
  select 'commercial_count_matches_identity' check_name,
         case when (select count(*) from aos_cia_commercial_facts_v1)
                    = (select count(*) from aos_cia_contact_identity_v1)
              then 'PASS' else 'FAIL' end status,
         (select count(*)::text from aos_cia_commercial_facts_v1) observed

  union all
  select 'commercial_unique_contact_key',
         case when count(*)=count(distinct contact_key) then 'PASS' else 'FAIL' end,
         count(*)::text
  from aos_cia_commercial_facts_v1

  union all
  select 'lead_unique_contact_key',
         case when count(*)=count(distinct contact_key) then 'PASS' else 'FAIL' end,
         count(*)::text
  from aos_cia_lead_facts_v1

  union all
  select 'call_unique_contact_key',
         case when count(*)=count(distinct contact_key) then 'PASS' else 'FAIL' end,
         count(*)::text
  from aos_cia_call_facts_v1

  union all
  select 'appointment_unique_contact_key',
         case when count(*)=count(distinct contact_key) then 'PASS' else 'FAIL' end,
         count(*)::text
  from aos_cia_appointment_facts_v1

  union all
  select 'sales_unique_contact_key',
         case when count(*)=count(distinct contact_key) then 'PASS' else 'FAIL' end,
         count(*)::text
  from aos_cia_sales_facts_v1

  union all
  select 'followup_unique_contact_key',
         case when count(*)=count(distinct contact_key) then 'PASS' else 'FAIL' end,
         count(*)::text
  from aos_cia_followup_facts_v1

  union all
  select 'email_full_identity_grain',
         case when (select count(*) from aos_cia_email_facts_v1)
                    = (select count(*) from aos_cia_contact_identity_v1)
              then 'PASS' else 'FAIL' end,
         (select count(*)::text from aos_cia_email_facts_v1)

  -- Domain totals reconcile with normalized source rows.
  union all
  select 'lead_rows_reconcile',
         case when (select coalesce(sum(lead_count),0) from aos_cia_lead_facts_v1)
                    = (select count(*) from aos_leads where aos_cia_normalize_contact_key_v1(numero_limpio) is not null)
              then 'PASS' else 'FAIL' end,
         (select coalesce(sum(lead_count),0)::text from aos_cia_lead_facts_v1)

  union all
  select 'call_rows_reconcile',
         case when (select coalesce(sum(call_count),0) from aos_cia_call_facts_v1)
                    = (select count(*) from aos_llamadas where aos_cia_normalize_contact_key_v1(numero_limpio) is not null)
              then 'PASS' else 'FAIL' end,
         (select coalesce(sum(call_count),0)::text from aos_cia_call_facts_v1)

  union all
  select 'appointment_rows_reconcile',
         case when (select coalesce(sum(appointment_count),0) from aos_cia_appointment_facts_v1)
                    = (select count(*) from aos_agenda_citas where aos_cia_normalize_contact_key_v1(numero_limpio) is not null)
              then 'PASS' else 'FAIL' end,
         (select coalesce(sum(appointment_count),0)::text from aos_cia_appointment_facts_v1)

  union all
  select 'sales_rows_reconcile',
         case when (select coalesce(sum(sale_count),0) from aos_cia_sales_facts_v1)
                    = (select count(*) from aos_ventas where aos_cia_normalize_contact_key_v1(numero_limpio) is not null)
              then 'PASS' else 'FAIL' end,
         (select coalesce(sum(sale_count),0)::text from aos_cia_sales_facts_v1)

  union all
  select 'followup_rows_reconcile',
         case when (select coalesce(sum(followup_count),0) from aos_cia_followup_facts_v1)
                    = (select count(*) from aos_seguimientos where aos_cia_normalize_contact_key_v1("NUMERO") is not null)
              then 'PASS' else 'FAIL' end,
         (select coalesce(sum(followup_count),0)::text from aos_cia_followup_facts_v1)

  -- Product/service partition current schema.
  union all
  select 'sales_product_service_partition',
         case when count(*) filter(where upper(btrim(tipo)) not in ('PRODUCTO','SERVICIO') or tipo is null)=0
              then 'PASS' else 'FAIL' end,
         count(*) filter(where upper(btrim(tipo)) not in ('PRODUCTO','SERVICIO') or tipo is null)::text
  from aos_ventas

  union all
  select 'sales_subcounts_do_not_exceed_total',
         case when count(*) filter(where product_count+service_count>sale_count)=0 then 'PASS' else 'FAIL' end,
         count(*) filter(where product_count+service_count>sale_count)::text
  from aos_cia_sales_facts_v1

  -- Lead current opportunity partition.
  union all
  select 'lead_opportunity_partition',
         case when count(*) filter(
                    where lead_count>0
                      and (lead_called_since_latest_entry is null or lead_unworked_since_latest_entry is null
                           or lead_called_since_latest_entry = lead_unworked_since_latest_entry)
                  )=0
              then 'PASS' else 'FAIL' end,
         count(*) filter(
                    where lead_count>0
                      and (lead_called_since_latest_entry is null or lead_unworked_since_latest_entry is null
                           or lead_called_since_latest_entry = lead_unworked_since_latest_entry)
                  )::text
  from aos_cia_commercial_facts_v1

  -- Boolean3 email semantics.
  union all
  select 'email_sent_implies_never_false',
         case when count(*) filter(where sent_count>0 and never_sent is distinct from false)=0
              then 'PASS' else 'FAIL' end,
         count(*) filter(where sent_count>0 and never_sent is distinct from false)::text
  from aos_cia_email_facts_v1

  union all
  select 'email_true_requires_safe_alias_and_zero_sends',
         case when count(*) filter(where never_sent=true and (not has_safe_email_alias or sent_count<>0))=0
              then 'PASS' else 'FAIL' end,
         count(*) filter(where never_sent=true and (not has_safe_email_alias or sent_count<>0))::text
  from aos_cia_email_facts_v1

  union all
  select 'email_unknown_has_zero_sends',
         case when count(*) filter(where never_sent is null and sent_count<>0)=0
              then 'PASS' else 'FAIL' end,
         count(*) filter(where never_sent is null and sent_count<>0)::text
  from aos_cia_email_facts_v1

  -- Conflict identities must remain non-canonical in consolidated output.
  union all
  select 'identity_conflicts_preserved',
         case when count(*) filter(where identity_status='CONFLICT' and canonical_patient_id is not null)=0
              then 'PASS' else 'FAIL' end,
         count(*) filter(where identity_status='CONFLICT' and canonical_patient_id is not null)::text
  from aos_cia_commercial_facts_v1
)
select * from checks order by check_name;
