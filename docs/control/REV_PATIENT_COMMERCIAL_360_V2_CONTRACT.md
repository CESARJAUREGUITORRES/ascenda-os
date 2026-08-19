# REV — PATIENT COMMERCIAL 360 V2 CONTRACT

**Existing UI to evolve:** `app/public/patients.html`  
**Existing RPC to evolve:** `aos_paciente_360`  
**Owner:** REV-F6 read/intelligence layer consuming certified REV-F5 identity  
**Rule:** upgrade the existing Pacientes 360; do not create a second patient master/panel.

## Current limitation

The current Patient 360 and several histories are resolved primarily through `numero_limpio`/last 9 digits. This is useful for compatibility but can fragment one person across historical phones or accidentally aggregate shared-phone records.

## V2 subject

The V2 subject is `canonical_patient_id`.

Backward-compatible lookup inputs may be:

- canonical patient ID;
- current phone;
- historical phone alias;
- reviewed document/email alias where role policy permits.

All inputs resolve first through Identity Bridge V2. The panel then queries history by canonical identity and explicit linked facts, not by an unbounded phone-only scan.

## V2 sections

### 1. Identity card

Expose role-appropriate:

- canonical name;
- current primary contact;
- canonical patient ID internally;
- current document/email only where permitted;
- identity status;
- confidence band;
- review/conflict indicator;
- data completeness;
- provenance summary;
- alias count / historical-contact indicator without unnecessary PII display.

### 2. Commercial summary

Derived from canonical facts:

- observed total sales/facturation within declared transaction coverage;
- observed paid/reconciled amount where F4 supports it;
- purchase count;
- first/last observed sale;
- first/last appointment/activity;
- future appointment state;
- top canonical products/services;
- current lifecycle state;
- observed reactivation count;
- sede history.

Never present incomplete historical coverage as lifetime truth. Display period/coverage metadata.

### 3. Unified timeline

Ordered events with explicit provenance/type:

- acquisition lead;
- call/contact;
- WhatsApp conversation milestone where permitted;
- appointment;
- sale;
- canonical product fact;
- payment/reconciliation fact;
- reactivation event.

Use explicit IDs (`lead_id_origen`, `llamada_id_origen`, `venta_id_match`, sale IDs, cotization/plan IDs) before inferred contact-key joins.

### 4. Identity aliases & merge history

Admin-only identity block:

- current canonical profile;
- historical identifiers/aliases as restricted evidence;
- fused/absorbed profile count;
- merge/apply event history;
- unresolved conflicts;
- rollback/recovery status when relevant.

No clinical content is needed to make commercial identity visible.

### 5. Intelligence card

From REV-F6:

- lifecycle state;
- repeat/retention signals;
- observed LTV with time window;
- cross-sell/next-product patterns with sample size/confidence;
- acquisition-to-revenue attribution only where evidence is certified;
- reactivation opportunity signal as analysis, not an autonomous send command.

Each insight must expose metric trust metadata.

### 6. Clinical boundary

Clinical notes, allergies, evaluations, images and other PHI remain role-gated. Commercial agents/WA/CIA do not receive broad clinical context merely because it exists in Patient 360.

## Duplicate UX target

Replace a generic duplicate warning with evidence classes:

- `EXACT_SAFE_CANDIDATE`;
- `STRONG_REVIEW`;
- `IDENTITY_CONFLICT`;
- `HOMONYM / DO_NOT_MERGE`.

Show why the case was classified without using weak heuristics. Physical merge actions remain admin+2FA and governed.

## Trust metadata displayed by the panel

Every derived metric/insight may include:

- `coverage` — fraction/period of relevant source universe represented;
- `confidence` — trust in identity/metric derivation;
- `freshness` — as-of timestamp / age of source model;
- `sample_size` — denominator behind analytic patterns.

A value without these fields may still be shown if it is a direct canonical fact, but inferred/aggregate intelligence must not look equally certain when evidence is weak.

## Historical sales plug-in

When 2024/2025 sales are ingested, Patient 360 must expand automatically through canonical sale/F3/F4/F5 facts. No manual patient-page reconstruction or new 2024/2025-specific code path.

## Acceptance gates

- old/new phone aliases resolve to same canonical patient where reviewed;
- shared phone does not collapse incompatible patients;
- fused aliases preserve historical sales/agenda/contact access;
- commercial totals reconcile to canonical sale/payment facts;
- current phone lookup still works;
- exact canonical ID lookup works;
- unresolved identity is visibly unresolved, not silently assigned;
- no PHI leak to commercial roles;
- coverage/confidence/freshness/sample size display works for F6 intelligence;
- existing Patient 360 navigation/session/edit/cotization flows remain functional.
