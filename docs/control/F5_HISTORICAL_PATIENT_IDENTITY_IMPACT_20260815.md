# F5 Historical Client & Sales + Patient Identity — Impact Report

**Date:** 2026-08-15  
**Risk:** CRITICAL — patient PII/PHI, identity resolution, future canonical merge.  
**Branch:** `data/f5-historical-patient-identity-foundation-20260815`  
**Entry gate:** F2/F3/F4 certified; GitHub Issue #151 is CURRENT.

## 1. Source inventory

Six owner-provided XLSX files were analyzed read-only. They share the same 27-column schema.

| Source | Rows |
|---|---:|
| San Isidro 2024 | 3,190 |
| Pueblo Libre 2024 | 4,192 |
| San Isidro 2025 | 3,066 |
| Pueblo Libre 2025 | 3,053 |
| San Isidro 2026 | 1,004 |
| Pueblo Libre 2026 | 993 |
| **Total** | **15,498** |

Each source file has a SHA-256 manifest prepared outside GitHub. No patient PII is committed to the repository.

## 2. Critical source behavior

- All 15,498 source patient IDs are distinct.
- The two sede exports are not independent patient universes. Same-year overlap is extremely high when normalized name + phone are compared:
  - 2024: 2,982 identities overlap between sede exports.
  - 2025: 2,883 overlap.
  - 2026: 961 overlap.
- Therefore filename/sede is `source_sede`, not an automatic `SEDE_PRINCIPAL` value.
- Cross-sede duplicate snapshots often contain complementary activity: appointment, tags, allergies, notes or last-budget evidence may exist in only one snapshot.

## 3. Conservative source identity analysis

A local deterministic, non-destructive clustering pass produced **7,830 source identity candidates** from 15,498 rows.

- 7,745 clusters have high-confidence source identity evidence.
- 48 are singletons with insufficient duplicate evidence.
- 37 require direct source-identity review.
- 582 normalized phone keys are shared by more than one distinct source cluster, involving 1,234 clusters. Phone-only matching is therefore unsafe for these.
- 4 valid 8-digit DNI keys collide across distinct source clusters and must be reviewed.
- Exact email collisions did not split across distinct source clusters in the current pass.

The source clustering is not yet a canonical-patient merge. Linking to `aos_pacientes` is a separate gate.

## 4. Source coverage after duplicate consolidation

Approximate coverage across the 7,830 source identity candidates:

- normalized phone: 99.2%
- valid 8-digit DNI: 40.2%
- email: 17.6%
- plausible DOB: 17.2%
- parsed district: 14.9%
- occupation: 14.3%
- historical tags: 22.2%
- allergies: 12.6%
- last appointment: **96.8%** after complementary cross-sede consolidation
- future next appointment as of intake: 0.9%
- last-budget evidence: 10.7%

The last-appointment result is strategically important: raw row-level coverage is only ~54.8%, but complementary sede snapshots raise identity-level coverage to ~96.8%.

## 5. Geography

The source `Dirección` field contains both locality-only and street + locality formats.

- 2,153 raw rows contain address/locality evidence.
- 2,097 can be parsed safely from the right into district / province / department.
- 1,100 of those also contain a street/address prefix.
- 68 normalized districts, 21 provinces and 14 departments appear in the source.

Existing production `aos_pacientes` has only 2 non-empty `distrito` values, so F5 can materially improve geographic coverage without guessing.

## 6. Current production comparison

Read-only production baseline during intake:

- `aos_pacientes`: 7,668 rows.
- `fuente_datos='historico'`: 6,998.
- phone populated: 7,610; 7,163 distinct.
- document populated: 3,825; 3,565 distinct raw values.
- email populated: 1,796.
- DOB populated: 1,244.
- raw address populated: 1,098.
- district populated: 2.
- occupation populated: 1,019.
- `ult_visita` date populated: 220; legacy `ULTIMA_VISITA` text populated: 587.

Production historical rows use canonical UUID-like patient IDs; source IDs are not reusable as canonical IDs. Evidence-based linking is required.

## 7. Data-quality quarantine rules

Source evidence is never silently discarded, but invalid/ambiguous values cannot enrich canonical fields automatically.

Observed quarantine classes include:

- 117 non-standard phone formats, 40 international phones, 62 missing phones.
- 91 populated non-8-digit/alphanumeric document values.
- 25 DOB values that are unparseable, future or implausibly old; minors remain reviewable rather than automatically rejected.
- 56 address values that cannot be safely decomposed into district/province/department.
- 110 `Última cita` values earlier than source creation date; retain as evidence because legacy migration semantics may explain them.
- same phone across materially different identities; phone alone is not authority.
- same DNI across materially different identities; always review.

## 8. Financial/visit evidence policy

- `Última cita`: use max observed date only after identity is confirmed; preserve which source/sede supplied it.
- Source snapshot supplying the max last-appointment date suggests `last_observed_sede`, not automatic `SEDE_PRINCIPAL`.
- `Próxima cita`: staging evidence only; never create agenda appointments from stale historical snapshot data.
- `Último presupuesto`: all 964 populated values parse as numeric `A/B`; 855 have A=B and 109 have A<B. Semantics are not assumed. Never convert to payment, sale, quote balance or debt until reconciled to authoritative records.
- `ADELANTO` governance from F2/F4 remains unchanged: payment evidence is not automatic debt.

## 9. Clinical evidence policy

- Historical allergy and clinical-note text is staged with provenance.
- No automatic write to `aos_historia_clinica` or `aos_notas_pacientes` occurs in the foundation.
- A confirmed canonical identity and a separate clinical merge policy are required before clinical enrichment.

## 10. Foundation architecture

F5 foundation adds private, additive tables only:

1. `aos_f5_source_batches_v1` — immutable file manifest/hash.
2. `aos_f5_patient_source_rows_v1` — raw JSON + normalized evidence.
3. `aos_f5_identity_clusters_v1` — proposed source identity clusters.
4. `aos_f5_identity_cluster_members_v1` — row membership/rule/score.
5. `aos_f5_patient_link_preview_v1` — proposed link + field-level patch against canonical patient.
6. `aos_f5_audit_v1` — F5 actions/audit.

Security boundary:
- RLS enabled.
- no browser policies.
- all access revoked from `public`, `anon`, `authenticated`.
- no public RPC in foundation.
- no source PII committed to GitHub.
- no `INSERT/UPDATE/DELETE` against `aos_pacientes` in foundation.

## 11. Merge policy for later gate

### Safe enrichment candidates after identity approval
- district / province-city / department and street address where source parsing is unambiguous;
- DOB only if plausible and conflict-free;
- occupation when canonical value is empty;
- last visit using max authoritative evidence;
- missing email/document/phone only when evidence is unambiguous.

### Separate relation/evidence, not scalar overwrite
- multiple tags;
- acquisition/source channel history;
- branch-specific HC aliases;
- source-sede activity snapshots;
- budget evidence.

### Human review required
- conflicting DNI, DOB, email or materially different names;
- shared phone across different identity clusters when no stronger evidence resolves it;
- proposed overwrite of a non-empty canonical value with a different value;
- any clinical note/allergy propagation.

## 12. Exit gates for foundation

1. FAST static security contract green.
2. Zero-Cost isolated Supabase migration + lint + pgTAP green.
3. Recovery proves fail-closed and preserves evidence tables.
4. Production preflight confirms no naming collision and current patient counts.
5. Additive migration only.
6. Load six hashed source batches idempotently into private staging.
7. Run DB-level source clustering/link preview against current `aos_pacientes`.
8. Publish coverage/conflict preview before any canonical patient enrichment.

No canonical patient mutation is authorized by this foundation migration.
