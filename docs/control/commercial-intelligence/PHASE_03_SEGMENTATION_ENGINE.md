# ASCENDA OS — COMMERCIAL INTELLIGENCE & AUDIENCE OS
## PHASE 3 — SEGMENTATION ENGINE

**Estado:** `100_COMPLETE`  
**Fecha de cierre:** 2026-08-13  
**Feature:** `feature/commercial-intelligence-phase3-segmentation-20260813`  
**PR feature → staging:** #57  
**CI:** Ascenda CI run 308 = SUCCESS  
**Merge funcional staging:** `cd00090ad7a949f15d6b90422ec2bedf775a26dd`  
**Modo:** SHADOW. Producción sin DDL Phase 3.

---

# 1. OBJETIVO CERRADO

Fase 3 establece una clasificación comercial multidimensional, versionada y explicable por `contact_key`, consumiendo Identity V1 + Commercial Facts V1.

Dimensiones:

- Value Tier: STANDARD / PREMIUM / GOLD / DIAMANTE;
- Lifecycle;
- Engagement: LOW / MEDIUM / HIGH;
- Commercial Traits multivalor.

No modifica `etiqueta_vip`, `SCORE_ESTADO`, `ESTADO_PACIENTE` ni fuentes operativas.

---

# 2. GATES FINALES

P3-G01…P3-G14 = PASS al persistir checkpoint final en `aos_memory`.

- P3-G01 Impact Report/sesgos: PASS
- P3-G02 baseline legacy/distribución: PASS
- P3-G03 policy registry versionado: PASS
- P3-G04 Value Tier: PASS
- P3-G05 Lifecycle: PASS
- P3-G06 Engagement: PASS
- P3-G07 Traits: PASS
- P3-G08 resolver 1:1: PASS
- P3-G09 shadow comparison: PASS
- P3-G10 tests/invariantes live: PASS
- P3-G11 performance: PASS
- P3-G12 seguridad privada: PASS
- P3-G13 CI + staging: PASS
- P3-G14 continuidad: PASS al checkpoint final

---

# 3. OBJETOS VERSIONADOS

Migration:

`supabase/migrations/20260813070000_cia_segmentation_engine_v1.sql`

Objetos:

- `aos_segmentation_policies`
- `aos_cia_current_segmentation_policy_v1`
- `aos_cia_customer_segments_v1`

Documentos:

- `FACT_REGISTRY_V1_2_PHASE3.md`
- `PHASE_03_VALIDATION_REPORT.md`

Scripts:

- `scripts/test_cia_segmentation_phase3.sql`
- `scripts/audit_cia_segmentation_phase3_readonly.sql`

---

# 4. POLICY V1

Policy family: `COMMERCIAL_SEGMENTATION`, version 1, status inicial `SHADOW`.

## Value Tier

Score = revenue points + frequency points + purchase-recency points.

- Revenue bands: 500 / 1,800 / 5,000 / 8,000.
- Frequency bands: 2 / 5 / 9 ventas.
- Recency: <=30 / <=90 días.
- DIAMANTE: score >=8 + revenue >=5,000 + >=5 ventas.
- GOLD: score >=6.
- PREMIUM: score >=3.
- STANDARD: resto/no compradores.

Distribución total:

- STANDARD 11,344
- PREMIUM 95
- GOLD 21
- DIAMANTE 13

## Lifecycle

Para clientes: `customer_last_activity_at=max(last_sale_at,last_attended_at)`.

Distribución:

- NEW_CUSTOMER 41
- ACTIVE_CUSTOMER 110
- COOLING_CUSTOMER 89
- INACTIVE_CUSTOMER 56
- APPOINTMENT_READY_PROSPECT 36
- ACTIVE_PROSPECT 965
- WARM_PROSPECT 1,849
- COLD_PROSPECT 1,534
- DISQUALIFIED_PROSPECT 1,313
- PROFILE_ONLY 5,480

794 contactos con terminal histórico fueron rescatados porque existe un lead posterior.

`REACTIVATED` se difiere hasta existir evidencia histórica suficiente en Commercial Facts.

## Engagement

- HIGH 77
- MEDIUM 176
- LOW 11,220

Revenue no participa en Engagement.

---

# 5. SHADOW VS LEGACY

Legacy VIP se mantiene intacto y solo se usa para auditoría comparativa.

La lógica legacy hallada depende principalmente de lifetime revenue; el shadow incorpora revenue + frecuencia + recencia y lifecycle/engagement separados.

Se detectaron perfiles `NORMAL` legacy que resultan DIAMANTE/GOLD/PREMIUM bajo la nueva policy, confirmando que la etiqueta física no debe ser la fuente maestra futura.

---

# 6. PERFORMANCE

Benchmark read-only representativo:

**~404.553 ms** sobre el universo de 11,473 contactos.

Resultado: PASS contra presupuesto P95 <1.5 s.

No se añaden materialización, cache ni índices nuevos en Fase 3.

---

# 7. SEGURIDAD

- policy table nueva con RLS habilitado;
- `PUBLIC/anon/authenticated` revocados;
- select inicial solo `service_role`;
- views `security_invoker=true`;
- sin SECURITY DEFINER;
- sin cambios de RLS fuente;
- sin cambios frontend/backend/Call Center/Email.

Post-merge staging, Supabase productivo continúa con 0 objetos Phase 3.

---

# 8. CERTIFICACIÓN

Las reglas fueron ejecutadas mediante equivalentes read-only contra datos vivos. La migration está versionada e integrada a staging, pero no se afirma despliegue físico de DDL en producción.

Fase 3 queda aprobada como dependencia de Fase 4 — Audience Resolver.
