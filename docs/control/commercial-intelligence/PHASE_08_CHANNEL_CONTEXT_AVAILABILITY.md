# ASCENDA OS — FASE 8
## Channel Context & Availability

**Estado:** IN_PROGRESS  
**Fecha:** 2026-08-13  
**Baseline staging:** `6a422bfffcaaef610820633b50b6d2bf6c8e6429`  
**Rama:** `feature/cia-phase8-channel-context-availability`  
**Supabase:** `ituyqwstonmhnfshnaqz`

---

# 1. OBJETIVO

Convertir una Activation de Fase 7 en un universo contextual explicable:

`Audience Total → Eligible for Context → Available Now`

sin crear Assignment, sin ejecutar canales, sin modificar `aos_siguiente_lead`, `aos_cola_config`, `calls.js`, Email legacy ni fuentes operativas.

Fase 9 solo podrá consumir contactos cuyo resultado Phase 8 sea `AVAILABLE` bajo una policy fijada y versionada.

---

# 2. FRONTERAS

- Audience = definición / membership.
- Snapshot = membership congelada.
- Activation = uso trazable y versión fijada.
- Eligibility = aptitud estable según canal/policy.
- Availability = aptitud temporal "ahora".
- Assignment = fuera de Fase 8.
- Channel execution = fuera de Fase 8.

Una exclusión del Call Center legacy NO se convierte automáticamente en prohibición universal.

---

# 3. BASELINE LIVE

Al inicio de Fase 8:
- Identity/Profile universe: 11,520 contactos.
- phone_valid: 11,520.
- email_valid: 1,579.
- identity_conflict: 23.
- called_today: 342.
- future appointment: 62.
- legacy leads in progress today: 335.
- pending followup: 16.
- overdue followup: 442.
- latest `NO LE INTERESA/SACAR DE LA BASE`: 2,164.
- latest `PROVINCIA/PROVINCIAS`: 183.

Current `aos_siguiente_lead` uses queue-specific exclusions including called-today, pending appointment, legacy in-progress and selected historical call statuses. Dedicated province queue proves `PROVINCIA` is context-specific, not universal.

---

# 4. POLICY MODEL V1

Create a versioned registry `aos_cia_context_policies`.

Initial policies:
- `CALL_GENERAL`
- `CALL_PROVINCE`
- `EMAIL_GENERAL`
- `SMS_GENERAL`
- `WHATSAPP_GENERAL`
- `ANALYSIS_GENERAL`
- `AUTOMATION_GENERAL`
- `OTHER_GENERAL`

Policy is immutable after activation binding. New business rules create a new version.

## CALL_GENERAL
Eligibility blockers:
- invalid phone;
- current lifecycle `DISQUALIFIED_PROSPECT`;
- current province route (`latest_call_status PROVINCIA/PROVINCIAS`).

Availability blockers:
- called today;
- future pending/confirmed appointment;
- legacy `aos_leads_en_curso` today.

Warnings only:
- identity conflict;
- known email activity today.

## CALL_PROVINCE
Eligibility:
- valid phone;
- current latest call status must be `PROVINCIA/PROVINCIAS`.
Availability blockers identical to CALL_GENERAL.

## EMAIL_GENERAL
Eligibility blockers:
- canonical email absent/invalid;
- email identity confidence not `MEDIUM`.
Availability blocker:
- email already sent today.
Historical bounce is advisory in V1 because facts do not prove that a historic bounce is still the current deliverability state.

## SMS / WHATSAPP
Eligibility can resolve from phone.
Availability = `UNKNOWN` in V1 with reason `CHANNEL_HISTORY_NOT_INTEGRATED` because outbound channel history is not yet integrated. Fase 9 must not assign UNKNOWN rows as AVAILABLE.

## ANALYSIS / AUTOMATION / OTHER
Non-contact context V1: no channel reachability blocker; availability follows membership and returns AVAILABLE unless a future policy says otherwise.

---

# 5. DECISION MODEL

Per contact:
- `eligibility_status`: `ELIGIBLE | INELIGIBLE | UNKNOWN`
- `availability_status`: `AVAILABLE | UNAVAILABLE | UNKNOWN`
- `is_assignable`: true only when both are positive and activation state permits downstream use.
- `reasons[]`: ordered structured reason codes.
- `warnings[]`: non-blocking evidence.

Reason code examples:
- `PHONE_INVALID`
- `EMAIL_INVALID`
- `EMAIL_IDENTITY_UNKNOWN`
- `CURRENTLY_DISQUALIFIED`
- `CURRENT_PROVINCE_ROUTE`
- `NOT_PROVINCE_ROUTE`
- `CALLED_TODAY`
- `EMAIL_SENT_TODAY`
- `FUTURE_APPOINTMENT`
- `LEGACY_WORK_IN_PROGRESS`
- `CHANNEL_HISTORY_NOT_INTEGRATED`
- `IDENTITY_CONFLICT`
- `EMAIL_BOUNCE_HISTORY`

UNKNOWN never silently becomes AVAILABLE.

---

# 6. ACTIVATION POLICY BINDING

Add one immutable 1:1 context binding per activation:
- activation_id
- policy_key
- policy_version
- bound_at
- bound_by_user_id

Binding is explicit and frozen. Policy changes later do not rewrite historical activations.

Activation created in Fase 7 remains valid without binding, but Phase 8 summary returns `CONTEXT_NOT_BOUND` until the admin binds a policy. Frontend should bind the channel default after activation creation or allow an explicit compatible policy.

---

# 7. READ CONTRACTS

Phase 8 exposes:
- context policy list;
- bind activation context;
- activation context summary;
- availability preview (max 100);
- contact availability explain;
- available contact-key set for Phase 9.

Summary fields:
- audience_total
- eligible
- ineligible
- eligibility_unknown
- available_now
- unavailable_now
- availability_unknown
- reason_counts
- policy key/version
- membership mode
- facts freshness / evaluated_at

For BATCH, audience_total comes from frozen snapshot membership.
For DYNAMIC, it comes from the fixed audience version resolved live.

---

# 8. PERFORMANCE

Targets:
- summary normal <1.5 s warm/representative;
- preview 50 <2.5 s;
- explain <1.5 s;
- no new indexes/triggers on operational write paths unless benchmark proves necessity and Call Center insert is retested.

---

# 9. SECURITY

- RLS on new persistence objects.
- no permissive browser policies.
- mutators verify CIA admin token internally.
- browser consumes Phase 8 gateway only.
- no raw SQL or arbitrary policy expressions from UI/AI.
- policy rules stored as controlled configuration interpreted by hardcoded evaluator.

---

# 10. IMPACT REPORT

**Risk:** HIGH, additive.

Touches:
- new policy/binding objects;
- new read evaluators/gateway;
- Phase 7 admin frontend to display contextual counts and bind policy.

Does NOT touch:
- `aos_siguiente_lead` / V2;
- `aos_cola_config`;
- `aos_leads_en_curso` writes;
- Call Center saving;
- Agenda/Ventas/CRM writes;
- Email legacy FK/tables;
- Assignment tables (not created yet).

Rollback:
1. disable/remove Phase 8 UI entry/use;
2. retain additive policy/binding data inactive;
3. Phase 7 activation continues functioning independently;
4. Call Center remains on V2 legacy path untouched.

---

# 11. GATES

- P8-G01 baseline / Phase 7 continuity
- P8-G02 Impact Report pre-DDL
- P8-G03 policy registry / versioning
- P8-G04 activation context binding
- P8-G05 deterministic eligibility
- P8-G06 deterministic availability
- P8-G07 reason taxonomy / explain
- P8-G08 BATCH membership parity
- P8-G09 DYNAMIC membership parity
- P8-G10 UNKNOWN semantics
- P8-G11 security / RLS / gateway
- P8-G12 frontend / responsive contract
- P8-G13 performance
- P8-G14 Call Center / Email compatibility
- P8-G15 QA / no residue
- P8-G16 replayability + CI + PR
- P8-G17 staging post-merge
- P8-G18 roadmap + `aos_memory`

Fase 8 solo será `100_COMPLETE` con P8-G01…P8-G18 PASS.
