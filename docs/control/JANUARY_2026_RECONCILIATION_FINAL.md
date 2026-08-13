# ASCENDA OS — JANUARY 2026 RECONCILIATION FINAL

**Status:** `VALIDATED_SALES_VISITS`  
**Validation date:** 2026-08-12 America/Lima  
**Scope:** sales integrity + historical visit reconstruction + downstream verification  
**PII:** intentionally omitted from this Git-tracked document

## 1. Certified financial checksum

January 2026 is certified at:

- **191 sales**
- **S/91,029.60**

The source CSV and production `aos_ventas` match at the certified transaction/financial layer. The January remediation did not change the number of sales or total revenue after financial certification.

## 2. Attendance rule used

Approved clinic rule for historical reconstruction:

- a certified sale recorded at a clinic location is evidence that the patient was physically present that day;
- advances, balances and partial payments also count as presence;
- MercadoPago for a **service** still counts as physical presence;
- automatic web exception: `COMPRA DE PRODUCTO + MERCADOPAGO` is treated as a web product sale and does not create a patient visit;
- employee/staff purchases remain valid sales but do not count as patient visits;
- visit grain is **PATIENT + DATE + BRANCH**, never one visit per sale row.

## 3. Certified visit result

The 191 January sales resolve into:

- **95** client-day-branch events;
- **93** patient visits;
- **1** web product sale excluded from attendance;
- **1** staff purchase excluded from patient attendance.

Final validation query:

- patient visits: **93**
- represented as `ASISTIO` or `EFECTIVA`: **93**
- missing attendance representation: **0**

Therefore January passes the sales + visits gate.

## 4. Agenda remediation

Agenda before remediation:

| State | Rows |
|---|---:|
| NO ASISTIO | 237 |
| ASISTIO | 107 |
| CANCELADA | 32 |
| EFECTIVA | 25 |
| PENDIENTE | 13 |
| REAGENDADA | 11 |
| **TOTAL** | **425** |

Applied to Agenda:

- **3** existing `PENDIENTE -> ASISTIO` updates backed by certified same-day physical sales;
- **11** historical `ASISTIO` records inserted for visits that had no adequate attended appointment representation;
- all historical inserts use `hora_cita = NULL` when no reliable time evidence exists;
- no time was invented;
- no unexpected patient was auto-created by the Agenda triggers;
- the ambiguous multi-appointment/no-show case was preserved rather than rewriting uncertain historical schedule states; a separate historical attended visit represents the proven presence.

Agenda after remediation:

| State | Rows |
|---|---:|
| NO ASISTIO | 237 |
| ASISTIO | 121 |
| CANCELADA | 32 |
| EFECTIVA | 25 |
| REAGENDADA | 11 |
| PENDIENTE | 10 |
| **TOTAL** | **436** |

## 5. Identity correction boundary

Identity data was not bulk-normalized from the CSV because historical spreadsheet autofill contamination is known to exist.

During January:

- one user-confirmed recurrent patient identity was corrected across the canonical patient, one sale identity and the already-existing attended appointment;
- a conflicting DNI copied onto an inactive/no-activity prospect was removed after read-only evidence showed no sales, appointments, calls or leads for that prospect identity;
- financial fields of the affected sale were preserved exactly;
- other ambiguous identity clusters were **deferred**, not guessed.

Remaining identity conflicts are intentionally carried to the later **Master Patient / affiliation** phase, where a separate client-filiation database will be used as higher-quality identity evidence.

This deferral does **not** block January sales/visit certification.

## 6. Persistent reconciliation ledger

A protected internal reconciliation ledger now exists in Supabase:

- `aos_recon_meses`
- `aos_recon_identidades`
- `aos_recon_visitas`
- `aos_recon_cambios`

Security properties:

- RLS enabled;
- no client policies created;
- privileges revoked from `anon` and `authenticated`;
- intended only as control-plane/audit data.

January ledger records include:

- monthly source/DB checksums;
- **72** source identity-cluster rows;
- **95** client-day-branch event rows;
- sale ID arrays per visit event;
- Agenda links where available;
- proposed/applied actions;
- before/after/rollback evidence for applied corrections.

Applied change ledger for January:

| Change type | Count |
|---|---:|
| Historical Agenda visit inserts | 11 |
| Agenda state updates | 3 |
| Agenda identity enrichment | 1 |
| Canonical patient identity update | 1 |
| Identity-collision cleanup | 1 |
| Sale identity-only correction | 1 |
| **TOTAL APPLIED** | **18** |

All **18** records are stored as `APPLIED` with rollback evidence.

## 7. Downstream validation

### Commissions
`aos_comisiones_admin(1, 2026)` returned:

- sales: **191**
- revenue: **S/91,029.60**
- commission total: **S/573.39**

The commission layer therefore retains the certified January financial basis.

### Marketing
`aos_marketing_attribution_public_v3(1, 2026)` returned successfully after remediation.

Relevant health signal:

- `anomaliasHigh = 0`

Marketing attribution revenue remains conceptually different from total clinic sales revenue and must not be compared as if both metrics had identical scope.

## 8. Performance incident resolved before final write phase

During January work, Supabase Free/Nano entered an overload condition with 5xx gateway failures and PostgreSQL statement timeouts.

The incident was isolated and remediated before January writes resumed. See:

- `docs/control/PERFORMANCE_GUARD_20260812.md`

The performance fix reduced redundant panel polling and guarded Railway background workers without removing business capabilities.

Post-fix health checks during January remediation showed:

- low connection count;
- zero `idle in transaction` sessions;
- zero long-running (>5 s) active queries in repeated checks;
- no return of the previous 5xx/statement-timeout storm during remediation.

A separate recurring low-cost unauthorized Studio request remains technical debt and is not a January reconciliation blocker.

## 9. January definition of done

January has passed the current phase definition of done:

- [x] source row count = DB row count
- [x] source monthly total = DB monthly total
- [x] financial layer certified
- [x] all inferred patient visits represented as attended/effective
- [x] web/staff attendance exceptions explicitly classified
- [x] no unexpected patient creation during historical Agenda inserts
- [x] rollback evidence retained
- [x] Commissions checked
- [x] Marketing checked
- [x] reconciliation matrices persisted in Supabase
- [x] unresolved identity ambiguity deferred instead of guessed

**Final phase status: `VALIDATED_SALES_VISITS`.**

## 10. Next boundary

Next month: **February 2026**.

Source target from the established monthly source baseline:

- **166 transactions**
- **S/78,734.62**

Do not remediate February from this target alone. First retrieve the original February CSV and re-query current production because the live database may have changed since the historical baseline.

February must repeat the same month-isolated process:

`READ-ONLY AUDIT -> SEMANTIC MATCH -> IDENTITY/VISIT MATRIX -> IMPACT REPORT -> SNAPSHOT -> GUARDED FIX -> EXACT FINANCIAL POST-CHECK -> VISIT VALIDATION -> COMMISSIONS/MARKETING -> LEDGER -> VALIDATED`
