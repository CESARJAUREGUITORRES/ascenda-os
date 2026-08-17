# ASCENDA OS — Migration Parity Owner Matrix

**Status:** CURRENT classification companion to #238  
**Source:** strong content-hash audit of 58 production migrations from 2026-08-15 onward.  
**Safety rule:** no bulk timestamp repair. Each owner closes its own durable-history slice with semantic/content evidence and isolated replay.

## 1. Already isolated as safe

### CIA F16 — exact-content version drift
Owner: CIA F16 / migration-history control.

Six rows are byte-identical live vs repository and are isolated in PR #248 as version-only renames. No SQL-content change.

Repair class: `SAFE_VERSION_RENAME`, pending full-history replay + exact CURRENT synchronization.

## 2. Same-name / content-mismatch families

### Revenue F4 / Cartera
Rows:
- `f4_revenue_operations_core_v1`
- `f4_cartera_candidates_v2`
- `f4_revenue_production_canary_p0`
- `f4_cartera_gateway_v2_auth_chain_hotfix`

Owner: Revenue F4 recovery/production history.
Repair class: `SEMANTIC_HISTORY_REVIEW`.
Rule: preserve current F4 runtime; compare live durable functions/ACL/state against the final repository contract before any rename. Historical production canary/cutover evidence may require no-op tombstones rather than replay.

### Marketing / Call Center
Rows:
- `marketing_attribution_v2_exact_candidate_identity`
- `call_center_followups_v2_contract`

Owner: Attribution / Call Center contract lineage.
Repair class: `SEMANTIC_HISTORY_REVIEW`.
Rule: determine whether production statement is an earlier materialized variant and whether repository file is a forward-compatible superset. No timestamp-only rename.

### Auth / secure-write
Rows:
- `fix_secure_write_v2_jsonb_match_count`
- `integration_secret_boundary_v1`

Owner: Auth V3 / security boundary.
Repair class: `SECURITY_SEMANTIC_REVIEW`.
Rule: compare SECURITY DEFINER, `search_path`, grants/revokes, secret storage and recovery semantics before history changes. Never copy live secrets/credential payloads into Git.

### WhatsApp WA1–WA4 / Groq
Rows:
- `wa1_secure_gateway_v1`
- `wa2_conversation_live_inbox_v1`
- `wa3_boxes_routing_handoff_v1`
- `wa4_ai_sales_router_v1`
- `groq_gpt_oss_model_refresh`

Owner: WhatsApp Revenue Hub S-series lineage.
Repair class: `SEMANTIC_HISTORY_REVIEW`.
Rule: reconcile legacy WA1–WA4 migrations with CURRENT S12 runtime and F17 channel ledger. Do not create a second WhatsApp truth or replay obsolete gateway/router variants blindly.

### CIA F16 delivery
Row:
- `cia_phase16_email_delivery_contracts_v2`

Owner: CIA F16.
Repair class: `SEMANTIC_HISTORY_REVIEW`.
Rule: isolate from the six exact renames; prove delivery/outcome semantics and ACL equivalence before version alignment.

### Revenue F5 durable identity
Row:
- `f5_historical_patient_identity_private_ingest_v1`

Owner: Revenue F5.
Repair class: `ACTIVE_OWNER_REVIEW`.
Rule: F5 remains in recovery/provenance work. No generic history repair while the owner still has production-only temporary migrations and zero reviewed preview/apply.

### CIA F17
Rows:
- `cia_phase17_multichannel_contracts_v1`
- `f17_legacy_whatsapp_acl_p0`
- `f17_legacy_whatsapp_acl_final`
- `cia_phase17_whatsapp_adapter_contracts_v1`

Owner: CIA F17.
Repair class: `OWNER_HISTORY_CHAIN`.
Known result for final adapter: durable/security SQL equivalent to production after normalization; eligible for version alignment only with replay-order proof and historical representation of superseded intermediate production migrations.

### Sentinel F8/F9
Rows:
- `sentinel_f8_incident_engine`
- `sentinel_f9_alert_outbox`
- `sentinel_f9_digest_incident_fk_index`
- `sentinel_f9_inapp_owner_alerts`

Owner: Sentinel.
Repair class: `SENTINEL_HISTORY_REVIEW`.
Rule: preserve F12/F13 privacy and owner/human-approval boundaries. Repair history separately from live incident/remediation behavior.

## 3. Production-only families

### F4 production-only
- `fix_admin_home_lima_business_date`
- `f4_revenue_operations_final_cutover_20260815`

Owner: Revenue F4.
Likely class: production hotfix/cutover history. Requires provenance and final-state comparison; candidate no-op tombstone only if durable state is already represented in repository and replay remains correct.

### F5 production-only / transient transport
Production-only F5 rows include foundation/preview/enrichment plus multiple encrypted/ciphertext/recovery/chat/PGP/gzip transport migrations.

Owner: Revenue F5 active workstream.
Class: `ACTIVE_OR_EPHEMERAL_OWNER_HISTORY`.
Rules:
- do not generic-repair while F5 is active;
- never copy credentials, encrypted payload transport, temporary bundles or ephemeral operational data into Git;
- durable schema/function history may be represented later by sanitized canonical migrations or explicit no-op historical tombstones after provenance proof;
- active latest `f5_chat_gzip_bundle_tmp_20260817` remains outside generic parity repair.

### CIA F16 live canary evidence
- `cia_phase16_live_canary_evidence_temp`

Owner: CIA F16 release evidence.
Class: `EPHEMERAL_EVIDENCE_HISTORY`.
Rule: never replay real canary evidence into a clean DB. If history parity requires a local version, use an explicit no-op tombstone only after confirming the durable F16 schema is represented elsewhere.

### Auth V3 hotfix
- `hotfix_auth_v3_resend_private_vault`

Owner: Auth/KronIA security boundary.
Class: `SECURITY_HISTORY_REVIEW`.
Rule: reconcile durable vault/ACL state without putting provider secrets into Git. Provider-side credential rotation/revocation remains a separate release gate.

### CIA F17 intermediate production chain
- `cia_phase17_whatsapp_canary_control_v1`
- `cia_phase17_whatsapp_mark_dispatch_v1`
- `cia_phase17_whatsapp_provider_event_v1`
- `cia_phase17_whatsapp_inbound_v1`

Owner: CIA F17.
Class: `SUPERSEDED_INTERMEDIATE_HISTORY`.
Evidence: final canonical F17 adapter reproduces the durable/security surfaces after normalization. Candidate repair: exact-version no-op tombstones for the four intermediates + final canonical file at live version `20260817183507`, but only after isolated full-order replay.

### Sentinel F13
- production `20260817203504_sentinel_f13_owner_hub`
- active branch local `20260817203500_sentinel_f13_owner_hub.sql`

Owner: Sentinel F13.
Class: `VERSION_ONLY_FORMAT_DRIFT`.
Evidence: normalized MD5 and normalized length are exact. Repair belongs in the F13 integration child after syncing CURRENT main; update workflow/test path references and run F13 exact-head gates.

## 4. Release ordering

1. Full-history isolated replay must produce actionable evidence; infrastructure failures do not count as migration failures.
2. Merge only coherent owner slices.
3. After each accepted slice, refresh `main`, production ledger snapshot and strong parity audit.
4. #238 closes only when every production version has an intentional local history representation, no unowned local drift remains, full clean replay passes, and CURRENT exact-head CI is green.
5. Only then rebuild KronIA K1 on the clean CURRENT baseline.
