# ASCENDA OS — F17 MULTICHANNEL CHANGE IMPACT REPORT V3

## Identificación

**Cambio:** CIA V3 F17 — SMS / WhatsApp / Future Channels  
**Fecha:** 2026-08-15 14:36 Lima  
**Rama:** `feature/cia-phase17-multichannel-20260815-v3`  
**Base exacta CURRENT main:** `f1f5861286e5dcf393dab79678ee8a7412478607`  
**Riesgo:** HIGH

## Objetivo

Extender el mismo Audience Engine a SMS, WhatsApp y futuros canales sin crear una verdad paralela de audiencia, lead o cliente por canal. El provider/backend debe permanecer intercambiable. Los hechos de mensajes, conversaciones, provider outcomes e inbound/outbound tracking deben enlazarse con identidad, activación y attribution canónicos.

## Gate F16 autoritativo — BLOQUEADO

Fresh production read-only preflight 2026-08-15 14:36 Lima:
- `aos_cia_kronia_f16_readiness_v1()` existe y retorna `ready_for_f16=true`, status `READY_GOVERNED_ORCHESTRATION`;
- `aos_cia_email_f17_readiness_v1()` NO existe (`to_regprocedure(...) = NULL`);
- por tanto no existe evidencia autoritativa de `READY_F17_EMAIL_CERTIFIED` ni `ready_for_f17=true`;
- GitHub Issue #104 permanece OPEN;
- F16 PR #114 permanece OPEN + DRAFT + unmerged;
- 11 tablas legacy Email todavía exponen 154 grants directos combinados a `anon`/`authenticated` en producción.

**Decisión:** no se autoriza ninguna mutación F17 en producción, provider activation ni spend. Solo discovery, diseño y CI sintético.

## CURRENT main / WhatsApp baseline

CURRENT main incluye WA-1, WA-2 y WA-3. El merge más reciente incorpora `WA-3: Boxes, Routing & Human Handoff`; su mensaje de merge registra exact-head `cacbf6ad...` con Zero-Cost DB lint, 70/70 pgTAP y contratos WA-1/WA-2/F4 green antes de merge.

WA-* se considera infraestructura de canal/facts/routing, nunca un Audience Engine alterno.

## Invariante dura

**NO duplicated audience/customer/lead tables per channel.**

F17 debe reutilizar Audience/Activation e identidades canónicas. Persistencia específica de canal solo puede representar endpoint identity, message/conversation/event/send-request/provider outcome/config/adapter state y siempre referenciar la verdad central.

## Contratos provider-neutral requeridos

1. endpoint de canal normalizado y enlazado a identidad canónica;
2. send request/message fact con idempotency key y activation/audience linkage;
3. provider outcome fact con provider event id único y replay-safe;
4. conversation/inbound event con provenance y attribution explícita;
5. consent/opt-out/suppression con UNKNOWN => fail-closed para marketing;
6. autorización server-authoritative, secrets solo en entorno, webhooks firmados y protegidos contra replay;
7. routing/handoff integrado con WA-3 sin crear ownership paralelo.

## Test plan previo a producción

- fixtures sintéticos, sin PII/PHI ni contenido real;
- normalización de teléfono/endpoint y negativos inválidos/ambiguos;
- duplicate send idempotency;
- duplicate/replayed webhook rejection;
- invalid signature / stale timestamp rejection;
- opt-out/suppression/UNKNOWN consent fail-closed;
- attribution linkage a Audience/Activation;
- routing/handoff linkage a WA-3;
- prueba estructural de cero tablas de audiencia paralelas;
- exact-head Zero-Cost/self-hosted CI, sin paid fallback;
- producción read-only preflight antes de cualquier migración/canary;
- rollback/recovery y zero-residue proof antes de certificación.

## Estado

- rama aislada desde CURRENT main: YES;
- Impact Report creado antes de cualquier cambio F17 en esta rama: YES;
- F16 certificado para F17: NO;
- F17 producción: BLOQUEADA;
- siguiente trabajo permitido: discovery/design/CI sintético solamente.
