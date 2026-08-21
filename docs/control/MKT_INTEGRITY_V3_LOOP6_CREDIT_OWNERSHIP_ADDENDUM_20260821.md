# MKT-INTEGRITY-HOTFIX-V3 — Loop 6 Credit / Ownership Addendum

**Base exact-head:** `933c3b0f2c4cfba504e584d4406922505917024e`  
**Branch:** `feat/mkt-loop6-credit-ownership-rules-v2`  
**Lock:** `MKT-INTEGRITY-HOTFIX-V3`  
**Loop 7:** NOT STARTED

## Why this addendum exists
The first Loop 6 deploy introduced explicit Call Center semantics, atomic Call↔Agenda persistence, idempotency and F6 patient-state. Before the first genuine production journal action occurred, the owner froze additional business-credit rules. The production journal was still `0`, so the rules can be hardened without reclassifying any Loop 6 v1 action.

## Frozen rules
1. **Converted-patient reactivation eligibility:** commercial Reactivation credit is allowed only when at least **15 full days** have elapsed since the latest qualifying prior event: sale, clinical attention, or ASISTIO/ASISTIÓ/EFECTIVA appointment. Business clock: `America/Lima`.
2. **Early reactivation (<15 days):** preserve real work and Agenda, but no new commercial appointment credit. Beneficiary scope is `CLINIC`; execution remains attributable to the logged-in advisor.
3. **NO ASISTIO ownership:** a non-converted prospect with a prior NO ASISTIO appointment remains protected for the original advisor for **72 hours from the original appointment slot**.
4. **Rescue during protected window:** another advisor may help and create the replacement Agenda, but the Agenda remains assigned to the original advisor; the helper execution is auditable and does not create a second commercial appointment.
5. **Recovery after 72h:** if a different advisor truly contacts the prospect after the 72h window and there is **no system-recorded follow-up by the original advisor after the missed slot**, the new advisor may receive the new commercial call+cita credit and ownership transfer.
6. **Original-advisor rebooking:** the original advisor keeps ownership but does not receive a second conversion for the same missed opportunity merely by rebooking it.
7. **Active appointment duplicate protection:** a current/future `PENDIENTE` or `CITA CONFIRMADA` Agenda row blocks a second commercial conversion and surfaces advisor/date/time context.
8. **Callback / follow-up conversion:** UI can stay simple, but server semantics distinguish actual `CALLBACK_INBOUND` from `FOLLOWUP_CONVERSION` when the conversion came from a recorded follow-up flow.
9. **SOLO_AGENDAR:** Agenda only, zero commercial cita credit, with execution trace.
10. **Server authority:** browser selection is intent only. The server may block or downgrade an ineligible credit request and must audit the decision.

## Data model
Loop 6 journal remains the committed-action ledger. It will add explicit fields for:
- `credited_advisor`, `credited_advisor_id`;
- `commercial_owner`, `commercial_owner_id`;
- `beneficiary_scope` (`ADVISOR` / `CLINIC`);
- `eligibility_status`, `eligibility_reason`;
- `prior_agenda_id`, `prior_advisor`, `prior_advisor_id`;
- `ownership_transfer`;
- `rule_context` JSONB.

A separate append-only `aos_callcenter_policy_events_v1` records blocked/downgraded policy decisions, including misuse attempts, without fabricating business calls or Agendas.

## KPI treatment
- Eligible new prospect / eligible recovery / eligible reactivation: call row `estado='CITA CONFIRMADA'` so it counts as commercial cita; Reactivation uses `tipo_gestion='REACTIVACION'` and no Marketing acquisition lead.
- Early reactivation / protected rescue / original-owner rebooking: call row may remain a real `SEGUIMIENTO` activity under the executing advisor, but it does **not** create a second `CITA CONFIRMADA`; replacement Agenda may be assigned to the protected commercial owner.
- Agenda-only: no call row.

This preserves workload trace while preventing commercial-cita inflation.

## Follow-up evidence
For the 72h transfer rule, only **system-recorded** evidence is authoritative. A prior-owner follow-up is present when, after the missed appointment slot and before the recovery event, either:
- `aos_llamadas` contains a later call for the same phone by the original advisor; or
- `aos_seguimientos` contains a created/updated record for the same phone and original advisor after that slot.
Off-app activity that is not recorded cannot be inferred.

## Safety gates
- Current production journal must still be 0 before apply.
- Existing repaired calls `36701,37185,37813,38012,38168,38186` and direct-links remain protected.
- Removed Alberto/Alan duplicates must remain absent.
- REV-F5 remains `6 / 15498 / 8716 / 15498 / 8716 / 230`.
- F6 private grants remain unchanged.
- Dedicated rollback canaries must cover: ≥15d, <15d, NO ASISTIO <72h, >72h no follow-up, >72h with owner follow-up, original-owner rebooking, active appointment duplicate, callback/followup conversion, Agenda-only, and attempted misuse.

No Loop 6 PASS may be declared until this addendum is implemented, deployed, and the real-operation gate is re-run under these rules.
