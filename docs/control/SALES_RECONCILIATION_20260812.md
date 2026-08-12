# Sales reconciliation — 2026-08-12

## Scope

Production reconciliation of August 2026 sales against the operator's accounting sheet before the formal month-by-month validation phase.

## Confirmed discrepancy

Before remediation:

- `aos_ventas`: 73 rows / S/53,574.80 for August 2026.
- Accounting sheet screenshot: S/53,274.80.
- Difference: exactly S/300.00.

Two imported sales without downstream references accounted for the full difference:

- sale PK 2115 / S/50.00;
- sale PK 2116 / S/250.00.

Dependency checks found zero references to those sale IDs in Agenda, Atenciones, Inventario movements, Payment Alerts, Work Plans, Product Follow-up and Treatment Sessions.

## Date correction

Sales PK 2095–2104 matched the ten rows shown in the accounting sheet under 2026-08-08. They were stored as 2026-08-09 while their generated `venta_id` values also encoded 20260808.

A guarded transaction changed only `fecha` from 2026-08-09 to 2026-08-08 for those ten records.

## Guarded remediation result

The transaction was allowed to commit only if it produced exactly:

- 71 August sales;
- S/53,274.80 total.

Post-commit verification matched both conditions.

Current August daily distribution after correction:

- 2026-08-01: 32 sales / S/20,083.80
- 2026-08-03: 6 / S/10,323.00
- 2026-08-04: 1 / S/259.00
- 2026-08-05: 1 / S/189.00
- 2026-08-06: 1 / S/100.00
- 2026-08-07: 12 / S/2,452.00
- 2026-08-08: 10 / S/14,723.00
- 2026-08-10: 4 / S/4,545.00
- 2026-08-11: 4 / S/600.00

## Marketing impact

The S/300 accounting correction does not imply a S/300 reduction in Marketing M0. Marketing M0 contains only sales attributable to the selected lead cohort.

After remediation, August Marketing M0 remains:

- 2 acquired clients;
- 6 attributed operations;
- S/1,045 M0 revenue.

One removed S/50 operation had contributed to an older cohort's later revenue, so the June cohort LTV decreased accordingly. This is expected behavior and confirms that LTV and accounting-month revenue are different measures.

## Import hardening

Migration `20260812194953_make_sales_import_batches_idempotent_20260812_v2.sql` adds exact-batch idempotency to `aos_importar_ventas`:

- identical JSON batches are serialized using an advisory transaction lock;
- an already processed exact batch returns as duplicate instead of inserting again;
- similar but legitimately distinct purchases are not automatically collapsed;
- the batch registry is not readable by `anon` or `authenticated` roles.

The UI still uses its explicit date selector for pasted sales. During the upcoming workbook-by-workbook reconciliation, dates and daily totals must therefore be compared against source sheets before declaring the historical dataset closed.

## Next gate

Validate every monthly sales workbook against `aos_ventas` using at least:

1. monthly row count;
2. monthly amount;
3. daily row count and amount;
4. exact row matching on date / patient / treatment / description / payment method / amount / site;
5. duplicates and missing records;
6. date shifts;
7. downstream effects in commissions, patients, cash and Marketing attribution.
