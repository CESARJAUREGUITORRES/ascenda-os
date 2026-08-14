# FASE 3 — Product catalog candidate classification

This file records only product metadata, never client PII.

## CURRENT_UNCATALOGED — strong active inventory evidence

These owner-confirmed products are not currently represented by a canonical active row in `aos_catalogo_servicios`, but live inventory shows them as `PRODUCTO_VENTA`:

- FOTOPROTECTOR OIL CONTROL FUSION WATER 50 ML-ISDIN
- POWER 10 HONEYDEW FAIRY 30 ML
- SENSITONIC

They are candidates for a later additive catalog migration after CI/preflight. Phase 3 does not auto-create them in the active catalog during the identity seed.

## LEGACY — keep historical identity, do not auto-activate

- CAPTOPRIL x30
- FOTOPROTRCTOR MAGIC FUSION REPAIR COLOR ISDIN
- HAPPYLASH BOOST 5 ml
- HELIOCARE 60 CAPS
- LYNDHARIAL CREMA
- LYNDHARIAL GOTAS
- OK EYES ISDIN
- VITAL EYES ISDIN

Historical sale evidence is preserved, but these names are not promoted to current sellable catalog without separate evidence/approval.

## Explicit links to existing generic catalog rows

Owner identity remains specific while inventory/catalog linkage can point to a generic operational SKU:

- HYALURONIC MOINSTURE 30ML ISDIN → HYAL MOIST ND
- HYALURONIC MOISTURE OILY 30ML ISDIN → HYAL MOIST OILY
- MENTONERA DE SILICONA → FAJA PAPADA SIL
- NF CAPS MEN → NF CAPS
- NF CAPS WOMEN → NF CAPS
- PRUNEX STICK → PRUNEX x1
- RETINAL INTENSE 50 ML → RETINAL ISDIN
- SHAMPOO MINOXIDIL / GRASO / SECO → SHAMPOO MINOX

The historical canonical label is not discarded merely because multiple variants share one current catalog row.
