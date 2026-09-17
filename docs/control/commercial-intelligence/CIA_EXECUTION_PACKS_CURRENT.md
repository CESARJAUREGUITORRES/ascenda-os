# CIA V3 — Autonomous Execution Packs CURRENT

**Captured:** 2026-09-16 America/Lima  
**Product:** ASCENDA CLINIC / ASCENDA OS  
**Workstream:** Commercial Intelligence & Audience OS V3  
**Owner authorization:** group the ten planned CIA panel phases into autonomous execution loops, stopping only at meaningful human-canary gates.

## Decision

Do **not** execute F1→F10 as ten separate conversational phases.

Use **4 macro-loops** with **3 human canary gates**:

1. **PACK-A · Foundation & Live Reconciliation** → planned F1–F3
2. **PACK-B · Audience Control Center + Call Center** → planned F4–F5
3. **PACK-C · Channel Activation Plane** → planned F6–F8
4. **PACK-D · Outcomes, Intelligence & Production Certification** → planned F9–F10

The assistant may execute all substeps inside each pack autonomously while invariants remain green. Stop only when:
- a human UX/workflow canary is explicitly required,
- a destructive/high-risk data decision requires owner choice,
- a dependency owned by another workstream is not production-ready,
- an invariant fails and safe repair is not deterministic.

## PACK-A — Foundation & Live Reconciliation

### Includes
- inventory live Supabase CIA tables/RPCs/readiness;
- inventory current Panel Central / Gestión de Bases frontend;
- reconcile August F0–F18 docs against September production drift;
- verify canonical commercial identity and WhatsApp contact identity bridge;
- verify commercial fact sources/provenance;
- compile governed filter dictionary for campaigns, calls, appointments, purchases, products/services, debt, recurrence, tier, recency, geography and channel eligibility;
- classify every existing component as:
  - REUSE
  - REPAIR
  - LEGACY
  - MISSING
- freeze Audience/Activation/Assignment contracts before frontend mutation.

### No human canary required
This pack is primarily read-only/reconciliation plus additive contracts/tests.

### Exit gate
- current-state map complete;
- identity authority confirmed;
- filter dictionary complete;
- F17/F18 readiness freshly known;
- exact implementation delta for PACK-B approved by invariants.

## PACK-B — Audience Control Center + Call Center

### Includes
- Audience Builder V2;
- reusable Audience Library;
- live vs snapshot semantics;
- preview counts + included/excluded reasons;
- save/version/reopen;
- strategy definitions;
- current Global Logic migration into explicit strategy rules;
- assignment by advisor/team;
- capacity / lease / top-up / priority;
- advisor Call Center consumption;
- preserve acquisition/reactivation/follow-up/direct-appointment distinctions;
- modern responsive admin UX replacing the rigid Gestión de Bases modal while preserving safe compatibility.

### Human Canary #1
Owner creates one controlled audience and assigns it to one advisor.

Verify:
- preview population is correct;
- save/reopen is deterministic;
- assignment does not duplicate source contacts;
- advisor sees exactly assigned work;
- Global Logic still functions for unassigned/default workload;
- outcomes return to the canonical ledger.

### Exit gate
Call Center audience control = HUMAN PASS.

## PACK-C — Channel Activation Plane

### Includes
- Email Audience Bridge;
- WhatsApp Audience Bridge;
- shared activation contract;
- channel eligibility/context;
- email consent/suppression preflight;
- WhatsApp canonical phone/contact identity;
- approved-template eligibility;
- activation snapshots;
- idempotency/dedupe;
- multichannel sequencing rules;
- KronIA proposals for audience/channel strategy;
- no autonomous send authority for KronIA.

### Important dependency rule
If CIA-F17 WhatsApp production readiness still has unresolved webhook/canary blockers:
- build and certify the audience/activation bridge in fail-closed mode;
- do not claim live WhatsApp sending certified;
- Email may still certify independently because F16 was historically production-certified.

### Human Canary #2
Use one small governed audience:
- Email activation;
- WhatsApp activation only if F17 live readiness is certified.

Verify recipient population, exclusions, no duplicates, canonical identities and activation ledger.

### Exit gate
Email bridge PASS; WhatsApp bridge PASS or explicitly READY-BUT-BLOCKED by external F17 transport gate.

## PACK-D — Outcomes, Intelligence & Production Certification

### Includes
- outcome reconciliation across Call Center / Email / WhatsApp;
- attribution by audience + activation + channel;
- acquisition vs reactivation preserved;
- appointments/attendance/sales/revenue linkage;
- Intelligence dashboards;
- KronIA recommendations with confidence/freshness/provenance;
- multichannel performance;
- replay/idempotency checks;
- rollback;
- load/polling/performance checks;
- documentation, agent memory and release checkpoint.

### Human Canary #3 — Final
Controlled end-to-end commercial experiment:
- one saved audience;
- one Call Center assignment;
- one Email activation;
- one WhatsApp activation if transport certified;
- observe appointment/sale/outcome;
- verify attribution returns to the same Audience/Activation truth.

### Exit gate
CIA Audience Control Center = PRODUCTION READY.

## Execution discipline inside every pack

For HIGH/CRITICAL mutations:

`OBSERVE LIVE → PREVIEW EXACT DELTA → CONTRACT TEST → DRY-RUN/TRANSACTION → APPLY ONLY GAP → READBACK → INVARIANT QUERY → IDEMPOTENT REPLAY → DEPLOY EXACT SHA → SMOKE → CHECKPOINT`

No intermediate conversational status is required unless a stop condition occurs.

## Human interaction budget

Instead of ten phase-by-phase approvals, target only **3 owner interactions**:

1. after PACK-B: Audience + Call Center canary;
2. after PACK-C: Email/WhatsApp activation canary;
3. after PACK-D: final multichannel commercial canary.

PACK-A is autonomous.

## Non-negotiable invariants

- one canonical contact identity;
- one canonical Audience/Activation truth;
- no per-channel duplicate customer tables;
- no direct browser sends bypassing governed channel authority;
- no unsafe mass rewrite of historical source/origin;
- no clinical free-text exposure in commercial segmentation;
- no advisor assignment duplication;
- no silent UNKNOWN activation;
- no polling/query storm regressions;
- WhatsApp Hub remains a separate transport/conversation workstream; CIA consumes its certified bridge;
- Email transactional appointment mail remains separate from Email Marketing.

## Immediate next action

Run **PACK-A** autonomously.  
If PACK-A invariants are green, proceed directly into **PACK-B implementation** without asking the owner again.  
Stop at **Human Canary #1** with the new Audience Control Center ready for owner/admin validation.
