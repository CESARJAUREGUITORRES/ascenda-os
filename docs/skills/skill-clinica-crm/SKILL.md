---
name: skill-clinica-crm
description: Lógica de negocio específica de clínicas estéticas y wellness para AscendaOS. Usar cuando se construyan módulos de call center, pacientes, citas, ventas, comisiones o seguimientos. Contiene modelo de datos, terminología, flujos operativos y reglas de negocio validadas para la implementación clínica de referencia.
---

# Clínica CRM — AscendaOS / implementación de referencia

## CONTEXTO DEL NEGOCIO

La implementación de referencia opera múltiples sedes y perfiles (administración, asesoría, recepción y personal clínico). **Nunca almacenar credenciales reales, contraseñas, tokens o secretos en skills, prompts, README, ejemplos o memoria versionada.** Las credenciales pertenecen exclusivamente a los mecanismos de autenticación/secret manager autorizados.

## IDENTIDAD CANÓNICA DEL PACIENTE — REGLA MADRE

La identidad comercial/operativa ya no debe depender únicamente de `numero_limpio`.

Modelo objetivo:

`identificador de entrada → evidencia/alias gobernado → canonical_patient_id → historial/timeline`

Reglas:

- `canonical_patient_id` es el sujeto estable una vez certificado REV-F5;
- `numero_limpio/contact_key` sigue siendo útil para búsqueda/importación/compatibilidad;
- un paciente puede conservar múltiples teléfonos históricos como aliases;
- mismo nombre **no** implica misma persona;
- mismo teléfono **no** implica misma persona;
- teléfono aproximado o numéricamente cercano nunca es evidencia de identidad;
- mismo nombre+apellido+teléfono+documento exactos y sin conflictos puede ser candidato de máxima confianza, pero la fusión física sigue gobernada y reversible;
- mismo documento con teléfono cambiado puede ser evidencia fuerte, pero requiere reglas de compatibilidad/revisión;
- conflicto de DNI/DOB/sexo o identifier ya asignado a otro paciente bloquea auto-merge;
- filas absorbidas/fusionadas conservan provenance y aliases históricos;
- CIA, WA, F6, Patient 360 e importadores consumen la misma identidad F5; no crean otra verdad de cliente.

Contratos actuales:

- `docs/control/REV_PATIENT_IDENTITY_BRIDGE_V2_CONTRACT.md`
- `docs/control/REV_PATIENT_COMMERCIAL_360_V2_CONTRACT.md`
- `docs/control/REV_CUSTOMER_LIFECYCLE_IDENTITY_CONFIDENCE_CONTRACT.md`

## TAXONOMÍA DE BASES

### DIM1 — ESTADO operativo del lead/paciente

- Virgen → nunca contactado, nunca tuvo cita.
- SinContacto → contactado antes pero sin respuesta reciente.
- Contactado → se habló pero sin cita agendada.
- ConCita → tiene cita programada.
- PacienteActivo → vino al menos una vez, sigue activo.
- Inactivo → sin actividad según la ventana vigente.
- Provincia → fuera del ámbito operativo definido.
- Retirado → pidió no ser contactado.
- ConAdelanto → existe evidencia de adelanto; **no equivale automáticamente a deuda/saldo**.

### DIM2 — ORIGEN

- Campaña.
- Tratamiento/interés.
- Orgánico/referido.
- MesIngreso.
- BaseAntigua.
- PacientesHistóricos.

### DIM3 — AGENDA

- Asistió.
- NoAsistió.
- Canceló.
- CitaPendiente.
- ConVentaEnCita.
- ControlRecurrente.

## CUSTOMER LIFECYCLE REV-F6

El lifecycle analítico es independiente de los estados operativos anteriores y se deriva de hechos certificados:

- `NEW_PATIENT`
- `RETURNING_PATIENT`
- `HISTORICAL_REACTIVATED`
- `ACTIVE_REPEAT`
- `DORMANT`
- `UNRESOLVED_IDENTITY`

Toda métrica inferida debe exponer, cuando aplique: `coverage`, `confidence`, `freshness`, `sample_size` y período observado.

## SEMÁNTICA DE CAMPAÑA VS TRATAMIENTO

**CAMPAÑA** = gancho/origen de marketing que captó el lead.  
**TRATAMIENTO** = servicio realmente vendido/aplicado.

Nunca mezclar ambos campos en cálculos de conversión o producto real. REV-F3 es la autoridad de producto canónico de ventas; CIA es la autoridad de adquisición/atribución gobernada.

## DEFINICIÓN DE CONVERSIÓN

Una conversión debe estar respaldada por evidencia explícita del funnel correspondiente (por ejemplo cita/venta), con período y denominador definidos. No atribuir ventas a campañas mediante coincidencia ilimitada de teléfono.

## LÓGICA MADRE DE CALL CENTER

Priorización base:

1. Vírgenes mes actual.
2. No asistió cita reciente.
3. Vírgenes históricos.
4. Sin contacto mes actual.
5. Canceló o reprogramó.
6. Base antigua sin convertir.
7. Pacientes activos/recompra según ventana.
8. Sin contacto histórico.

El anti-duplicado diario de cola no sustituye la identidad canónica del paciente.

## TIPIFICACIONES DE LLAMADA

- CONTACTADO_INTERESADO
- CONTACTADO_NO_INTERESADO
- NO_CONTESTA
- BUZÓN
- NÚMERO_EQUIVOCADO
- CITA_AGENDADA
- REAGENDADO
- CANCELÓ
- VOLVER_A_LLAMAR
- PROVINCIA

## SEGUIMIENTOS PROGRAMADOS

Las ventanas de recompra/recontacto por tratamiento son reglas comerciales configurables y deben derivarse del producto/tratamiento canónico y de la última evidencia real, no de texto libre cuando exista F3.

## HISTORIA CLÍNICA / PRIVACIDAD

Identificación y campos clínicos sensibles requieren rol/política correspondiente. Notas clínicas, alergias, evaluaciones, imágenes y PHI no se exponen automáticamente a asesores, CIA o WA porque el Patient 360 comercial pueda resolver la identidad.

## ROLES Y PERMISOS

- ADMIN: administración y acciones críticas según auth/2FA y políticas.
- ASESOR: contexto comercial permitido, citas/notas comerciales y cartera asignada.
- RECEPCIÓN: agenda y datos básicos según política.
- DOCTOR/ENFERMERÍA: módulos clínicos según rol y regulación.

**Patient merge = CRITICAL.** Requiere admin+2FA, dry-run, evidencia, audit event, canary y rollback/recovery. Nunca autorizar por UI/browser role solamente.

## SCORE / RECENCIA

Los umbrales operativos históricos (por ejemplo 90/180 días) pueden usarse como defaults, pero REV-F6 debe versionarlos, mostrar el `as_of` y separar lifecycle analítico de etiquetas operativas legacy.

## FUNNEL DE CONVERSIÓN — MODELO ACTUALIZADO

Preferir enlaces explícitos y canonical identity:

`LEAD → lead_id_origen → LLAMADA → llamada_id_origen → AGENDA → venta_id_match/IDs explícitos → VENTA → F3 PRODUCTO → F4 REVENUE`

F5 resuelve el `canonical_patient_id` transversal.

`numero_limpio` queda como fallback/compatibility bridge, no como prueba de identidad ni atribución por sí solo.

KPIs deben definir claramente numerador, denominador, período, cobertura y fuente.

## PATIENT COMMERCIAL 360

Evolucionar el panel existente `app/public/patients.html`; no crear un segundo patient master.

Objetivo V2:

- canonical identity + aliases históricos;
- timeline lead/call/WA/agenda/sale/product/payment;
- lifecycle;
- revenue observado con cobertura temporal;
- identity confidence;
- coverage/freshness/sample-size para inteligencia;
- duplicate/merge audit state;
- separación estricta entre contexto comercial y PHI clínica.

## SENTINEL — DATA INTEGRITY

Sentinel debe poder observar invariantes agregados de identidad/revenue sin PII, según `docs/control/SENTINEL_DATA_INTEGRITY_SIGNALS_CONTRACT.md`, incluyendo source mismatch, member mismatch, identity collision, apply sin governance, sale/product orphan y reconciliation orphan.

## VERTICALES FUTUROS

Al adaptar a otros verticales, conservar la separación entre:

- identidad canónica;
- eventos/operación;
- producto/servicio;
- dinero/revenue;
- lifecycle/inteligencia;
- activación/canales;
- observabilidad.
