# ASCENDA OS — CANONICAL CONTINUITY HANDOFF

**Updated:** 2026-08-12 (America/Lima)  
**Current boundary:** January closed -> February read-only audit

This is the canonical handoff for continuing ASCENDA OS from another ChatGPT/Codex session. Read it together with `AGENTS.md`, `SECURITY.md`, `docs/control/ASCENDA_CONTROL_MASTER.md` and the front-specific documents in `docs/control/` before changing production.

## 1. Project anchors

- GitHub repository: `CESARJAUREGUITORRES/ascenda-os` (private)
- Supabase production: `ituyqwstonmhnfshnaqz`
- `main` = production Git baseline
- `staging` = integration branch, not a separate production database
- productive application: `app/`
- productive frontend: `app/public/`
- productive Node/Railway server: `app/server.js`
- `src/` = legacy/historical unless proven otherwise
- Railway deploys from GitHub `main`; a merge to `main` may auto-deploy

## 2. Mandatory operating rules

1. Read `AGENTS.md` and `SECURITY.md` before writes.
2. Never expose credentials, tokens, API keys, passwords or PHI/PII in Git documentation.
3. For HIGH production-data corrections use: read-only audit -> Impact Report -> dependency/trigger check -> snapshot -> deterministic transaction -> post-check -> rollback evidence.
4. Do not mass-delete duplicate-looking sales; legitimate repeated purchases exist.
5. Do not overwrite cleaner canonical identity from suspicious spreadsheet DNI/phone values.
6. Historical sales reconciliation is performed **one month at a time** with a separate rollback boundary for every month.
7. Do not start a month's writes until its source CSV has been retrieved and current production re-queried.

## 3. Source-of-truth rules

### Monthly CSV = transactional truth
Authoritative for:
- sale date
- treatment/category
- raw description
- payment method
- amount
- payment status
- adviser
- attended-by/professional
- branch
- financial row count
- daily/monthly totals

### ASCENDA + corroborating systems = identity priority
Prefer already-clean canonical data from ASCENDA for:
- DNI
- phone
- `numero_limpio`
- consolidated patient identity

Identity conflicts must be resolved using combined evidence from patients, sales, appointments, calls, leads and historical frequency. A later separate affiliation/client database supplied by the user will be used as higher-confidence evidence during the Master Patient phase.

### Products
For `TRATAMIENTO = COMPRA DE PRODUCTO`, the actual product is often encoded in `DESCRIPCION`.

Preserve raw description. Product alias/canonical-name/quantity/payment-semantic normalization is a later dedicated phase after historical sales are financially reconciled.

## 4. Historical monthly source targets

January-July source total:
- **1,192 transactions**
- **S/498,424.47**

| Month | Source rows | Source total |
|---|---:|---:|
| Jan 2026 | 191 | S/91,029.60 |
| Feb 2026 | 166 | S/78,734.62 |
| Mar 2026 | 156 | S/63,681.65 |
| Apr 2026 | 152 | S/59,496.95 |
| May 2026 | 179 | S/79,225.85 |
| Jun 2026 | 159 | S/61,140.75 |
| Jul 2026 | 189 | S/65,115.05 |

Historical baseline differences before month-by-month remediation:
- January: same row count, S/99 short
- February: +13 rows / +S/5,751.60 in ASCENDA
- March: -1 row / -S/161 in ASCENDA
- April: row count and total matched, field-level audit still required
- May: +2 rows / +S/79 in ASCENDA
- June: -3 rows / -S/1 in ASCENDA
- July: row count and total matched, field-level audit still required

These are historical baselines only. Always re-query live production before acting.

## 5. Known systematic failure modes

- entire import batches shifted to the wrong date
- one logical sale split into artificial rows
- multiple source sales fused into one row
- duplicate imports / extra rows
- missing rows
- source phone/DNI autofill artifacts
- historical loss of `ATENDIO`
- inconsistent treatment labels
- product names embedded in description
- payment/adviser/professional values omitted or changed by older imports

Semantic one-to-one matching is required; row ordinal is not reliable.

## 6. Attendance reconstruction rule

Approved clinic rule:

- a certified sale at a clinic location means the patient was physically present that day;
- advances, balances and partial payments count as presence;
- MercadoPago for a service still counts as presence;
- automatic web exception: `COMPRA DE PRODUCTO + MERCADOPAGO` does not create a patient visit;
- staff purchases remain valid sales but do not count as patient visits;
- visit grain is **PATIENT + DATE + BRANCH**, not one visit per sale.

Never invent an appointment hour. If historical presence is proven but time is not, use `hora_cita = NULL`.

## 7. Persistent monthly reconciliation ledger

A protected internal control-plane ledger now exists in production Supabase:

- `aos_recon_meses`
- `aos_recon_identidades`
- `aos_recon_visitas`
- `aos_recon_cambios`

Security:
- RLS enabled
- no client policies
- privileges revoked from `anon` and `authenticated`
- do not expose this ledger directly to the frontend

Purpose:
- preserve monthly checksums
- preserve identity-resolution evidence
- preserve patient-day-branch visit reconstruction
- preserve source sale-ID links
- preserve before/after/rollback evidence for every applied change

Use the same ledger for February onward rather than recreating matrices only in chat.

## 8. JANUARY 2026 — CLOSED

**Current status: `VALIDATED_SALES_VISITS`.**

Canonical final document:
- `docs/control/JANUARY_2026_RECONCILIATION_FINAL.md`

Certified financial result:
- **191 sales**
- **S/91,029.60**

Visit result:
- 95 client-day-branch events
- **93 patient visits**
- 1 web product sale excluded from attendance
- 1 staff purchase excluded from patient attendance
- final validation: **93/93 patient visits represented as `ASISTIO` or `EFECTIVA`**
- missing representation: **0**

Agenda before January attendance remediation:
- total 425
- ASISTIO 107
- EFECTIVA 25
- NO ASISTIO 237
- CANCELADA 32
- PENDIENTE 13
- REAGENDADA 11

Applied:
- 3 deterministic `PENDIENTE -> ASISTIO` updates
- 11 historical `ASISTIO` inserts without invented time
- no unexpected patient auto-creation
- ambiguous existing no-show schedules were preserved instead of rewritten without evidence

Agenda after remediation:
- total **436**
- ASISTIO **121**
- EFECTIVA 25
- NO ASISTIO 237
- CANCELADA 32
- PENDIENTE 10
- REAGENDADA 11

January reconciliation ledger contains:
- 72 source identity-cluster rows
- 95 event/visit rows
- exact sale-ID arrays per event
- 18 APPLIED change records with rollback evidence

Applied change categories:
- 11 historical Agenda visits
- 3 Agenda state corrections
- 1 Agenda identity enrichment
- 1 canonical patient identity correction
- 1 identity-collision cleanup
- 1 sale identity-only correction

Remaining ambiguous identity clusters are deferred to the later affiliation/Master Patient phase. They do not block the certified sales/visit layer.

### January downstream checks

Commissions (`aos_comisiones_admin(1,2026)`):
- 191 sales
- S/91,029.60 revenue
- S/573.39 commission total

Marketing (`aos_marketing_attribution_public_v3(1,2026)`):
- RPC healthy
- `anomaliasHigh = 0`

Marketing attribution metrics must not be equated with total clinic sales revenue because cohort/attribution scope differs.

## 9. Performance incident / Performance Guard

During January reconciliation, Supabase Free/Nano became overloaded with gateway 5xx and PostgreSQL statement timeouts.

Canonical incident doc:
- `docs/control/PERFORMANCE_GUARD_20260812.md`

Production Performance Guard commit:
- `558c6c27f36e9be3b1491ae9a76e3fa73d65ec73`

Key fixes:
- dynamic panel interval cleanup on navigation
- Home Admin duplicate polling removed
- hidden-tab polling suspended
- expensive panel reads staggered
- overload retry delay increased
- agent due-check guarded; business cron cadence preserved
- snapshot background generation reduced from 5 min to 30 min with mutex
- Studio scheduler protected from overlap
- shared background backoff/circuit behavior
- agent-log numeric trigger fixed through versioned migration

Post-fix checks during January remediation:
- low connection count
- 0 idle-in-transaction sessions
- 0 active queries >5 s in repeated health checks
- no return of the prior 5xx/statement-timeout storm during reconciliation writes

Residual technical debt:
- a separate recurring unauthorized Studio request returns 401 approximately every minute. It is currently low cost and not a reconciliation blocker; trace and remove it in a dedicated performance cleanup, not by weakening authorization.

## 10. CURRENT CONTINUATION POINT — FEBRUARY 2026

Do **not** repeat January.

Next exact action is a **READ-ONLY February audit**.

Historical source target:
- **166 transactions**
- **S/78,734.62**

A current commission RPC observed before February remediation reported a different live February state, demonstrating why live production must be re-queried rather than assuming the historical baseline.

### February sequence

1. Retrieve the original February CSV from the user's private ChatGPT File Library.
2. Query current February `aos_ventas`.
3. Recompute daily counts/totals and full transaction fingerprinting.
4. Build semantic one-to-one source <-> DB matching.
5. Classify exact/update/missing/extra/split/fused/identity-review cases.
6. Build February identity matrix using canonical ASCENDA identity priority.
7. Infer patient-day-branch visits using the approved attendance rule.
8. Cross-check Agenda and existing attendance states.
9. Persist the read-only February matrix into the reconciliation ledger.
10. Produce the February Impact Report.
11. Only after the Impact Report: snapshot -> guarded writes -> exact financial post-check -> 100% visit representation.
12. Validate Commissions + Marketing.
13. Mark February validated and update this handoff before March.

## 11. Monthly definition of done

A month is validated only when:
- source row count = DB row count
- source monthly total = DB monthly total
- daily row counts and totals reconcile
- each source financial transaction has a deterministic DB representation
- no unexplained extras remain
- operational fields reconcile for unambiguous rows
- cleaner canonical identity is not degraded
- every certified patient visit is represented in Agenda as attended/effective under the approved rule
- downstream Commissions/Marketing are checked
- reconciliation ledger and rollback evidence are complete
- handoff is updated before moving to the next month

## 12. Next recommended action

**Start February read-only audit. No February writes before its Impact Report.**
