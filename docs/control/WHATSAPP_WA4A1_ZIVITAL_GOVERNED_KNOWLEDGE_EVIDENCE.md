# WA-4A.1 — Zi Vital Governed Knowledge

Status: TEST-first / PROD-ready / Copilot SAFE-OFF.

## Sources

1. `EL_SISTEMA_DE_DOMINIOS_ZI_VITAL.pdf` — internal authoritative source for Zi Vital system, domains, approaches, related treatments/products, profiles and process framing.
2. `PROCESO_ATENCIN_ZI_VITAL.pdf` — internal authoritative source for patient journey, roles, triage, consultation, quotation, consent, procedure and follow-up.

The PDFs are not ingested as an unstructured prompt corpus. Their concepts are transformed into governed nodes with source locators, explicit risk levels and audience-specific projections.

## Audience contract

- `PUBLIC_CLIENT`: short explanatory answers suitable for a client. No internal strategy, system metadata or clinical instructions.
- `ADVISOR_INTERNAL`: explanation/playbook context for advisors; includes the public summary but not owner/system internals.
- `OWNER_ADMIN`: strategic meaning and system metadata for owner/admin decisions.
- `CLINICAL_RESTRICTED`: clinically sensitive source content and restrictions. Must never be exposed by a public-client query.
- `SYSTEM_REFERENCE`: canonical taxonomy/relationships for system maintenance, catalog reconciliation and future updates.

## Canonical nodes

### System
- `ZV_SYSTEM` — sequence PREPARAR → ACTIVAR → REGENERAR → MANTENER; domains FACIAL/CORPORAL/CAPILAR; Detox/Vitaminas as cross-cutting concepts from the source.

### Facial
- `DOMAIN_FACIAL`
- `FACIAL_SKIN_SIGNATURE`
- `FACIAL_HARMONY_DESIGN`
- `FACIAL_BIOREGEN_FACE`

### Corporal
- `DOMAIN_CORPORAL`
- `CORPORAL_BODY_RESET`
- `CORPORAL_SCULPT_BODY` — alias `Contour Sculpt` retained as an alias, not a second concept.
- `CORPORAL_SCULPT_BOOTY` — alias `Volume & Firm` retained as an alias.

### Capilar
- `DOMAIN_CAPILAR`
- `CAPILAR_ACTIVACION_REGENERACION` — alias `Hair Revival`.
- `CAPILAR_MANTENIMIENTO_PREVENCION` — alias `Hair Guard`.

### Patient journey
- `ZV_PATIENT_JOURNEY`
- `PHASE_1_RECEPCION`
- `PHASE_2_TRIAJE`
- `PHASE_3_PRECONSULTA`
- `PHASE_4_CONSULTA_MEDICA`
- `PHASE_5_PLAN_COTIZACION`
- `PHASE_6_CONSENTIMIENTO_PROCEDIMIENTO`
- `PHASE_7_CIERRE_SEGUIMIENTO`
- roles: `ROLE_RECEPCIONISTA`, `ROLE_ENFERMERIA`, `ROLE_DOCTORA`.

Total seed: 23 governed nodes + 2 source records.

## Clinical governance decisions

The source documents contain clinical/physiological framing that is valuable internally but must not be converted into autonomous public claims. Examples include detox/depuration language and capillary protocols mentioning minoxidil/dutasteride, PRP, exosomes and PDRN. These nodes are marked `CLINICAL_REVIEW_REQUIRED` or HIGH where appropriate. Public projections describe the Zi Vital approach without prescribing, diagnosing or guaranteeing outcomes.

## Knowledge Fabric connection

`aos_wa4a_knowledge_search_v2(query,audience,limit,domains)` extends WA-4A V1 and projects exactly one audience-specific answer. `app/wa4-knowledge.js` accepts `CLINIC_KNOWLEDGE` and rejects rows whose embedded audience does not equal the requested bundle audience.

Knowledge authority remains:

`governed/certified source facts + evidence refs > approved derived knowledge > generic LLM knowledge`.

This phase connects the governed source to Knowledge Fabric only. It does **not** wire the new V2 search into `server-wa4.js`/Copilot and does not enable AI send, auto-reply or auto-routing.

## Canonical catalog relations seeded

Safe exact current catalog relationships are resolved when canonical catalog names exist, including selected Skin Signature, Body Reset, Sculpt Body and Capillary Activation services. Historical/product aliases remain references and must be reconciled against canonical catalog identities rather than creating duplicate products/services.

## Safety / rollback

- No patient, lead, sale or REV tables are read or mutated.
- No canonical catalog row is mutated.
- anon/authenticated have no direct table/RPC access.
- rollback removes only WA-4A.1 knowledge objects and leaves WA-4A V1/canonical sources intact.
