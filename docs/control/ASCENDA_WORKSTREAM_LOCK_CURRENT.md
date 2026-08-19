# ASCENDA OS — WORKSTREAM EXECUTION LOCK CURRENT

**Status:** CURRENT / REV-F5 REACTIVATED  
**Owner assignment:** 2026-08-18 Lima — resume definitive REV-F5 closeout  
**Certified hotfix merge:** `main@d260a5e060e840d8db6baca9581bbc5386539d10` / PR #284  
**Previous lock:** `HOTFIX-WILMER-AGENDA-MARKETING-2-20260818` — CLOSED / PRODUCTION CERTIFIED  
**ACTIVE LOCK:** `REV-F5-CLOSEOUT`  
**NEXT LOCK:** `UNASSIGNED` until REV-F5 is production-certified.

## Hotfix-2 certification

Canonical evidence:

- `docs/control/REV_F5_PAUSE_CHECKPOINT_20260818_WILMER_AGENDA_HOTFIX2.md`;
- `docs/control/WILMER_AGENDA_SEMANTICS_HOTFIX2_CERT_20260818.md`;
- migration `wilmer_agenda_semantics_hotfix2_20260818`;
- migration `late_lead_agenda_origin_marketing_fix_20260818`;
- PR #284 merged at `d260a5e060e840d8db6baca9581bbc5386539d10`.

Certified business semantics:

- 12 Wilmer scheduling/reagenda rows from 2026-08-18 were removed from `aos_llamadas` after full JSON audit archival;
- all 12 corresponding Agenda rows remain intact;
- 9 classified `PACIENTE_CONTINUIDAD`, 3 `REAGENDA_NO_COMERCIAL`;
- the two later cases `910303293` and `982093872` remain as valid Agenda reagendas and retain direct Marketing lead attribution;
- future continuation/reagenda confirmations are archived as non-commercial and suppressed from `aos_llamadas`, preventing Home/Calls/Marketing KPI inflation;
- Agenda/CITA_MANUAL created before a unique same-day Marketing lead, with no registered call and no prior clinical conversion, receives direct Agenda attribution only; no call is fabricated;
- one deterministic historical Mireya Agenda-only late-lead case (`935740326` → lead 4610) was reconciled.

## REV-F5 resume state

Production Supabase remained unchanged through hotfix-2:

- source batches: **6**;
- expected source rows: **15,498**;
- `aos_f5_patient_source_rows_v1`: **7,064**;
- remaining source rows: **8,434**;
- `aos_f5_identity_clusters_v1`: **3,950**;
- `aos_f5_identity_cluster_members_v1`: **0**;
- `aos_f5_patient_link_preview_v1`: **0**;
- `aos_f5_canonical_apply_events_v1`: **0**;
- `aos_pacientes`: **7,679**.

Resume REV-F5 from **7,064/15,498**, reconciling persisted state before any retry. Never restart from the obsolete 1,000-row snapshot.

## Global rule

At most one HIGH/CRITICAL mutable workstream may operate at a time. While `REV-F5-CLOSEOUT` owns the lock, Calls/Agenda/Marketing remains regression-only unless another explicit recoverable pause is authorized.
