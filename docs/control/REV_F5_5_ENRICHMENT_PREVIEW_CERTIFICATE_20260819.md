# REV-F5.5 — ENRICHMENT PREVIEW CERTIFICATE

**Captured:** 2026-08-19 America/Lima  
**Workstream:** `REV-F5-CLOSEOUT`  
**Entry GitHub baseline:** `main@a9e5d0940d5bf43d43d65589d4ad739bd02276f2`  
**Scope:** fill-only enrichment preview only. No canonical patient mutation, Review/Apply, patient creation or physical merge.

## Entry revalidation

Before the F5.5 mutable gate, CURRENT remained compatible with the certified F5.4 state:

- source rows = **15,498**;
- identity memberships = **15,498**;
- clusters / classifications = **8,716 / 8,716**;
- MATCH = **296**;
- REVIEW = **6,984**;
- NEW = **1,436**;
- preview applied rows = **0**;
- canonical Apply events = **0**;
- canonical patients = **7,687**;
- REV-F5.4 contractual canonical fingerprint = `619f20596f6f9181f96332997ee3d953`.

## Existing enrichment contract reused

REV-F5.5 did not invent a new field mapping. It reused the existing F5.3 `proposed_patch` semantics, which already generated fill-only patches only when the corresponding canonical value was empty.

The certified preview mapping is limited to:

- `Email`;
- `N° documento`;
- `Sexo`;
- `Fecha de nacimiento`;
- `Dirección`;
- `Ocupación`;
- `distrito`;
- `departamento`;
- `ciudad`.

A dedicated private table `public.aos_f5_enrichment_preview_v1` and service-role-only builder `public.aos_f5_build_enrichment_preview_v1()` materialize the F5.5 contract at field level.

Every preview row requires:

- its cluster is REV-F5.4 `MATCH`;
- the target canonical patient still exists;
- the target canonical field is empty;
- exactly **one distinct historical source value** exists for the field;
- provenance is retained through source-row IDs;
- `requires_human=true`;
- `apply_eligible=false`;
- no Apply event exists.

If any existing MATCH proposed patch fails these gates, the whole rebuild fails closed.

## Certified LIVE enrichment preview

- MATCH population evaluated = **296 / 296**;
- MATCH patients with at least one safe fill-only preview = **202**;
- field-level preview rows = **455**;
- duplicate `(cluster,field)` keys = **0**;
- ambiguous source-value previews = **0**;
- provenance-missing previews = **0**;
- canonical overwrite violations = **0**;
- non-MATCH preview rows = **0**;
- target mismatches = **0**;
- clinical-note/allergy preview rows = **0**;
- Apply-eligible rows = **0**;
- rows outside human gate = **0**.

### Field distribution

| Field | Preview rows | Policy state |
|---|---:|---|
| `Sexo` | **121** | APPLY_ALLOWED / LOW |
| `distrito` | **108** | APPLY_ALLOWED / LOW |
| `Fecha de nacimiento` | **75** | POLICY_UNDEFINED |
| `Ocupación` | **67** | POLICY_UNDEFINED |
| `Dirección` | **57** | POLICY_UNDEFINED |
| `Email` | **23** | POLICY_BLOCKED / IDENTITY_ANCHOR |
| `N° documento` | **4** | POLICY_UNDEFINED |
| **TOTAL** | **455** | preview only |

`departamento` and `ciudad` are part of the established mapping but produced zero current fill-only rows because the matching canonical records with historical evidence were already populated.

## Apply-policy boundary

The existing `aos_f5_apply_field_policy_v1` was not widened in F5.5.

Across the 455 preview rows:

- policy currently APPLY_ALLOWED = **229** field rows;
- policy explicitly blocked = **23** field rows (`Email`);
- policy undefined = **203** field rows;
- F5.5 `apply_eligible=true` = **0**.

Therefore the policy information is descriptive for the next governance phase only. **F5.5 authorizes no writes to `aos_pacientes`, including the 229 rows whose field policy is currently allowed.**

## Deliberately deferred semantic mappings

The historical evidence audit also found:

- phone fill opportunities = **0**;
- latest-appointment potential fills = **201**;
- acquisition-channel/origin potential fills = **1**.

`Última cita → ULTIMA_VISITA/ult_visita` and acquisition channel → `FUENTE/fuente_datos` were **not** materialized because F5.5 found no already-approved canonical semantic mapping for those destinations. They remain quantified evidence for a later explicit contract decision rather than silently guessing field semantics.

Clinical notes and allergies remain excluded from commercial automatic enrichment. Historical budget remains evidence-only and is not used as revenue/debt truth.

## Security boundary

Live privilege readback:

- enrichment table SELECT: `anon=false`, `authenticated=false`, `service_role=true`;
- builder EXECUTE: `anon=false`, `authenticated=false`, `service_role=true`;
- no PII committed to GitHub;
- no browser role receives the private enrichment preview.

## Determinism proof

The complete enrichment preview was rebuilt twice against unchanged CURRENT state.

Both runs returned exactly:

- proposal fields = **455**;
- patients with proposal = **202**;
- policy allowed = **229**;
- policy blocked = **23**;
- policy undefined = **203**;
- Apply events = **0**;
- canonical patients = **7,687**;
- canonical mutation = **false**.

Semantic preview fingerprint, run 1: `d22f2542813dcf71e767abc9e78d1021`.  
Semantic preview fingerprint, run 2: `d22f2542813dcf71e767abc9e78d1021`.

Canonical fingerprint before/after and both runs: `619f20596f6f9181f96332997ee3d953`.

Result: **DETERMINISTIC PASS**.

## Gate result

- `REV-F5.5 — ENRICHMENT PREVIEW — PASS`
- `REV-F5.6 — REVIEW & APPLY — NEXT / BLOCKED PENDING EXPLICIT OWNER AUTHORIZATION`
- overall `REV-F5 — EN CURSO / NOT YET PRODUCTION CERTIFIED`
- `REV-F6 — BLOCKED`

This certificate does not authorize Review/Apply, patient creation, canonical overwrite or physical identity merge.
