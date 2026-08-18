# REV-F5 — TEMPORARY PAUSE CHECKPOINT FOR WILMER / AGENDA SEMANTICS HOTFIX-2

**Status:** RECOVERABLE PAUSE / owner-authorized by explicit request to correct Wilmer + strengthen Agenda→late Marketing attribution  
**Date:** 2026-08-18 America/Lima  
**Source main before pause:** `269fd9f2edf133db82eeab3e4e8eb2f8b68d0d48`  
**Reason:** correct Wilmer 2026-08-18 non-commercial scheduling rows so Agenda is preserved but Calls/Home commercial KPIs are not inflated; strengthen Agenda-manual-first → Marketing-lead-later attribution without fabricating calls.

## Live REV-F5 checkpoint captured immediately before pause

Production Supabase `ituyqwstonmhnfshnaqz`:

- source manifests: **6**;
- expected source rows: **15,498**;
- `aos_f5_patient_source_rows_v1`: **7,064**;
- pending rows: **8,434**;
- `aos_f5_identity_clusters_v1`: **3,950**;
- `aos_f5_identity_cluster_members_v1`: **0**;
- `aos_f5_patient_link_preview_v1`: **0**;
- `aos_f5_canonical_apply_events_v1`: **0**;
- `aos_pacientes`: **7,679**;
- F5 temporary transport/gzip/pgp/credential rows: **0**.

## Hotfix scope

May mutate only Calls / Agenda / Marketing semantic attribution, KPI exclusion and traceability needed for this hotfix. Must not mutate F5-owned source, cluster, preview, apply, or patient canonical data.

## Resume contract

After production certification, re-read live counts. If the F5 checkpoint remains unchanged, immediately restore `ACTIVE LOCK: REV-F5-CLOSEOUT` and resume from **7,064/15,498**. Never restart from an older snapshot.
