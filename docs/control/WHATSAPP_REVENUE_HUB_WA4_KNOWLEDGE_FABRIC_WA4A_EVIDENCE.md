# WA-4A — Knowledge Fabric — Discovery / Authority / TEST Evidence

**Date:** 2026-08-27 America/Lima  
**Exact entry baseline:** `main@103c62b1de7b4aa65d21c40b9bde1110f500c96f`  
**Mutable lock:** `WA-4A — KNOWLEDGE FABRIC`  
**Execution mode:** `TEST-FIRST / ZERO-COST / PROD-READY / NO PROD APPLY`  

## 1. Discovery result

WA-4 already has a safe-off Copilot and multi-model router. `app/wa4-copilot.js` currently reads `aos_catalogo_servicios` and `aos_promociones` directly, ranks services lexically, sends selected commercial facts to the model, validates catalog IDs/prices, runs a separate safety classifier and never auto-sends. `aos_wa_ai_control_v1` remains `copilot_enabled=false`, `auto_reply_enabled=false`; production has `0` AI runs.

The missing layer is not another chatbot or another catalog. The gap is a governed retrieval contract that can prove **which source/version/freshness produced a fact**, block stale/conflicting facts and enforce least-data before later Copilot use.

## 2. Production knowledge-source inventory — read-only

Observed on 2026-08-27:

- `aos_catalogo_servicios`: **221/221 ACTIVE** = 54 PRODUCTO + 167 SERVICIO.
  - 164/221 have `precio_base`; **57 active rows have no base price**.
  - 175/221 have commercial description; **46 active rows lack commercial description**.
  - 220/221 have at least one FAQ.
  - latest `updated_at`: 2026-05-06 UTC.
- `aos_catalogo_categorias`: **26/26 ACTIVE**; 24 commercial descriptions; 26 FAQ sets; latest update 2026-05-04 UTC.
- `aos_promociones`: **0 rows**. Absence of a promotion must mean `UNKNOWN/NONE PRESENT`, never an invented offer.
- `aos_sedes_geo`: **2 active branches**, with address/phone/maps plus display-hour strings.
- `aos_config_horarios`: **14 rows / 12 active**, updated 2026-04-20 UTC.
- `aos_servicios_catalogo`: **0 rows** and is not authority.

## 3. Real conflict discovered

The two current hour representations contradict each other:

- `aos_sedes_geo` says PUEBLO_LIBRE `10:00-20:30`, SAN_ISIDRO `10:30-20:30`, weekend `09:30-18:00`;
- `aos_config_horarios` says `09:00-19:00` Monday-Saturday for both branches and Sunday inactive.

WA-4A will not silently choose or merge these values. Authority is frozen as follows:

- `aos_config_horarios` = operational hours authority;
- `aos_sedes_geo` = branch address/phone/maps authority;
- `aos_sedes_geo.horario_lv/horario_finde` = conflicting display metadata, excluded from answerable knowledge and retained only as conflict evidence.

Until the underlying source drift is reconciled by its owner, affected hour facts must be `BLOCKED_CONFLICT` and never reach the model as answerable context.

## 4. Authority matrix

| Domain | Source | Tier | Contract |
|---|---|---:|---|
| Catalog product/service facts | `aos_catalogo_servicios` | 10 | Authoritative commercial facts, price, approved description, benefits, FAQ, operational requirements. |
| Promotions | `aos_promociones` | 10 | Authoritative only while active and inside explicit validity. |
| Branch | `aos_sedes_geo` | 10 | Address/phone/maps; freshness is UNKNOWN because the table has no update timestamp. Hours excluded. |
| Hours | `aos_config_horarios` | 10 | Operational authority, but cross-source drift fails closed. |
| Category | `aos_catalogo_categorias` | 20 | Generic fallback; cannot override service-specific facts. |
| Legacy catalog | `aos_servicios_catalogo` | 90 | Not authority. |
| Generic LLM knowledge | model | 99 | Non-authority; cannot create or override ASCENDA facts. |

Hard order:

`governed source facts + evidence refs > approved derived knowledge > generic LLM knowledge`.

## 5. Necessity gate

`BUILD YES / NEW KNOWLEDGE MASTER NO / SOURCE MUTATION NO / PROD APPLY NO`.

Required minimum:

1. machine-readable authority matrix;
2. read-only unified knowledge projection;
3. source/version/evidence references;
4. freshness + validity states;
5. cross-source and same-subject conflict detection;
6. private retrieval RPC returning READY facts only;
7. issues/diagnostics view for stale/conflicting/inactive/insufficient facts;
8. least-data adapter for future WA-4B/WA-4C use;
9. deterministic grounding validator for citations, prices, hours and branch evidence;
10. TEST fixtures covering READY/STALE/CONFLICT/EXPIRED/UNKNOWN freshness.

No physical knowledge master is required because canonical sources already exist.

## 6. Least-data boundary

WA-4A commercial context may include only approved public/operational facts such as name, category, approved commercial description, approved benefits, price, duration/session count/frequency, public FAQ, promotion facts, branch contact/location and governed opening hours.

The Knowledge Fabric deliberately excludes from generic sales/model context:

- `descripcion_clinica`;
- `indicaciones`;
- `contraindicaciones`;
- `perfil_paciente`;
- `mecanismo_accion`;
- `composicion`;
- patient/lead/sale/REV identity data;
- secrets and integration credentials.

Personalized clinical suitability/adverse-event handling remains a human/clinical escalation path.

## 7. Freshness / validity contract

- catalog/category/hour rows with `updated_at` <= 180 days old: `FRESH` for retrieval purposes;
- rows older than 180 days: `STALE` → fail closed;
- sources with no update timestamp: `UNKNOWN`; branch location may be surfaced only as `READY_WITH_WARNING` with explicit freshness warning;
- promotions additionally require `activa=true` and current date inside `vigencia_inicio/vigencia_fin`;
- inactive/upcoming/expired promotions are non-answerable;
- same-subject divergent authoritative prices or promo terms are conflicts;
- current branch-hour drift is an explicit cross-source conflict.

The 180-day threshold is a WA-4A operational retrieval policy, not a claim that the underlying business fact changed after 180 days.

## 8. Delivered TEST package

Planned exact package:

- `supabase/migrations/20260827185000_wa4a_knowledge_fabric_v1.sql`;
- derived rollback/recovery with zero canonical-source mutation;
- `aos_wa4a_knowledge_authority_v1`;
- `aos_wa4a_knowledge_items_v1`;
- `aos_wa4a_knowledge_issues_v1`;
- private `aos_wa4a_knowledge_search_v1(...)`;
- `app/wa4-knowledge.js` least-data bundle + deterministic grounding validator;
- isolated SQL fixtures + retrieval/security tests;
- dedicated Zero-Cost workflow.

`app/wa4-knowledge.js` is intentionally **not wired into `server-wa4.js` or `wa4-copilot.js` in WA-4A**. Copilot remains SAFE-OFF. WA-4B may consume the certified contract after its own necessity gate.

## 9. Mandatory fail-closed behavior

- stale source → not answerable;
- conflicting source → not answerable;
- inactive/expired promo → not answerable;
- no governed fact → no fabricated business answer;
- unknown knowledge citation → reject;
- price not in cited governed facts → reject;
- hours not in cited READY HOURS facts → reject;
- branch/location claim without branch evidence → reject;
- human clinical/commercial escalation remains allowed without fabricating a fact.

## 10. Production boundary

WA-4A is built and certified in isolated TEST only. No WA-4A migration is to be applied to production while the owner-directed TEST-first/Supabase recovery hold is active.

Merging a PROD-ready package into GitHub is not database promotion and does not authorize Copilot, AI send, auto-reply, auto-routing, campaigns, Ads Sync or autonomous WhatsApp outbound.
