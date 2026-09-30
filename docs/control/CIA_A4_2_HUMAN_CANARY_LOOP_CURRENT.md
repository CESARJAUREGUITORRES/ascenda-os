# CIA A4.2 — Human Canary Loop CURRENT

Date: 2026-09-30
Base main: `013661a8705d11b05e8b4cd03192b0ad3eca875e`
Supabase project: `ituyqwstonmhnfshnaqz`
Live migration: `20260930221624_cia_a4_2_human_canary_critical_lane_v1`

## Goal

Certify Audience -> Distribution -> one-advisor Call Center consumption without enabling mass distribution or mutating patient/appointment truth to manufacture a PASS.

## L0 — Critical-lane stabilization

Observed production failures:
- `/api/callcenter/rpc` returned HTTP 500.
- Supabase/PostgREST evidence: SQLSTATE `57014` / statement timeout.
- Critical RPC affected: `aos_callcenter_prepare_action_v1`.
- Same pressure also hit `aos_get_historial_paciente` and `aos_panel_asesor`.

Mitigation:
- bounded function-local `statement_timeout=10s` on exactly those three RPCs.
- Railway bridge remains 12s and browser bridge remains 15s.
- no global timeout change.
- no business-data write.

Rollback:
```sql
alter function public.aos_callcenter_prepare_action_v1(text,text) reset statement_timeout;
alter function public.aos_get_historial_paciente(text) reset statement_timeout;
alter function public.aos_panel_asesor(text,text,text,text) reset statement_timeout;
```

## L1 — Negative WEB canary

Audience: `WEB_BOOKINGS`.

Current expected live result for the existing WEB contact:
- audience_count = 1
- assignable_now = 0
- blocked reasons include `CALLED_TODAY`, `FUTURE_APPOINTMENT`, `LEGACY_WORK_IN_PROGRESS`
- `START_CANARY_ASSIGNMENT` must return `CANARY_NO_ASSIGNABLE_CONTACTS`
- global routing must remain OFF
- no plan may remain open

PASS means the system refuses unsafe reassignment.

## L2 — Positive one-contact human canary

Preconditions:
1. ADMIN session with PASSWORD_2FA and `admin-calls`.
2. Select exactly one active advisor with `advisor-calls`.
3. Source audience has at least one legitimately assignable contact.
4. global routing baseline OFF.
5. no DRAFT/ACTIVE/PAUSED canary plan exists.

Human flow:
1. Llamadas -> Audiencias.
2. Choose an audience and press `Usar audiencia`.
3. Distribución -> select one advisor.
4. `Simular distribución`.
5. Confirm `assignable_now >= 1`, projected quantity = 1.
6. Press `Probar con 1 contacto`.
7. Open Call Center as the selected advisor.
8. Verify exactly one V3_CANARY assignment appears.
9. Open contact; patient/history/advisor hydration must complete without 500.
10. Perform only the intended human test action.
11. Read back assignment/plan/activation state.
12. Stop/revert canary; confirm global routing OFF and advisor route cleared.

## Release gates

- `START_DISTRIBUTION` remains absent/disabled.
- CALL release state remains `HUMAN_CANARY_REQUIRED`, `execution_enabled=false`.
- Email and WhatsApp distribution remain unchanged.
- Positive canary PASS does not itself authorize mass distribution; A4.3 must explicitly advance release state after evidence review.

## PASS evidence

Required:
- no 500 on critical Call Center RPC during the canary;
- exactly one assignment;
- correct advisor;
- no duplicate work;
- no future-appointment conflict;
- canary reversible;
- post-stop routing global OFF;
- zero unintended open plans.
