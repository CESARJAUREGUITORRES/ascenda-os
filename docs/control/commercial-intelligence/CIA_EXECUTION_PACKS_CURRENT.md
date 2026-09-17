# CIA V3 — Autonomous Execution Packs CURRENT

**Captured:** 2026-09-16 America/Lima  
**Product:** ASCENDA CLINIC / ASCENDA OS  
**Workstream:** Commercial Intelligence & Audience OS V3  
**Current control state:** `PACK-A CLOSED · STOP BEFORE PACK-B`  
**Authoritative PACK-A evidence:** `docs/control/commercial-intelligence/CIA_PACK_A_CLOSEOUT_20260916.md`  
**Owner authorization:** finish Foundation & Live Reconciliation, freeze the exact PACK-B delta, and stop before PACK-B implementation.

## Decision

Do **not** execute F1→F10 as ten separate conversational phases.

Use **4 macro-loops** with **3 human canary gates**:

1. **PACK-A · Foundation & Live Reconciliation** → planned F1–F3 · **CLOSED**
2. **PACK-B · Audience Control Center + Call Center** → planned F4–F5 · **NOT STARTED**
3. **PACK-C · Channel Activation Plane** → planned F6–F8 · **BLOCKED BY PACK-B**
4. **PACK-D · Outcomes, Intelligence & Production Certification** → planned F9–F10 · **BLOCKED BY PACK-C**

The assistant may execute substeps inside an explicitly active pack autonomously while invariants remain green. Stop when:
- the active pack reaches its defined stop boundary;
- a human UX/workflow canary is explicitly required;
- a destructive/high-risk data decision requires owner choice;
- a dependency owned by another workstream is not production-ready;
- an invariant fails and safe repair is not deterministic.

**Control correction:** the earlier instruction to continue automatically from PACK-A into PACK-B is superseded. PACK-B requires an explicit next-pack start from the owner.

## PACK-A — Foundation & Live Reconciliation

**Status:** `CLOSED · PASS WITH EXPLICIT PACK-B PREREQUISITES`

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

### Closeout evidence

PACK-A reconciled `main@ed20fab28ddebf917a9de660dacb2cbf14daaedb` against Supabase production and Railway production.

Key findings frozen in `CIA_PACK_A_CLOSEOUT_20260916.md`:
- canonical commercial population: **13,238 contacts**;
- governed filter registry: **73/73 complete**, no missing mappings/sources/type/operator gaps;
- existing audience presets: **10**, validating/resolving at observation time;
- segmentation runtime cache is stale/drifted and must be repaired before fresh tier/lifecycle assignment claims;
- current Call Center still depends on legacy `tipo_cola` / Global Logic compatibility;
- direct browser mutation of `aos_cola_config` plus broad compatibility RLS must be migrated through a governed gateway before hardening;
- resolver performance requires bounded interactive UX and optimization rather than timeout inflation;
- Email remains reusable at its certified boundary; WhatsApp live CIA activation remains fail-closed until its separate transport/canary readiness is certified.

### PACK-B prerequisites frozen by PACK-A

- **P1 · Segment freshness:** repair/refresh segment runtime cache and prove coverage/parity.
- **P2 · Queue governance:** introduce governed `aos_cola_config` mutation gateway → migrate UI → smoke → then harden RLS.
- **P3 · Resolver UX/performance:** bounded pages + debounce/single-flight/cancellation and benchmark/optimize as required.

### No human canary required
PACK-A was read-only/reconciliation plus control documentation. Production mutation residue = **0**.

### Exit gate
- current-state map complete: **PASS**;
- identity authority confirmed: **PASS**;
- filter dictionary complete: **PASS · 73/73**;
- channel/readiness boundary freshly known: **PASS / bounded**;
- exact implementation delta for PACK-B frozen: **PASS**;
- PACK-A checkpoint committed: **PASS**.

## PACK-B — Audience Control Center + Call Center

**Status:** `NOT STARTED · REQUIRES EXPLICIT OWNER START · P1/P2/P3 FIRST`

### Includes
- execute P1/P2/P3 prerequisites from PACK-A before broad UI rollout;
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

### Mandatory compatibility rule
Global Logic / legacy queue behavior remains a reversible fallback until governed assignment parity is proven. Do not revoke the current direct-write compatibility path before the governed queue-config gateway has replaced it and passed smoke.

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
If CIA/WhatsApp production readiness still has unresolved webhook/canary blockers:
- build and certify the audience/activation bridge in fail-closed mode;
- do not claim live WhatsApp sending certified;
- Email may still certify independently at its demonstrated governed boundary.

### Human Canary #2
Use one small governed audience:
- Email activation;
- WhatsApp activation only if current live transport readiness is certified.

Verify recipient population, exclusions, no duplicates, canonical identities and activation ledger.

### Exit gate
Email bridge PASS; WhatsApp bridge PASS or explicitly READY-BUT-BLOCKED by external transport gate.

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

The target product validation remains three meaningful owner canaries:

1. after PACK-B: Audience + Call Center canary;
2. after PACK-C: Email/WhatsApp activation canary;
3. after PACK-D: final multichannel commercial canary.

Pack transitions themselves follow the current owner scope. PACK-A is closed and the current scope stops before PACK-B.

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
- WhatsApp Hub / Conversations remains a separate transport/conversation workstream; CIA consumes only its certified bridge;
- Email transactional appointment mail remains separate from Email Marketing.

## Immediate next action

**STOP at PACK-A closeout.**  
Do not implement PACK-B from this checkpoint until the owner explicitly starts PACK-B.  
When started, execute **P1 → P2 → P3** first, then build the Audience Control Center and stop at Human Canary #1.