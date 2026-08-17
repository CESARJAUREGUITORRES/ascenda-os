# ASCENDA OS — Migration History Parity Audit CURRENT

**CURRENT source tree:** generated from `supabase/migrations` on the audit branch based on `main@f68b5c0efe3765af8ea8abd0760af29cd13928df`.
**Production evidence:** read-only frozen `supabase_migrations.schema_migrations` versions >= `20260815000000`.

## Summary

- `remote_rows`: **60**
- `local_rows_all`: **89**
- `exact_content`: **6**
- `content_exact_version_drift`: **0**
- `content_exact_name_and_version_drift`: **0**
- `exact_version_content_mismatch`: **1**
- `name_match_content_mismatch`: **24**
- `version_name_conflict`: **0**
- `ambiguous_content_match`: **0**
- `unsupported_statement_count`: **0**
- `remote_only`: **29**
- `local_only`: **23**
- `duplicate_local_version`: **0**

## CONTENT_EXACT_VERSION_DRIFT

|name|prod_version|local_version|path|md5|
|---|---|---|---|---|
|—|—|—|—|—|

## EXACT_VERSION_CONTENT_MISMATCH

|version|name|path|prod_md5|local_md5|
|---|---|---|---|---|
|`20260817203504`|`sentinel_f13_owner_hub`|`supabase/migrations/20260817203504_sentinel_f13_owner_hub.sql`|`e403332d1c9f53efa0338f8f3585442c`|`5022ae05e1b705e587cad2e0c957df72`|

## NAME_MATCH_CONTENT_MISMATCH

|name|prod_version|local_version|path|prod_md5|local_md5|
|---|---|---|---|---|---|
|`f4_revenue_operations_core_v1`|`20260815095037`|`20260814223000`|`supabase/migrations/20260814223000_f4_revenue_operations_core_v1.sql`|`a2b043b91ca5cba12aba3d47997036b0`|`cf29a2a6c3692f99843c65c09dd4b914`|
|`f4_cartera_candidates_v2`|`20260815095105`|`20260814223100`|`supabase/migrations/20260814223100_f4_cartera_candidates_v2.sql`|`a8faee8cfec0be313d876d5c9d32940d`|`867dcd901ca9791182e9554716d703ab`|
|`marketing_attribution_v2_exact_candidate_identity`|`20260815134059`|`20260815134500`|`supabase/migrations/20260815134500_marketing_attribution_v2_exact_candidate_identity.sql`|`a37a261c17f95a0c9f13f3388d04b04b`|`a48e23040a82670c78c588450d907e8a`|
|`call_center_followups_v2_contract`|`20260815135145`|`20260815135500`|`supabase/migrations/20260815135500_call_center_followups_v2_contract.sql`|`8403254872a50d2d027b078879b7118d`|`5aa26f4609fbc5eaab46f8d94b08a498`|
|`fix_secure_write_v2_jsonb_match_count`|`20260815152341`|`20260814201500`|`supabase/migrations/20260814201500_fix_secure_write_v2_jsonb_match_count.sql`|`11426c9268485511c70b00cc28319f46`|`267bebb91b63d23a21498935824827d3`|
|`wa1_secure_gateway_v1`|`20260815163307`|`20260815160000`|`supabase/migrations/20260815160000_wa1_secure_gateway_v1.sql`|`3217d2155b13c6023d47481e4bf35683`|`67c53c9c891441d45accb7a7d523b592`|
|`f4_revenue_production_canary_p0`|`20260815165537`|`20260815162000`|`supabase/migrations/20260815162000_f4_revenue_production_canary_p0.sql`|`90301e1f14ed006690e5affa1ac7ada4`|`3cbbde22adc85ee72ee55281af6a4228`|
|`wa2_conversation_live_inbox_v1`|`20260815183105`|`20260815175500`|`supabase/migrations/20260815175500_wa2_conversation_live_inbox_v1.sql`|`cc290733fe6c8c0c81b2525d5a42d187`|`3efe079aa54e6061a181d8f93db22dcb`|
|`f4_cartera_gateway_v2_auth_chain_hotfix`|`20260815192012`|`20260815191500`|`supabase/migrations/20260815191500_f4_cartera_gateway_v2_auth_chain_hotfix.sql`|`e5797a02bdd5a9aa2b08883611e335e1`|`1906b0ee0d2d8c841c3781888957783f`|
|`wa3_boxes_routing_handoff_v1`|`20260815193102`|`20260815190500`|`supabase/migrations/20260815190500_wa3_boxes_routing_handoff_v1.sql`|`93da6a9b3d1fd1ff5bec0aea78553e26`|`896e35974266437ea0cf6c6964c5f425`|
|`wa4_ai_sales_router_v1`|`20260815211255`|`20260815203000`|`supabase/migrations/20260815203000_wa4_ai_sales_router_v1.sql`|`d575df4795a6182a5839ca76758368bd`|`be9a6864d4fc195bca56de21c2e2f303`|
|`groq_gpt_oss_model_refresh`|`20260815211320`|`20260815204500`|`supabase/migrations/20260815204500_groq_gpt_oss_model_refresh.sql`|`25277daf5b917cc3f81b3ceec5d62e49`|`c413fbd056268f2964b77b327dcc6477`|
|`cia_phase16_email_delivery_contracts_v2`|`20260815220259`|`20260814220000`|`supabase/migrations/20260814220000_cia_phase16_email_delivery_contracts_v2.sql`|`103c4e32a0fd4e52083571549e2b1bad`|`1f0fdb1732534f803df75c36fa9c375b`|
|`f5_historical_patient_identity_private_ingest_v1`|`20260815232737`|`20260815233000`|`supabase/migrations/20260815233000_f5_historical_patient_identity_private_ingest_v1.sql`|`784f5210bac2db97dbb0e7b5df3494ee`|`18afe263eb99abeba78410df743e28fe`|
|`integration_secret_boundary_v1`|`20260815234408`|`20260815205000`|`supabase/migrations/20260815205000_integration_secret_boundary_v1.sql`|`4ca29ebbfe3c492aecd469351e449e81`|`99da2c26e29d771e4cea906fa9359d13`|
|`cia_phase17_multichannel_contracts_v1`|`20260816031658`|`20260815215000`|`supabase/migrations/20260815215000_cia_phase17_multichannel_contracts_v1.sql`|`83b904fd61470df3a317f72a96418267`|`f0ce5b328a5ece4f6fee3f9cdbc43a4c`|
|`f17_legacy_whatsapp_acl_p0`|`20260816093639`|`20260816054900`|`supabase/migrations/20260816054900_f17_legacy_whatsapp_acl_p0.sql`|`fed4a79864ee95ac98bbf2d66be07057`|`b5686405d902f934914f39392b72f253`|
|`sentinel_f8_incident_engine`|`20260817000618`|`20260816233500`|`supabase/migrations/20260816233500_sentinel_f8_incident_engine.sql`|`1e99619578cd1768084967181fb22a36`|`01016e822e0926ab81e6222e24f9c79a`|
|`sentinel_f9_alert_outbox`|`20260817013916`|`20260817010000`|`supabase/migrations/20260817010000_sentinel_f9_alert_outbox.sql`|`36deb43853f3779095aaa74e5ccc7aa6`|`d3e3917c3b8aba652639c0d2997e3be6`|
|`sentinel_f9_digest_incident_fk_index`|`20260817014618`|`20260817015500`|`supabase/migrations/20260817015500_sentinel_f9_digest_incident_fk_index.sql`|`04a5d3465e1a8c629bfb95a8f7747759`|`19744774104e7abfb0599e358b3c74fe`|
|`f17_legacy_whatsapp_acl_final`|`20260817170316`|`20260817170500`|`supabase/migrations/20260817170500_f17_legacy_whatsapp_acl_final.sql`|`131d68b0874fd97d244d5cd871099485`|`a6cb940869af1da86a0ed66e14dae4b1`|
|`sentinel_f9_inapp_owner_alerts`|`20260817174233`|`20260817043000`|`supabase/migrations/20260817043000_sentinel_f9_inapp_owner_alerts.sql`|`299570bb3d5fbc142b95c5203929a81d`|`56a3b67a2ad987a9225e8ed9052ba59a`|
|`cia_phase17_whatsapp_adapter_contracts_v1`|`20260817183507`|`20260815223000`|`supabase/migrations/20260815223000_cia_phase17_whatsapp_adapter_contracts_v1.sql`|`7e56f3f474ae6bb3777a37bc7f0903d9`|`8cbada019e91caae8f6bc856a288cef6`|
|`wa_s14_web_push_notification_transport`|`20260817223004`|`20260817221500`|`supabase/migrations/20260817221500_wa_s14_web_push_notification_transport.sql`|`28de08e3fa7f9dcba31b2b9c5d95b1f8`|`517f0f2fe73e8b4660a9f6780f81634e`|

## CONTENT_EXACT_NAME_AND_VERSION_DRIFT

|prod_name|prod_version|local_name|local_version|path|md5|
|---|---|---|---|---|---|
|—|—|—|—|—|—|

## VERSION_NAME_CONFLICT

|version|prod_name|local_name|path|local_md5|
|---|---|---|---|---|
|—|—|—|—|—|

## REMOTE_ONLY

|prod_version|prod_name|prod_md5|
|---|---|---|
|`20260815161920`|`fix_admin_home_lima_business_date`|`4ff6651f9acf4d603c4192cf81abd6fb`|
|`20260815211021`|`f4_revenue_operations_final_cutover_20260815`|`2e7716e497cd64f52b345ae9a05ee99d`|
|`20260815215652`|`f5_historical_patient_identity_foundation_v1_20260815`|`c2480ec157d153221f37c746de6f1a3a`|
|`20260815224906`|`cia_phase16_live_canary_evidence_temp`|`e1376cd9406a73911c946aec7433a62a`|
|`20260816003421`|`f5_historical_patient_identity_compact_preview_v1_20260815`|`17b5262794985d8a94f5ff29a83432a2`|
|`20260816003440`|`f5_cluster_fieldwise_enrichment_v1_20260815`|`ec886c6e1951340066dec78287604688`|
|`20260816003807`|`f5_encrypted_transport_v1_20260815`|`ee5cc3c55297c5b13ce2b3011fb930c5`|
|`20260816004943`|`f5_ciphertext_transport_insert_window_20260815`|`5613494b72baf81939c1c4b02a82f4ad`|
|`20260816005038`|`f5_ciphertext_transport_insert_window_close_20260815`|`12733bde250bf3d4bb698a07cb6ba56d`|
|`20260816005058`|`f5_ciphertext_process_window_open_20260815`|`d3deb91c94c97111224bd4c29baa8b1c`|
|`20260816005121`|`f5_ciphertext_process_window_close_20260815`|`8d136a7327d069b74ae1345972da497a`|
|`20260816005222`|`f5_safe_preview_metrics_v1_20260815`|`b8830f9de1e325fbdcb682e6df8510e1`|
|`20260816005245`|`f5_safe_preview_metrics_close_20260815`|`03e2283ccc1e5ec4640f4dc36919f5ad`|
|`20260816005349`|`f5_encrypted_transport_cleanup_20260815`|`f6ac3dc7009d94f60b7f802c78094389`|
|`20260816013341`|`f5_ephemeral_cipher_recovery_staging_20260815`|`c65761a5d1ddca074ad088c2d38cf304`|
|`20260816014723`|`f5_ephemeral_cipher_recovery_rpc_20260815`|`60845a0854db250a7a2b0cf75447f0c3`|
|`20260816020011`|`hotfix_auth_v3_resend_private_vault`|`32d66b15a169fd3c46455bf889e55afa`|
|`20260816020627`|`f5_cleanup_ephemeral_transport_20260815`|`92268ac6ce88e0240f850fd0fcf2735b`|
|`20260816022053`|`f5_review_apply_v1_20260816`|`4527bf24650a99e728068eab097ddbed`|
|`20260817161248`|`f5_private_recovery_transport_bridge`|`b6a89151daa725c7b6035dad0efb3212`|
|`20260817171043`|`cia_phase17_whatsapp_canary_control_v1`|`79bd19a8524d6fac57476f41926802b7`|
|`20260817171102`|`cia_phase17_whatsapp_mark_dispatch_v1`|`03c787f6b896d28e6bda04beb785162e`|
|`20260817171119`|`cia_phase17_whatsapp_provider_event_v1`|`07d484b90c016e6458f83a0f17c2706c`|
|`20260817171141`|`cia_phase17_whatsapp_inbound_v1`|`f994dc533d5684546f4f99ddfc620841`|
|`20260817173258`|`f5_ephemeral_chat_ingest_bridge_20260817`|`aded97b20848ec179d93bbe6d02b27b0`|
|`20260817174205`|`f5_ephemeral_chat_transfer_credentials_20260817`|`1b37b5f8a0c0ac85cf6aa9bbbb28cc83`|
|`20260817175028`|`f5_ephemeral_pgp_payload_transport_20260817`|`38e57010f77186d8cacc24b6a33e683f`|
|`20260817211133`|`f5_chat_gzip_bundle_tmp_20260817`|`78c355fa3654e6cefbb0e77237ed8a5e`|
|`20260817225845`|`refresh_f5_ephemeral_bridge_20260817`|`d0fc14f7935485769d67899ff82b6b8f`|

## LOCAL_ONLY

|local_version|local_name|path|local_md5|
|---|---|---|---|
|`20260815134500`|`marketing_attribution_v2_exact_candidate_identity`|`supabase/migrations/20260815134500_marketing_attribution_v2_exact_candidate_identity.sql`|`a48e23040a82670c78c588450d907e8a`|
|`20260815135500`|`call_center_followups_v2_contract`|`supabase/migrations/20260815135500_call_center_followups_v2_contract.sql`|`5aa26f4609fbc5eaab46f8d94b08a498`|
|`20260815160000`|`wa1_secure_gateway_v1`|`supabase/migrations/20260815160000_wa1_secure_gateway_v1.sql`|`67c53c9c891441d45accb7a7d523b592`|
|`20260815162000`|`f4_revenue_production_canary_p0`|`supabase/migrations/20260815162000_f4_revenue_production_canary_p0.sql`|`3cbbde22adc85ee72ee55281af6a4228`|
|`20260815175500`|`wa2_conversation_live_inbox_v1`|`supabase/migrations/20260815175500_wa2_conversation_live_inbox_v1.sql`|`3efe079aa54e6061a181d8f93db22dcb`|
|`20260815190500`|`wa3_boxes_routing_handoff_v1`|`supabase/migrations/20260815190500_wa3_boxes_routing_handoff_v1.sql`|`896e35974266437ea0cf6c6964c5f425`|
|`20260815191500`|`f4_cartera_gateway_v2_auth_chain_hotfix`|`supabase/migrations/20260815191500_f4_cartera_gateway_v2_auth_chain_hotfix.sql`|`1906b0ee0d2d8c841c3781888957783f`|
|`20260815203000`|`wa4_ai_sales_router_v1`|`supabase/migrations/20260815203000_wa4_ai_sales_router_v1.sql`|`be9a6864d4fc195bca56de21c2e2f303`|
|`20260815204500`|`groq_gpt_oss_model_refresh`|`supabase/migrations/20260815204500_groq_gpt_oss_model_refresh.sql`|`c413fbd056268f2964b77b327dcc6477`|
|`20260815205000`|`integration_secret_boundary_v1`|`supabase/migrations/20260815205000_integration_secret_boundary_v1.sql`|`99da2c26e29d771e4cea906fa9359d13`|
|`20260815215000`|`cia_phase17_multichannel_contracts_v1`|`supabase/migrations/20260815215000_cia_phase17_multichannel_contracts_v1.sql`|`f0ce5b328a5ece4f6fee3f9cdbc43a4c`|
|`20260815220000`|`f5_historical_patient_identity_foundation_v1`|`supabase/migrations/20260815220000_f5_historical_patient_identity_foundation_v1.sql`|`add52ddbcc9d79fb8885314b9ed9b6e1`|
|`20260815223000`|`cia_phase17_whatsapp_adapter_contracts_v1`|`supabase/migrations/20260815223000_cia_phase17_whatsapp_adapter_contracts_v1.sql`|`8cbada019e91caae8f6bc856a288cef6`|
|`20260815233000`|`f5_historical_patient_identity_private_ingest_v1`|`supabase/migrations/20260815233000_f5_historical_patient_identity_private_ingest_v1.sql`|`18afe263eb99abeba78410df743e28fe`|
|`20260816000500`|`f5_historical_patient_identity_compact_preview_v1`|`supabase/migrations/20260816000500_f5_historical_patient_identity_compact_preview_v1.sql`|`19b89c5b491acd699331ca9a181d8ea3`|
|`20260816000600`|`f5_cluster_fieldwise_enrichment_v1`|`supabase/migrations/20260816000600_f5_cluster_fieldwise_enrichment_v1.sql`|`4f4129aeee74938e592430ca1718b439`|
|`20260816054900`|`f17_legacy_whatsapp_acl_p0`|`supabase/migrations/20260816054900_f17_legacy_whatsapp_acl_p0.sql`|`b5686405d902f934914f39392b72f253`|
|`20260816233500`|`sentinel_f8_incident_engine`|`supabase/migrations/20260816233500_sentinel_f8_incident_engine.sql`|`01016e822e0926ab81e6222e24f9c79a`|
|`20260817010000`|`sentinel_f9_alert_outbox`|`supabase/migrations/20260817010000_sentinel_f9_alert_outbox.sql`|`d3e3917c3b8aba652639c0d2997e3be6`|
|`20260817015500`|`sentinel_f9_digest_incident_fk_index`|`supabase/migrations/20260817015500_sentinel_f9_digest_incident_fk_index.sql`|`19744774104e7abfb0599e358b3c74fe`|
|`20260817043000`|`sentinel_f9_inapp_owner_alerts`|`supabase/migrations/20260817043000_sentinel_f9_inapp_owner_alerts.sql`|`56a3b67a2ad987a9225e8ed9052ba59a`|
|`20260817170500`|`f17_legacy_whatsapp_acl_final`|`supabase/migrations/20260817170500_f17_legacy_whatsapp_acl_final.sql`|`a6cb940869af1da86a0ed66e14dae4b1`|
|`20260817221500`|`wa_s14_web_push_notification_transport`|`supabase/migrations/20260817221500_wa_s14_web_push_notification_transport.sql`|`517f0f2fe73e8b4660a9f6780f81634e`|

## AMBIGUOUS_CONTENT_MATCH

|prod_version|name|class|count|
|---|---|---|---|
|—|—|—|—|

## DUPLICATE_LOCAL_VERSION

|version|entries|
|---|---|
|—|—|

## Gate

Automatic repair is permitted only for `CONTENT_EXACT_VERSION_DRIFT` after owner/current checks. Content mismatches, remote-only rows, transient F5 transport rows and ambiguous matches remain fail-closed.
