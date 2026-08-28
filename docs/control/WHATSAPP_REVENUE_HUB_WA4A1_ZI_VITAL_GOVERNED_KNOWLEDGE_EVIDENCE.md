# WA-4A.1 — Zi Vital Governed Knowledge

**Boundary:** TEST-certified / PROD-ready only. This phase must not be applied to production while the base WA-4A Knowledge Fabric migration remains unapplied. Copilot/auto-reply/AI send remain SAFE-OFF.

## Sources and provenance

Two user-provided, direction-approved source documents are transformed into structured governed knowledge rather than copied as raw prompt text.

| source_key | title | pages | SHA-256 |
|---|---|---:|---|
| `ZI_DOMAINS_20260827` | EL SISTEMA DE DOMINIOS ZI VITAL | 14 | `cbb2a3cf2ff0458203004d41522595d5322c30dc1d084eb4e9c4f591b81ad901` |
| `ZI_ATTENTION_20260827` | PROCESO ATENCIÓN ZI VITAL | 8 | `ac9a61cfd19368a308f78e900b37108c24021ee419fe578cc7635f1000af3254` |

Every projected knowledge item carries `source_key`, page range, source version and source SHA-256 in `evidence_ref`.

## Canonical ontology

Final V1 model contains **26 canonical entities** and **130 audience projections** (26 × 5 audiences).

- System: `ZI_SYSTEM`
- Transversal principle: `ZI_SEQUENCE` = Preparar → Activar → Regenerar → Mantener
- Cross-layers: `ZI_LAYER_DETOX`, `ZI_LAYER_VITAMINS`
- Domains: `DOMAIN_FACIAL`, `DOMAIN_CORPORAL`, `DOMAIN_CAPILAR`
- Facial approaches: `APP_SKIN_SIGNATURE`, `APP_HARMONY_DESIGN`, `APP_BIOREGEN_FACE`
- Corporal approaches: `APP_BODY_RESET`, `APP_SCULPT_BODY`, `APP_SCULPT_BOOTY`
- Capilar approaches: `APP_HAIR_REVIVAL`, `APP_HAIR_GUARD`
- Care process: `CARE_PROCESS`
- Roles: `ROLE_RECEPCION`, `ROLE_ENFERMERIA`, `ROLE_DOCTORA`
- Care phases: `CARE_F1`…`CARE_F7`

The four procedural subphases in source document Phase 6 are structured inside `CARE_F6.system_reference`, not duplicated as standalone entities.

## Alias decisions

The source documents use some alternate labels. They are preserved as aliases instead of creating duplicate concepts:

- `Sculpt Body` ← alias `Contour Sculpt`
- `Sculpt Booty` ← alias `Volume & Firm`
- `Activación & Regeneración` ← alias `Hair Revival`
- `Mantenimiento & Prevención` ← alias `Hair Guard`

Product/treatment names written in the PDFs are **source evidence, not automatic catalog identities**. Historic or informal strings such as `NF cap`, `Perfect-B`, `Perfect-F`, or document-specific spellings do not create new SKUs or mutate existing catalog rows.

## Audience governance

| Audience | Purpose | Retrieval behavior |
|---|---|---|
| `PUBLIC_CLIENT` | Short, useful client explanation | Explicit audience required; max model reply 480 chars |
| `ADVISOR_INTERNAL` | Advisor guidance and explanation logic | Explicit audience required; no public fallback |
| `OWNER_ADMIN` | Strategic, architecture and management knowledge | Explicit audience required |
| `CLINICAL_RESTRICTED` | Clinical context from the approved documents | High-risk, `answerable=false`, `requires_human=true`; adapter requires `HUMAN_CLINICAL` |
| `SYSTEM_REFERENCE` | Canonical ontology, aliases, source terminology and update logic | Explicit audience required; full structured source reference available |

There is no implicit cross-audience fallback. Zi Vital rows fail closed when no audience is supplied.

## Client-answer contract

Client-facing knowledge is deliberately concise. Example governed reasoning supported by the source:

- Query concept: “La doctora me dijo que mi dominio era facial; me hice Pink Glow y no sé cuál es mi enfoque.”
- Retrieval: `PUBLIC_CLIENT` → `APP_SKIN_SIGNATURE`, because `Pink Glow` is source-linked to Skin Signature.
- Intended response style: brief explanation that Pink Glow is commonly located within Skin Signature in the Zi Vital framework, with a caveat that an individual medical plan can combine approaches.

The bot must not expose advisor playbooks, owner strategy, clinical-restricted details or the full source-reference payload in a public answer.

## Clinical boundary

The domain document contains medical/procedural references including minoxidil, dutasteride, PRP, exosomes and PDRN. These are preserved only as source-grounded internal/clinical context. The system must never infer an autonomous prescription, diagnosis or treatment indication from them.

`CLINICAL_RESTRICTED` evidence requires human clinical escalation in `app/wa4-knowledge.js`.

## Care-process boundary

The care document is represented as a seven-phase process with three non-overlapping roles:

1. Reception/opening
2. Conscious triage
3. Prior explanation of process/approaches
4. Personalized medical consultation
5. Plan/cotization/decision
6. Consents/preparation/procedure
7. Close/follow-up

The ten triage questions are preserved in `CARE_F2.system_reference.triage_questions`. Public projections do not expose the complete internal questionnaire automatically.

## Knowledge Fabric integration

WA-4A.1 connects the derived Zi Vital source to the existing Knowledge Fabric **contract**, not to autonomous Copilot execution:

- `aos_wa4a1_zi_knowledge_items_v1` emits rows compatible with the WA-4A evidence/freshness/retrieval shape.
- `aos_wa4a1_zi_knowledge_search_v1(query,audience,limit)` performs audience-scoped retrieval.
- `app/wa4-knowledge.js` accepts `ZI_VITAL` and enforces audience isolation, short public responses and clinical-human escalation.
- `app/server-wa4.js` and `app/wa4-copilot.js` remain unwired to `wa4-knowledge`; no autonomous answer path is enabled in this phase.

This is deliberate sequencing: **govern source → prove isolation/safety → integrate Knowledge Fabric contract → only later wire Copilot/Playbook behavior.**

## Security / least-data

- New source/entity tables, derived view and search RPC are denied to `anon` and `authenticated`.
- `service_role` is the only runtime role granted direct read/search access.
- No patient, lead, sale or REV identity table is read or mutated.
- No existing catalog/promotion/branch/hour/category source is mutated by the WA-4A.1 migrations.
- Generic LLM knowledge remains non-authoritative under WA-4A.

## TEST certification gates

Dedicated Zero-Cost CI proves:

- adapter syntax and legacy WA-4A adapter regressions;
- 8 audience/grounding Node tests;
- exactly 2 source documents;
- exactly 26 entities / 130 projected knowledge rows;
- 26 projections for each audience;
- aliases and page/hash provenance;
- 10 triage questions and 4 Phase-6 subphases;
- `Pink Glow` → `Skin Signature` retrieval in `PUBLIC_CLIENT` and `ADVISOR_INTERNAL` independently;
- no public cross-audience leakage;
- `dutasteride` clinical retrieval is human-only;
- anon/auth ACL denial and service-role access;
- existing WA-4A Knowledge Fabric regression;
- rollback removes only WA-4A.1 and leaves base WA-4A/canonical sources unchanged;
- reapply is deterministic.

## Production boundary

**Do not apply these migrations to PROD yet.** Production currently has the business-data/catalog improvements, but the base WA-4A feature migration remains deliberately unapplied under the current Supabase HTTP 402 recovery strategy.

PROD promotion order after recovery must remain dependency-safe:

1. Revalidate current `main` and PROD drift.
2. Apply base WA-4A migration and prove readback.
3. Apply WA-4A.1 schema + seeds in timestamp order.
4. Prove ACL/provenance/audience retrieval.
5. Keep Copilot SAFE-OFF until its later integration gate.
