# CIA V3 — Resumption Checkpoint after Agenda V3 closeout

**Captured:** 2026-09-16 America/Lima  
**Workstream:** Commercial Intelligence & Audience OS V3  
**Target product identity:** ASCENDA CLINIC  
**Technical runtime:** ASCENDA OS  
**Production Supabase:** `ituyqwstonmhnfshnaqz`

## Why this checkpoint exists

Agenda V3, Patient 360, advisor/web attribution, Coordination reporting and the public website handoff were stabilized immediately before resuming the audience/database control-plane work.

The next product work is the specialized admin panel for commercial audiences and databases used by Call Center and Email. Do not rebuild this program from scratch. Resume from the canonical CIA V3 architecture and reuse the certified Agenda/identity lessons below.

## Existing CIA V3 product contract

Canonical pipeline:

`Source Data → Identity Resolution → Commercial Facts → Segmentation → Audience Engine → Context/Eligibility → Activation → Assignment → Advisor Work → Request/Approval → Commercial Intelligence → KronIA → Channel Adapters → Outcomes/Attribution`

Stable capabilities already closed historically:
- F1 Identity Resolver
- F2 Commercial Facts
- F3 Segmentation Engine
- F4 Audience Resolver
- F5 Panel Central Skeleton
- F6 Audience Library Persistence
- F7 Snapshots & Activation
- F8 Channel Context & Availability
- F9 Assignment Engine
- F10 Advisor Control Center
- F11 Call Center Integration V3
- F12 Advisor Work Views
- F13 Requests & Approval Engine
- F14 Commercial Intelligence Shadow
- F15 KronIA + Multiagent Orchestration
- F16 Email Integration — production certified

Historical current control still marks CIA-F17 Multichannel incomplete and CIA-F18 blocked. Revalidate production readiness before reopening those phases.

## Product intent for the panel

The panel is admin-governed commercial intelligence, not a spreadsheet viewer.

It must let the administrator:
- see and manage reusable audiences across Call Center, Email, WhatsApp/SMS/future channels;
- build segments from canonical commercial identity/facts;
- distinguish leads, prospects, patients and historical customers without redefining clinical identity;
- work with never-worked / pending / reactivation / follow-up / appointment-related populations;
- segment by product/service interest, commercial history and governed customer tier when available;
- save reusable audiences and snapshots;
- preview exact population/count before activation;
- choose purpose/channel only after audience definition;
- assign work to advisors with capacity/lease/top-up logic;
- monitor outcomes and attribution without inflating acquisition;
- allow advisor requests/changes only through governed request/approval; admin remains final authority.

## Source-of-truth rules

1. One canonical audience truth. Never create separate “Email audience”, “Call Center audience” or “WhatsApp customer” tables.
2. Operational source rows stay intact. CIA resolves/aggregates/versions; it does not move data out of source systems.
3. Patient/customer identity must reuse the governed identity layer. Same name or same phone alone never authorizes a merge.
4. Call Center semantics remain explicit:
   - new lead / acquisition
   - reactivation
   - patient follow-up
   - direct appointment
   These states must not be collapsed into one “conversion” metric.
5. Email marketing remains governed through Audience/Activation and consent/suppression checks. Transactional appointment email is a separate operational flow.
6. Commercial features must not expose ordinary clinical free text, diagnoses, clinical photos, prescriptions or full medical-history content.

## Reusable lessons from Agenda V3 / September 2026

### A. Attribution must be human-readable and canonical
Agenda proved the correct pattern:
- technical identifiers stay in canonical columns;
- human UI resolves names/labels;
- WEB organic has no advisor owner;
- ADVISOR_LINK retains canonical advisor identity but displays the human name;
- channel/source and owner are separate dimensions.

CIA should use the same principle for campaigns, lists, assignments and outcomes:
`canonical id internally → friendly label in UI`.

### B. One ledger / one authority
Agenda succeeded because every entry point wrote to the same `aos_agenda_citas` authority and all downstream effects observed that ledger.

CIA must preserve the equivalent principle:
- one Audience/Activation truth;
- Call Center and Email consume it;
- no channel-specific duplicate segmentation engine.

### C. Side effects should observe canonical events, not individual screens
The automatic Coordination appointment report works because it observes the canonical appointment ledger rather than each UI.

For CIA:
- outcome/attribution facts should be produced from governed execution/outcome events;
- do not patch each channel UI independently to create commercial truth.

### D. Presentation is not authority
Agenda V3 could be completely redesigned without breaking booking because UI and core were separated.

The Audience panel should similarly separate:
- admin UX / filters / visualizations;
- deterministic segmentation/eligibility RPCs;
- activation and approval authority;
- channel adapters.

### E. Fail closed, explain clearly
Unknown identity, missing consent, stale evidence or unavailable channel must not silently activate.
The UI should show why a contact/population is excluded.

### F. Preserve distinctions instead of overwriting source data
Do not mass-rewrite `origen`, lifecycle or acquisition fields to make reports look cleaner.
Create derived facts/classifications with provenance and confidence.

### G. Controlled data-change loop
For HIGH/CRITICAL audience/data changes use:
`OBSERVE LIVE → PREVIEW EXACT DELTA → TRANSACTION/DRY-RUN → MUTATE ONLY GAP → READBACK → INVARIANT QUERY → IDEMPOTENT REPLAY → CHECKPOINT`.

### H. Avoid UI polling/load regressions
Previous Home/Admin pressure showed retry/poll storms can overload the app.
The new panel should use lazy loading, scoped queries, pagination, debounced search and single-flight requests rather than repeated broad reads.

## UX direction for the Audience / Database panel

Recommended information architecture for the existing CIA product, without changing its data authority:

### 1. Overview
- total canonical contacts
- active reusable audiences
- assigned / pending work
- activation by channel
- recent outcomes
- data-quality / identity conflicts
- suppression/consent warnings

### 2. Audience Builder
- source population
- deterministic filters
- estimated count
- included/excluded reasons
- save audience
- snapshot/version
- no channel selection required until audience is defined

### 3. Audience Library
- reusable saved audiences
- owner / created date / version
- live vs snapshot
- last activation
- channel availability
- outcome summary

### 4. Call Center
- audience → advisor assignment
- capacity / lease / top-up
- new lead vs reactivation vs follow-up vs direct appointment semantics
- advisor work views
- outcome tracking

### 5. Email
- choose certified audience/activation
- consent + suppression preflight
- template/campaign context
- preview
- governed send request
- delivery/outcome reconciliation
- never bypass F16 authority with direct browser sends

### 6. Data Explorer / Identity
- search canonical commercial contact
- provenance of source systems
- aliases/identifiers
- conflict state
- commercial 360 summary
- no unsafe patient merge from this panel

### 7. Requests & Approval
- advisor requests
- proposed audience changes
- activation requests
- admin approve/reject
- audit trail

### 8. Intelligence
- channel-neutral outcomes
- conversion by audience/campaign/source
- acquisition vs reactivation separated
- confidence/freshness/provenance
- recommendations remain proposals, never autonomous authority

## Immediate resumption protocol

Before writing new CIA code:
1. re-read `AGENTS.md`;
2. read `CIA_AGENT_BOOTSTRAP_CURRENT.md`;
3. read `CIA_MASTER_ALIGNMENT_CURRENT.md`;
4. query production CIA readiness RPCs fresh;
5. inventory current live CIA tables/RPCs and current Panel Central frontend;
6. reconcile old August roadmap state with September runtime drift;
7. decide whether the next loop is:
   - panel/UX modernization over already-certified F5–F16 contracts, or
   - formal CIA-F17 closeout;
8. acquire/update the global workstream lock before HIGH/CRITICAL mutations.

## Project isolation

Do not mix this with:
- ASCENDA SOFTY
- ASCENDA MENTOR
- ASCENDA DROP / ROO7
- WordPress theme backend
- WhatsApp Conversations product ownership

The active data/runtime remains:
- GitHub `CESARJAUREGUITORRES/ascenda-os`
- Supabase `ituyqwstonmhnfshnaqz`
- Railway project `8def5cac-6aa4-42f1-96cc-8c9cf7d7d3a3`
- Notion path `CRACTIVE OS / PRODUCTOS / ASCENDA OS`.

