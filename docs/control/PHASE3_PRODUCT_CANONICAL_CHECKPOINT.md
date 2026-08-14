# ASCENDA OS — FASE 3 PRODUCTO CANÓNICO · CURRENT CHECKPOINT

**Estado:** PREPRODUCTION BUILD  
**Branch:** `feature/phase3-product-canonical-20260814`  
**Upstream temporal:** `infra/zero-cost-ci-v2` / PR #97  

## Source audit locked

- workbook: `Clientes_Productos 2026.xlsx` (private; PII is not committed);
- 394 historical sale IDs verified against production;
- 388 product facts;
- 6 explicit exclusions;
- 418 physical units;
- 43 promo/pack sale rows;
- 51 owner canonical product names;
- 167 historical product aliases after correction;
- 0 alias→canonical conflicts after integration corrections.

Integration corrections locked:
- 909 → `PERFECT FORM B 90GR`;
- 1644 → `LYNDHARIAL GOTAS`;
- 1632 → physical quantity `0`;
- 1638 → physical quantity `0`.

## Build present on branch

- product identity table;
- alias v2 table;
- locked sale fact layer;
- additive resolver + `aos_ventas` trigger;
- owner seed without PII;
- catalog linkage while preserving historical variants;
- fail-closed `REVIEW_REQUIRED` path;
- recovery script;
- 29-assertion isolated pgTAP contract;
- dedicated Zero-Cost CI V2 workflow.

## Production boundary

No Phase 3 migration from this branch is authorized/applied to production yet. `aos_ventas.descripcion` remains immutable historical evidence. Production cutover is blocked until exact-SHA CI and read-only preflight pass after synchronization with CURRENT `main`.
