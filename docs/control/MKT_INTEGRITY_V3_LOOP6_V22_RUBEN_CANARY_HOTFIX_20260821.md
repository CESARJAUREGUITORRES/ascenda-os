# MKT-INTEGRITY-V3 · Loop 6 V2.2 — first real canary hotfix

## Incident
First genuine post-baseline operation failed the governed runtime path.

Ruben Carlos Dominguez Munoz / `997883711`:
- Marketing lead `5884`, CAPILAR, unique prior touchpoint;
- Mireya SEGUIMIENTO call `38301` at 18:23:41 Lima;
- Agenda `2c581c52-89e9-465f-89be-0e3818eda309` created 19:35:06 Lima for 2026-08-25 18:00;
- legacy `CITA_MANUAL`, initially `lead_id_origen=NULL`, `llamada_id_origen=NULL`;
- no Loop6 journal/policy row at incident time.

Strong evidence: no prior sale, clinical attention or ASISTIO/EFECTIVA. Correct semantic = `FOLLOWUP_CONVERSION / MARKETING / lead 5884 / +1 call +1 cita / MIREYA`.

Three additional legacy-unlinked Agenda rows were found after the old baseline:
- `7d530a24-fe05-43bc-b7ab-a83428050532` / 928017492 / WILMER — converted patient; no contemporary call evidence, no automatic credit granted;
- `dc99e863-1e97-49e3-8000-cc420b71bc8a` / 995558890 / WILMER — converted patient; no contemporary call evidence, no automatic credit granted;
- `92949454-4c1e-4273-bb7c-9b2b9288e0b2` / 980749071 / WILMER — converted patient with qualifying activity 17/08 (<15d), no new commercial credit permitted.

## Root cause / containment
Production retained legacy Call Center save functions and the loader cache key remained `calls-loop6.js?v=20260821-loop6`. In an SPA/stale-runtime condition a legacy function could persist directly outside `aos_callcenter_commit_action_v1`. The runtime also had an early-return build guard that could prevent re-arming overrides after panel reinjection.

V2.2 containment:
1. DB BEFORE INSERT guards reject non-governed `CITA CONFIRMADA` call writes.
2. DB BEFORE INSERT guards reject non-governed `CITA_MANUAL` and `CALL_CENTER*` Agenda writes.
3. canonical core sets transaction-local `aos.loop6_governed_write=1` before calling V2 implementation.
4. frontend loader cache key becomes `calls-loop6.js?v=20260821-loop6-v2.2`.
5. runtime build marker becomes `v2.2` and unsafe SPA early-return is removed.
6. legacy `ccConfirmarCita()` and `guardarCitaManual()` are fail-closed unless exact runtime v2.2 is active.

Rollback canary after LIVE DB apply:
- direct legacy commercial Call rows = 0;
- direct legacy CITA_MANUAL Agenda rows = 0;
- governed core = journal 1 / Call 1 / Agenda 1.
All synthetic rows rolled back.

## Ruben repair
Deterministic repair applied after exact precondition checks:
- Call `38384` = `CITA CONFIRMADA / FOLLOWUP_CONVERSION / MARKETING / lead 5884 / MIREYA`;
- Agenda `2c581c52-89e9-465f-89be-0e3818eda309` now links `lead_id_origen=5884`, `llamada_id_origen=38384`, `origen_cita=CALL_CENTER`;
- Seguimiento `SEG-1787354621097-4zle` = COMPLETADO and linked to lead 5884;
- journal key `repair-ruben-997883711-20260821-193506` = COMPLETE, creditedAdvisor MIREYA;
- post-repair panel snapshot: Mireya 151 calls / 3 citas (call total is dynamic due concurrent advisor activity; cita delta is the repaired business invariant).

Loop 6 remains BLOCKED until V2.2 frontend deploy is exact-commit SUCCESS, stale-client canary passes, invariants are re-read, and a fresh genuine-operation baseline is captured. Loop 7 NOT STARTED.
