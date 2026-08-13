# ASCENDA OS — CIA PHASE 2 VALIDATION REPORT
## Commercial Facts Engine V1

**Fecha de cierre:** 2026-08-13  
**Feature:** `feature/commercial-intelligence-phase2-facts-20260813`  
**PR feature → staging:** #55  
**CI:** Ascenda CI run 293 = SUCCESS  
**Merge funcional staging:** `b71daf9e1c75cdee3dd6ced6a0288a73a3d4aecd`

---

# 1. RESULTADO

Fase 2 implementa en Git/staging el contrato V1 de Commercial Facts sobre Identity Resolver V1.

Objetos versionados:

- `aos_cia_interest_taxonomy_v1`;
- `aos_cia_lead_facts_v1`;
- `aos_cia_call_facts_v1`;
- `aos_cia_appointment_facts_v1`;
- `aos_cia_sales_facts_v1`;
- `aos_cia_followup_facts_v1`;
- `aos_cia_email_facts_v1`;
- `aos_cia_commercial_facts_v1`.

Migrations:

- `20260813063500_cia_commercial_facts_v1.sql`;
- `20260813063600_cia_commercial_facts_v1_1_email_fix.sql`.

No se modificó ninguna fila fuente ni contrato productivo existente.

---

# 2. VALIDACIÓN LIVE READ-ONLY

La migration no fue aplicada a Supabase productivo. Su semántica fue ejecutada mediante consultas read-only equivalentes sobre datos vivos.

Snapshot durante validación:

| Dominio | Filas fuente | Filas con contact_key válido | Contactos |
|---|---:|---:|---:|
| Leads | 5,403 | 5,391 | 5,076 |
| Calls | 34,188 | 33,999 | 5,885 |
| Appointments | 3,047 | 2,918 | 1,157 |
| Sales | 1,275 | 1,268 | 296 |
| Follow-ups | 524 | 523 | 456 |

Todos los contact keys válidos de esos dominios pertenecen al universo Identity V1: **0 claves fuera del contrato**.

---

# 3. LEAD OPPORTUNITY

Se comprobó que lifetime contact history y oportunidad actual son conceptos distintos.

- Lead contacts: 5,076.
- Lifetime lead contacts sin ninguna llamada: 0.
- `lead_unworked_since_latest_entry`: **1,287**.
- `lead_called_since_latest_entry`: **3,789**.
- 1,287 + 3,789 = 5,076: PASS.

Esto convierte `lead_unworked_since_latest_entry` en el fact canónico para “lead ingresado y todavía no trabajado después de su ingreso más reciente”.

---

# 4. CALLS

Normalización V1:

- `PROVINCIAS` → `PROVINCIA`;
- SIN CONTACTO / NO CONTESTA = no-contact operativo.

Sobre filas normalizadas:

- 33,999 llamadas;
- 6,651 con estado de interacción/resolución operativa;
- 27,348 no-contact;
- max `intento` observado: 77.

Benchmark de ranking + aggregate call-heavy representativo: **~260 ms**.

---

# 5. AGENDA

Sobre 2,918 filas válidas:

- 1,583 NO ASISTIO;
- 780 ASISTIO/EFECTIVA;
- 54 contactos con cita activa futura según política V1 (`PENDIENTE|CITA CONFIRMADA`, fecha >= hoy Lima).

Upcoming y latest se mantienen como hechos separados.

---

# 6. SALES / PRODUCT / SERVICE

Sobre 1,268 filas normalizadas:

- PRODUCTO: 403;
- SERVICIO: 865;
- partición mismatch: 0;
- revenue total: S/ 551,046.27;
- producto: S/ 60,286.50;
- servicio: S/ 490,759.77.

En la tabla completa actual `aos_ventas` se observaron 404 PRODUCTO + 871 SERVICIO = 1,275 filas; las diferencias corresponden exclusivamente a registros cuyo teléfono no produce contact_key V1.

---

# 7. FOLLOW-UPS

- 524 filas fuente;
- 523 normalizables;
- 456 contactos;
- 524/524 fechas programadas usan formato ISO `YYYY-MM-DD`;
- pending: 15;
- overdue V1: 509;
- completed: 2.

0 claves de seguimiento quedan fuera del universo Identity V1.

---

# 8. EMAIL RECONCILIATION

Fuentes canónicas de send count:

- `aos_emails_enviados`;
- `aos_email_envios` donde estado = enviado.

No se cuentan como send por sí mismas:

- `aos_email_flujo_ejecuciones`;
- `aos_email_cadencia`.

Corrección detectada durante el loop:

56 registros de `aos_emails_enviados` tienen `email_destino=''` y destinatario utilizable. Se corrigió el resolver para usar fallback mediante `NULLIF(TRIM(...),'')`.

Baseline final:

- unique sends: 1,942;
- safely mapped sends: **1,623**;
- unresolved sends: **319**;
- contacts with send evidence: 334;
- contacts with safe canonical email alias: 1,501;
- `email.never_sent=TRUE`: 1,167;
- `email.never_sent=UNKNOWN`: 9,972;
- HIGH direct-phone mappings actuales: 0.

Provider events:

- delivered: 968 total / 406 mapped / 108 contacts;
- bounced: 54 total / 46 mapped / 28 contacts;
- opened: 1 total / 0 mapped.

No se atribuyen los 319 sends no resueltos a ningún contacto.

---

# 9. BOOLEAN3

Validado como contrato:

- sent evidence → `email.never_sent = FALSE`;
- safe unique email + zero sends → TRUE;
- ausencia de alias/evidencia suficiente → NULL/UNKNOWN.

NULL nunca se transforma automáticamente a FALSE.

---

# 10. PERFORMANCE

Benchmarks read-only representativos:

- Call facts heavy ranking/aggregation: ~260 ms.
- Email identity + sends reconciliation: ~78 ms en medición aislada corregida.
- Composition representativa Identity + Leads + Calls + Agenda + Sales + Follow-up + Email sends: **~474 ms**.

Presupuesto V1: preview/count normal P95 < 1.5 s.

Resultado: PASS. No se justifica materialización/caché ni índices nuevos en Fase 2.

---

# 11. SEGURIDAD / BLAST RADIUS

Las migrations son aditivas:

- views `security_invoker=true`;
- no SECURITY DEFINER;
- no escritura;
- revocación a PUBLIC/anon/authenticated;
- select inicial solo `service_role`;
- no RLS fuente modificada;
- no Call Center modificado;
- no runtime frontend/backend modificado.

Después del merge a staging se verificó Supabase productivo:

- vistas `aos_cia_*`: 0;
- funciones `aos_cia_*`: 0.

Por tanto, producción permanece intacta.

---

# 12. ALCANCE DE LA CERTIFICACIÓN

Ascenda CI actual valida runtime JS/JSON/archivos críticos pero no ejecuta SQL migrations contra una base temporal.

No existe en este momento una Supabase development branch reutilizable; crear una nueva tiene un flujo de costo/confirmación separado.

Por ello la certificación de Fase 2 significa:

1. semántica SQL ejecutada read-only contra datos productivos;
2. invariantes y sumatorias reconciliadas;
3. migration revisada como paquete aditivo;
4. CI de repositorio SUCCESS;
5. integración Git a staging;
6. producción sin cambios.

La ejecución física de las migrations en un entorno DB desplegable sigue siendo un gate de despliegue, no una afirmación realizada en esta fase.

---

# 13. DECISIÓN

Commercial Facts V1 queda aprobado como dependencia de Fase 3.

Fase 3 — Segmentation Engine debe consumir `aos_cia_commercial_facts_v1` / Fact Registry V1.1 y no reconstruir facts directamente desde eventos fuente salvo para una nueva extensión formal del registry.
