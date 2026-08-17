# ASCENDA OS — Migration History Parity Audit

**Mode:** read-only / offline content comparison against frozen production ledger hashes
**Remote scope:** versions `>= 20260815000000`
**Remote rows:** 58
**Local rows scanned (all history):** 87
**Local rows in recent scope:** 23

## Summary

- EXACT_CONTENT: **0**
- CONTENT_EXACT_VERSION_DRIFT: **6**
- CONTENT_EXACT_NAME_AND_VERSION_DRIFT: **0**
- EXACT_VERSION_CONTENT_MISMATCH: **0**
- NAME_MATCH_CONTENT_MISMATCH: **23**
- VERSION_NAME_CONFLICT: **0**
- AMBIGUOUS_CONTENT_MATCH: **0**
- UNSUPPORTED_STATEMENT_COUNT: **0**
- REMOTE_ONLY: **29**
- LOCAL_ONLY: **22**
- DUPLICATE_LOCAL_VERSION: **2**

Only `CONTENT_EXACT_VERSION_DRIFT` is an automatic candidate for filename/version reconciliation after owner/drift checks. `CONTENT_EXACT_NAME_AND_VERSION_DRIFT` proves identical SQL but also a name change, so it remains manual. Any content mismatch or ambiguity is blocked from automatic repair.

## CONTENT_EXACT_VERSION_DRIFT

| Migration | Production version | Repository version | Local path | Statement MD5 |
|---|---:|---:|---|---|
| `cia_phase16_email_governed_schema_v1` | `20260815215930` | `20260814200500` | `supabase/migrations/20260814200500_cia_phase16_email_governed_schema_v1.sql` | `3c3704f0a291920aea185cf9effe49f8` |
| `cia_phase16_email_contracts_v1` | `20260815220040` | `20260814200600` | `supabase/migrations/20260814200600_cia_phase16_email_contracts_v1.sql` | `469408332e983f87baa3231799aefac2` |
| `cia_phase16_email_render_context_hardening` | `20260815220329` | `20260814220100` | `supabase/migrations/20260814220100_cia_phase16_email_render_context_hardening.sql` | `5b5c310d89fdc8813802b8d021699b55` |
| `cia_phase16_verify_app_session_v1` | `20260815220344` | `20260814220300` | `supabase/migrations/20260814220300_cia_phase16_verify_app_session_v1.sql` | `6b0966b5446a817dbeadb2b951901a85` |
| `cia_phase16_legacy_email_acl_hardening` | `20260815220458` | `20260814220200` | `supabase/migrations/20260814220200_cia_phase16_legacy_email_acl_hardening.sql` | `bbba3422f613fea24700e61611b62833` |
| `cia_phase16_resend_outcome_coverage_v3` | `20260815221343` | `20260815221000` | `supabase/migrations/20260815221000_cia_phase16_resend_outcome_coverage_v3.sql` | `d15577b78c30f16a0ad154209019b829` |

## CONTENT_EXACT_NAME_AND_VERSION_DRIFT

| Production migration | Production version | Repository migration | Repository version | Local path |
|---|---:|---|---:|---|
| — | — | — | — | — |

## EXACT_VERSION_CONTENT_MISMATCH

| Version | Migration | Local path | Production MD5 | Local MD5 |
|---:|---|---|---|---|
| — | — | — | — | — |

## NAME_MATCH_CONTENT_MISMATCH

| Migration | Production version | Repository version | Local path | Local MD5 |
|---|---:|---:|---|---|
| `f4_revenue_operations_core_v1` | `20260815095037` | `20260814223000` | `supabase/migrations/20260814223000_f4_revenue_operations_core_v1.sql` | `cf29a2a6c3692f99843c65c09dd4b914` |
| `f4_cartera_candidates_v2` | `20260815095105` | `20260814223100` | `supabase/migrations/20260814223100_f4_cartera_candidates_v2.sql` | `867dcd901ca9791182e9554716d703ab` |
| `marketing_attribution_v2_exact_candidate_identity` | `20260815134059` | `20260815134500` | `supabase/migrations/20260815134500_marketing_attribution_v2_exact_candidate_identity.sql` | `a48e23040a82670c78c588450d907e8a` |
| `call_center_followups_v2_contract` | `20260815135145` | `20260815135500` | `supabase/migrations/20260815135500_call_center_followups_v2_contract.sql` | `5aa26f4609fbc5eaab46f8d94b08a498` |
| `fix_secure_write_v2_jsonb_match_count` | `20260815152341` | `20260814201500` | `supabase/migrations/20260814201500_fix_secure_write_v2_jsonb_match_count.sql` | `267bebb91b63d23a21498935824827d3` |
| `wa1_secure_gateway_v1` | `20260815163307` | `20260815160000` | `supabase/migrations/20260815160000_wa1_secure_gateway_v1.sql` | `67c53c9c891441d45accb7a7d523b592` |
| `f4_revenue_production_canary_p0` | `20260815165537` | `20260815162000` | `supabase/migrations/20260815162000_f4_revenue_production_canary_p0.sql` | `3cbbde22adc85ee72ee55281af6a4228` |
| `wa2_conversation_live_inbox_v1` | `20260815183105` | `20260815175500` | `supabase/migrations/20260815175500_wa2_conversation_live_inbox_v1.sql` | `3efe079aa54e6061a181d8f93db22dcb` |
| `f4_cartera_gateway_v2_auth_chain_hotfix` | `20260815192012` | `20260815191500` | `supabase/migrations/20260815191500_f4_cartera_gateway_v2_auth_chain_hotfix.sql` | `1906b0ee0d2d8c841c3781888957783f` |
| `wa3_boxes_routing_handoff_v1` | `20260815193102` | `20260815190500` | `supabase/migrations/20260815190500_wa3_boxes_routing_handoff_v1.sql` | `896e35974266437ea0cf6c6964c5f425` |
| `wa4_ai_sales_router_v1` | `20260815211255` | `20260815203000` | `supabase/migrations/20260815203000_wa4_ai_sales_router_v1.sql` | `be9a6864d4fc195bca56de21c2e2f303` |
| `groq_gpt_oss_model_refresh` | `20260815211320` | `20260815204500` | `supabase/migrations/20260815204500_groq_gpt_oss_model_refresh.sql` | `c413fbd056268f2964b77b327dcc6477` |
| `cia_phase16_email_delivery_contracts_v2` | `20260815220259` | `20260814220000` | `supabase/migrations/20260814220000_cia_phase16_email_delivery_contracts_v2.sql` | `1f0fdb1732534f803df75c36fa9c375b` |
| `f5_historical_patient_identity_private_ingest_v1` | `20260815232737` | `20260815233000` | `supabase/migrations/20260815233000_f5_historical_patient_identity_private_ingest_v1.sql` | `18afe263eb99abeba78410df743e28fe` |
| `integration_secret_boundary_v1` | `20260815234408` | `20260815205000` | `supabase/migrations/20260815205000_integration_secret_boundary_v1.sql` | `99da2c26e29d771e4cea906fa9359d13` |
| `cia_phase17_multichannel_contracts_v1` | `20260816031658` | `20260815215000` | `supabase/migrations/20260815215000_cia_phase17_multichannel_contracts_v1.sql` | `f0ce5b328a5ece4f6fee3f9cdbc43a4c` |
| `f17_legacy_whatsapp_acl_p0` | `20260816093639` | `20260816054900` | `supabase/migrations/20260816054900_f17_legacy_whatsapp_acl_p0.sql` | `b5686405d902f934914f39392b72f253` |
| `sentinel_f8_incident_engine` | `20260817000618` | `20260816233500` | `supabase/migrations/20260816233500_sentinel_f8_incident_engine.sql` | `01016e822e0926ab81e6222e24f9c79a` |
| `sentinel_f9_alert_outbox` | `20260817013916` | `20260817010000` | `supabase/migrations/20260817010000_sentinel_f9_alert_outbox.sql` | `d3e3917c3b8aba652639c0d2997e3be6` |
| `sentinel_f9_digest_incident_fk_index` | `20260817014618` | `20260817015500` | `supabase/migrations/20260817015500_sentinel_f9_digest_incident_fk_index.sql` | `19744774104e7abfb0599e358b3c74fe` |
| `f17_legacy_whatsapp_acl_final` | `20260817170316` | `20260817170500` | `supabase/migrations/20260817170500_f17_legacy_whatsapp_acl_final.sql` | `a6cb940869af1da86a0ed66e14dae4b1` |
| `sentinel_f9_inapp_owner_alerts` | `20260817174233` | `20260817043000` | `supabase/migrations/20260817043000_sentinel_f9_inapp_owner_alerts.sql` | `56a3b67a2ad987a9225e8ed9052ba59a` |
| `cia_phase17_whatsapp_adapter_contracts_v1` | `20260817183507` | `20260815223000` | `supabase/migrations/20260815223000_cia_phase17_whatsapp_adapter_contracts_v1.sql` | `8cbada019e91caae8f6bc856a288cef6` |

## VERSION_NAME_CONFLICT

| Version | Production name | Local name | Local path | Local MD5 |
|---:|---|---|---|---|
| — | — | — | — | — |

## AMBIGUOUS_CONTENT_MATCH

| Production version | Migration | Matching local candidates |
|---:|---|---:|
| — | — | — |

## REMOTE_ONLY

| Production version | Production name |
|---:|---|
| `20260815161920` | `fix_admin_home_lima_business_date` |
| `20260815211021` | `f4_revenue_operations_final_cutover_20260815` |
| `20260815215652` | `f5_historical_patient_identity_foundation_v1_20260815` |
| `20260815224906` | `cia_phase16_live_canary_evidence_temp` |
| `20260816003421` | `f5_historical_patient_identity_compact_preview_v1_20260815` |
| `20260816003440` | `f5_cluster_fieldwise_enrichment_v1_20260815` |
| `20260816003807` | `f5_encrypted_transport_v1_20260815` |
| `20260816004943` | `f5_ciphertext_transport_insert_window_20260815` |
| `20260816005038` | `f5_ciphertext_transport_insert_window_close_20260815` |
| `20260816005058` | `f5_ciphertext_process_window_open_20260815` |
| `20260816005121` | `f5_ciphertext_process_window_close_20260815` |
| `20260816005222` | `f5_safe_preview_metrics_v1_20260815` |
| `20260816005245` | `f5_safe_preview_metrics_close_20260815` |
| `20260816005349` | `f5_encrypted_transport_cleanup_20260815` |
| `20260816013341` | `f5_ephemeral_cipher_recovery_staging_20260815` |
| `20260816014723` | `f5_ephemeral_cipher_recovery_rpc_20260815` |
| `20260816020011` | `hotfix_auth_v3_resend_private_vault` |
| `20260816020627` | `f5_cleanup_ephemeral_transport_20260815` |
| `20260816022053` | `f5_review_apply_v1_20260816` |
| `20260817161248` | `f5_private_recovery_transport_bridge` |
| `20260817171043` | `cia_phase17_whatsapp_canary_control_v1` |
| `20260817171102` | `cia_phase17_whatsapp_mark_dispatch_v1` |
| `20260817171119` | `cia_phase17_whatsapp_provider_event_v1` |
| `20260817171141` | `cia_phase17_whatsapp_inbound_v1` |
| `20260817173258` | `f5_ephemeral_chat_ingest_bridge_20260817` |
| `20260817174205` | `f5_ephemeral_chat_transfer_credentials_20260817` |
| `20260817175028` | `f5_ephemeral_pgp_payload_transport_20260817` |
| `20260817203504` | `sentinel_f13_owner_hub` |
| `20260817211133` | `f5_chat_gzip_bundle_tmp_20260817` |

## LOCAL_ONLY

| Repository version | Repository name | Local path | Local MD5 |
|---:|---|---|---|
| `20260815134500` | `marketing_attribution_v2_exact_candidate_identity` | `supabase/migrations/20260815134500_marketing_attribution_v2_exact_candidate_identity.sql` | `a48e23040a82670c78c588450d907e8a` |
| `20260815135500` | `call_center_followups_v2_contract` | `supabase/migrations/20260815135500_call_center_followups_v2_contract.sql` | `5aa26f4609fbc5eaab46f8d94b08a498` |
| `20260815160000` | `wa1_secure_gateway_v1` | `supabase/migrations/20260815160000_wa1_secure_gateway_v1.sql` | `67c53c9c891441d45accb7a7d523b592` |
| `20260815162000` | `f4_revenue_production_canary_p0` | `supabase/migrations/20260815162000_f4_revenue_production_canary_p0.sql` | `3cbbde22adc85ee72ee55281af6a4228` |
| `20260815175500` | `wa2_conversation_live_inbox_v1` | `supabase/migrations/20260815175500_wa2_conversation_live_inbox_v1.sql` | `3efe079aa54e6061a181d8f93db22dcb` |
| `20260815190500` | `wa3_boxes_routing_handoff_v1` | `supabase/migrations/20260815190500_wa3_boxes_routing_handoff_v1.sql` | `896e35974266437ea0cf6c6964c5f425` |
| `20260815191500` | `f4_cartera_gateway_v2_auth_chain_hotfix` | `supabase/migrations/20260815191500_f4_cartera_gateway_v2_auth_chain_hotfix.sql` | `1906b0ee0d2d8c841c3781888957783f` |
| `20260815203000` | `wa4_ai_sales_router_v1` | `supabase/migrations/20260815203000_wa4_ai_sales_router_v1.sql` | `be9a6864d4fc195bca56de21c2e2f303` |
| `20260815204500` | `groq_gpt_oss_model_refresh` | `supabase/migrations/20260815204500_groq_gpt_oss_model_refresh.sql` | `c413fbd056268f2964b77b327dcc6477` |
| `20260815205000` | `integration_secret_boundary_v1` | `supabase/migrations/20260815205000_integration_secret_boundary_v1.sql` | `99da2c26e29d771e4cea906fa9359d13` |
| `20260815215000` | `cia_phase17_multichannel_contracts_v1` | `supabase/migrations/20260815215000_cia_phase17_multichannel_contracts_v1.sql` | `f0ce5b328a5ece4f6fee3f9cdbc43a4c` |
| `20260815220000` | `f5_historical_patient_identity_foundation_v1` | `supabase/migrations/20260815220000_f5_historical_patient_identity_foundation_v1.sql` | `add52ddbcc9d79fb8885314b9ed9b6e1` |
| `20260815223000` | `cia_phase17_whatsapp_adapter_contracts_v1` | `supabase/migrations/20260815223000_cia_phase17_whatsapp_adapter_contracts_v1.sql` | `8cbada019e91caae8f6bc856a288cef6` |
| `20260815233000` | `f5_historical_patient_identity_private_ingest_v1` | `supabase/migrations/20260815233000_f5_historical_patient_identity_private_ingest_v1.sql` | `18afe263eb99abeba78410df743e28fe` |
| `20260816000500` | `f5_historical_patient_identity_compact_preview_v1` | `supabase/migrations/20260816000500_f5_historical_patient_identity_compact_preview_v1.sql` | `19b89c5b491acd699331ca9a181d8ea3` |
| `20260816000600` | `f5_cluster_fieldwise_enrichment_v1` | `supabase/migrations/20260816000600_f5_cluster_fieldwise_enrichment_v1.sql` | `4f4129aeee74938e592430ca1718b439` |
| `20260816054900` | `f17_legacy_whatsapp_acl_p0` | `supabase/migrations/20260816054900_f17_legacy_whatsapp_acl_p0.sql` | `b5686405d902f934914f39392b72f253` |
| `20260816233500` | `sentinel_f8_incident_engine` | `supabase/migrations/20260816233500_sentinel_f8_incident_engine.sql` | `01016e822e0926ab81e6222e24f9c79a` |
| `20260817010000` | `sentinel_f9_alert_outbox` | `supabase/migrations/20260817010000_sentinel_f9_alert_outbox.sql` | `d3e3917c3b8aba652639c0d2997e3be6` |
| `20260817015500` | `sentinel_f9_digest_incident_fk_index` | `supabase/migrations/20260817015500_sentinel_f9_digest_incident_fk_index.sql` | `19744774104e7abfb0599e358b3c74fe` |
| `20260817043000` | `sentinel_f9_inapp_owner_alerts` | `supabase/migrations/20260817043000_sentinel_f9_inapp_owner_alerts.sql` | `56a3b67a2ad987a9225e8ed9052ba59a` |
| `20260817170500` | `f17_legacy_whatsapp_acl_final` | `supabase/migrations/20260817170500_f17_legacy_whatsapp_acl_final.sql` | `a6cb940869af1da86a0ed66e14dae4b1` |

## DUPLICATE_LOCAL_VERSION

| Version | Local entries |
|---:|---|
| `20260814200500` | `cia_phase16_email_governed_schema_v1` → `supabase/migrations/20260814200500_cia_phase16_email_governed_schema_v1.sql`; `phase3_product_canonical_schema_v1` → `supabase/migrations/20260814200500_phase3_product_canonical_schema_v1.sql` |
| `20260814200600` | `cia_phase16_email_contracts_v1` → `supabase/migrations/20260814200600_cia_phase16_email_contracts_v1.sql`; `phase3_product_owner_seed_v1` → `supabase/migrations/20260814200600_phase3_product_owner_seed_v1.sql` |

## UNSUPPORTED_STATEMENT_COUNT

| Production version | Migration | Statement count |
|---:|---|---:|
| — | — | — |

## Gate

This audit intentionally does **not** mutate production or Supabase migration history.

Analysis PASS means the report was generated deterministically from a read-only production statement-hash snapshot. Release parity remains blocked until every non-exact row is resolved by its owning workstream and Supabase Preview is green on exact CURRENT head.
