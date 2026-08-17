# ASCENDA OS — Migration History Parity Audit

**Mode:** read-only / offline comparison against frozen production ledger snapshot  
**Scope:** versions `>= 20260815000000`  
**Remote rows:** 58  
**Local rows in scope:** 23  

## Summary

- EXACT: **0**
- SAME_NAME_DIFFERENT_VERSION: **20**
- VERSION_NAME_CONFLICT: **0**
- REMOTE_ONLY: **38**
- LOCAL_ONLY: **3**

`SAME_NAME_DIFFERENT_VERSION` is a candidate for filename/history reconciliation only after content identity is proven. `REMOTE_ONLY` may be active concurrent work and must never be blindly deleted or replayed.

## SAME_NAME_DIFFERENT_VERSION

| Migration | Production version | Repository version | Local path |
|---|---:|---:|---|
| `marketing_attribution_v2_exact_candidate_identity` | `20260815134059` | `20260815134500` | `migrations/20260815134500_marketing_attribution_v2_exact_candidate_identity.sql` |
| `call_center_followups_v2_contract` | `20260815135145` | `20260815135500` | `migrations/20260815135500_call_center_followups_v2_contract.sql` |
| `wa1_secure_gateway_v1` | `20260815163307` | `20260815160000` | `migrations/20260815160000_wa1_secure_gateway_v1.sql` |
| `f4_revenue_production_canary_p0` | `20260815165537` | `20260815162000` | `migrations/20260815162000_f4_revenue_production_canary_p0.sql` |
| `wa2_conversation_live_inbox_v1` | `20260815183105` | `20260815175500` | `migrations/20260815175500_wa2_conversation_live_inbox_v1.sql` |
| `f4_cartera_gateway_v2_auth_chain_hotfix` | `20260815192012` | `20260815191500` | `migrations/20260815191500_f4_cartera_gateway_v2_auth_chain_hotfix.sql` |
| `wa3_boxes_routing_handoff_v1` | `20260815193102` | `20260815190500` | `migrations/20260815190500_wa3_boxes_routing_handoff_v1.sql` |
| `wa4_ai_sales_router_v1` | `20260815211255` | `20260815203000` | `migrations/20260815203000_wa4_ai_sales_router_v1.sql` |
| `groq_gpt_oss_model_refresh` | `20260815211320` | `20260815204500` | `migrations/20260815204500_groq_gpt_oss_model_refresh.sql` |
| `cia_phase16_resend_outcome_coverage_v3` | `20260815221343` | `20260815221000` | `migrations/20260815221000_cia_phase16_resend_outcome_coverage_v3.sql` |
| `f5_historical_patient_identity_private_ingest_v1` | `20260815232737` | `20260815233000` | `migrations/20260815233000_f5_historical_patient_identity_private_ingest_v1.sql` |
| `integration_secret_boundary_v1` | `20260815234408` | `20260815205000` | `migrations/20260815205000_integration_secret_boundary_v1.sql` |
| `cia_phase17_multichannel_contracts_v1` | `20260816031658` | `20260815215000` | `migrations/20260815215000_cia_phase17_multichannel_contracts_v1.sql` |
| `f17_legacy_whatsapp_acl_p0` | `20260816093639` | `20260816054900` | `migrations/20260816054900_f17_legacy_whatsapp_acl_p0.sql` |
| `sentinel_f8_incident_engine` | `20260817000618` | `20260816233500` | `migrations/20260816233500_sentinel_f8_incident_engine.sql` |
| `sentinel_f9_alert_outbox` | `20260817013916` | `20260817010000` | `migrations/20260817010000_sentinel_f9_alert_outbox.sql` |
| `sentinel_f9_digest_incident_fk_index` | `20260817014618` | `20260817015500` | `migrations/20260817015500_sentinel_f9_digest_incident_fk_index.sql` |
| `f17_legacy_whatsapp_acl_final` | `20260817170316` | `20260817170500` | `migrations/20260817170500_f17_legacy_whatsapp_acl_final.sql` |
| `sentinel_f9_inapp_owner_alerts` | `20260817174233` | `20260817043000` | `migrations/20260817043000_sentinel_f9_inapp_owner_alerts.sql` |
| `cia_phase17_whatsapp_adapter_contracts_v1` | `20260817183507` | `20260815223000` | `migrations/20260815223000_cia_phase17_whatsapp_adapter_contracts_v1.sql` |

## VERSION_NAME_CONFLICT

| Version | Production name | Local name | Local path |
|---:|---|---|---|
| — | — | — | — |

## REMOTE_ONLY

| Production version | Production name |
|---:|---|
| `20260815095037` | `f4_revenue_operations_core_v1` |
| `20260815095105` | `f4_cartera_candidates_v2` |
| `20260815152341` | `fix_secure_write_v2_jsonb_match_count` |
| `20260815161920` | `fix_admin_home_lima_business_date` |
| `20260815211021` | `f4_revenue_operations_final_cutover_20260815` |
| `20260815215652` | `f5_historical_patient_identity_foundation_v1_20260815` |
| `20260815215930` | `cia_phase16_email_governed_schema_v1` |
| `20260815220040` | `cia_phase16_email_contracts_v1` |
| `20260815220259` | `cia_phase16_email_delivery_contracts_v2` |
| `20260815220329` | `cia_phase16_email_render_context_hardening` |
| `20260815220344` | `cia_phase16_verify_app_session_v1` |
| `20260815220458` | `cia_phase16_legacy_email_acl_hardening` |
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

| Repository version | Repository name | Local path |
|---:|---|---|
| `20260815220000` | `f5_historical_patient_identity_foundation_v1` | `migrations/20260815220000_f5_historical_patient_identity_foundation_v1.sql` |
| `20260816000500` | `f5_historical_patient_identity_compact_preview_v1` | `migrations/20260816000500_f5_historical_patient_identity_compact_preview_v1.sql` |
| `20260816000600` | `f5_cluster_fieldwise_enrichment_v1` | `migrations/20260816000600_f5_cluster_fieldwise_enrichment_v1.sql` |

## Gate

This audit intentionally does **not** mutate production or Supabase migration history.

PASS for analysis means the report was generated deterministically. Release parity is not PASS until every non-EXACT row is classified and resolved by its owning workstream, followed by a green Supabase Preview on exact CURRENT head.
