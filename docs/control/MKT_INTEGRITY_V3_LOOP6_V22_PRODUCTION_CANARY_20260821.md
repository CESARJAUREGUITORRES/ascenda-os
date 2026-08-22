# MKT-INTEGRITY-V3 · Loop 6 V2.2 production canary baseline

## Functional runtime
- PR #340: MERGED.
- Merge / functional runtime: `f6adba60358d7d45ef547ba29f0189767b0355e9`.
- Railway status for exact commit: SUCCESS (`ASCENDA-OS - ascenda-os`).
- Loader: exactly one `/calls-loop6.js?v=20260821-loop6-v2.2`.
- Runtime marker: `window.__AOS_CC_LOOP6_V2__='v2.2'`.
- Unsafe SPA early-return removed.
- Legacy `ccConfirmarCita()` / `guardarCitaManual()` paths fail closed unless exact v2.2 runtime is active.
- DB BEFORE INSERT guards fail closed for non-governed commercial Call and Call Center Agenda writes.

## First real canary incident and repair
Ruben Carlos Dominguez Munoz / `997883711` was the first genuine prior-baseline canary and exposed a stale/legacy runtime bypass.

Certified repair:
- Marketing lead `5884` CAPILAR;
- commercial Call `38384` = `CITA CONFIRMADA / FOLLOWUP_CONVERSION / MARKETING / MIREYA`;
- Agenda `2c581c52-89e9-465f-89be-0e3818eda309` linked to Call `38384` and lead `5884`, `origen_cita=CALL_CENTER`;
- Seguimiento `SEG-1787354621097-4zle` = COMPLETADO, lead `5884`;
- action journal key `repair-ruben-997883711-20260821-193506` = COMPLETE, creditedAdvisor MIREYA.
- post-repair live panel observed Mireya at 3 citas; call total remains dynamic during concurrent advisor work.

Three additional pre-hotfix legacy-unlinked Agenda rows remain documented without automatic commercial credit because evidence did not justify it:
- `7d530a24-fe05-43bc-b7ab-a83428050532` / 928017492 / WILMER;
- `dc99e863-1e97-49e3-8000-cc420b71bc8a` / 995558890 / WILMER;
- `92949454-4c1e-4273-bb7c-9b2b9288e0b2` / 980749071 / WILMER (<15d converted patient at incident time).

## Post-deploy safety proof
Rollback canary after Railway SUCCESS:
- direct legacy commercial Call => 0 persisted;
- direct legacy CITA_MANUAL Agenda => 0 persisted;
- governed RPC => journal 1 / Call 1 / Agenda 1 inside transaction;
- rollback => zero synthetic residue.

No new unlinked legacy Call Center Agenda was observed after V2.2 fail-closed activation.

## Protected invariants
At baseline:
- protected calls `36701,37185,37813,38012,38168,38186`: 6/6 present;
- removed Alberto/Alan duplicate Agenda IDs: 0 present;
- REV-F5: 6 batches / 15,498 source / 8,716 clusters / 15,498 members / 8,716 previews / 230 apply events;
- F6 Identity + Lifecycle: service-role-only;
- Acquisition: V2 56 / V3 57.

## New authoritative genuine-operation baseline
Captured only after PR #340 Railway exact-commit SUCCESS and post-deploy rollback canary:

- UTC: `2026-08-22T01:17:57.749075+00:00`
- America/Lima: **2026-08-21 20:17:57**
- action journal total: **1** (the Ruben repair audit row only)
- policy events: **0**
- max `aos_llamadas.id`: **38397**
- Agenda rows: **3152**
- post-baseline genuine V2.2 operations: **0 / 5**

For terminal certification, count only genuine customer actions with `created_at > 2026-08-22T01:17:57.749075+00:00`. Exclude any repair/test/admin key, including `repair-ruben-997883711-20260821-193506`.

## Gate
The next genuine action after the V2.2 baseline is the new controlled canary. If it fails semantics/cardinality/direct-links/ownership/idempotency, STOP Loop 6 again. If it passes, continue ordinary use until >=5 genuine V2.2 operations exist, then execute terminal certification. Loop 7 remains NOT STARTED.
