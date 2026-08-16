# Sentinel — F1 Governance, Privacy & Cost Policy

**Estado:** CURRENT / CANONICAL / F1  
**Fecha:** 2026-08-16 (America/Lima)  
**Workstream:** `SENTINEL`  
**Control Maestro:** `docs/control/SENTINEL_CONTROL_MASTER.md`  
**Roadmap:** `docs/control/SENTINEL_ROADMAP_V1.md`

---

## 1. Propósito

Esta política define la frontera obligatoria antes de que Sentinel exporte telemetría real desde ASCENDA OS. F1 no instrumenta producción: establece qué puede observarse, qué está prohibido exportar, cuánto puede costar, cómo se desactiva y qué evidencia es necesaria para habilitar fases posteriores.

## 2. Decisión de arquitectura

Sentinel adopta una arquitectura **híbrida y vendor-neutral**:

- Sentry: sensor especializado de errores/stack traces y debugging de alta señal.
- OpenTelemetry: contrato portable de traces/metrics/logs y futura capa de filtering, redaction, transformation y sampling.
- Uptime Kuma: disponibilidad externa cuando exista hosting 24/7 aprobado.
- Sentinel Core: topología, business-health, estado e incidentes `SEN-*`.
- GitHub/Railway/Supabase: fuentes técnicas y de runtime ya existentes; Sentinel las correlaciona, no las reemplaza.

Ningún backend externo es requisito para que Sentinel Core pueda existir. La indisponibilidad de Sentry debe degradar observabilidad, nunca la operación clínica/comercial de ASCENDA.

## 3. Anti-scope F1

F1 **NO** autoriza:

- instalar `@sentry/*` en producción;
- definir `SENTRY_DSN` en Railway;
- activar tracing productivo;
- activar Session Replay;
- exportar logs productivos;
- desplegar OpenTelemetry Collector productivo;
- desplegar Uptime Kuma en infraestructura pagada;
- crear tablas/RPC Sentinel en Supabase;
- crear Telegram bot productivo;
- activar Diagnostic Runner, AI triage o remediation;
- crear el panel Sentinel Hub;
- introducir pay-as-you-go o upgrades pagados.

Esas capacidades pertenecen a fases posteriores y requieren sus propios gates.

## 4. Regla Zero-PHI/PII Telemetry

La telemetría externa se considera un boundary no confiable para datos clínicos/personales. El modelo es **allowlist-first**: si un atributo no está expresamente permitido, no se exporta.

### 4.1 Datos prohibidos

Nunca deben salir como evento, tag, breadcrumb, log, span attribute, attachment, replay, query string o payload:

- nombre/apellidos de pacientes, leads, clientes, trabajadores o terceros;
- DNI/documentos, teléfonos, emails, direcciones, fecha de nacimiento;
- IDs de paciente/lead/persona, incluso hash estable, salvo revisión futura específica;
- historias clínicas, diagnósticos, notas, evoluciones, prescripciones, alergias, fotos y documentos;
- contenido de WhatsApp, SMS, email o chat;
- prompts/respuestas de IA que contengan contenido de usuario/paciente;
- cuerpos de requests/responses con datos de negocio o personales;
- cookies, `Authorization`, JWT, app tokens, OTP, session tokens;
- API keys, service-role, webhook secrets, passwords, private keys;
- raw webhook bodies;
- archivos subidos;
- datos financieros a nivel transacción/persona: monto de pago individual, tarjeta, comprobante, saldo individual;
- IP del usuario como atributo persistente cuando pueda evitarse;
- URL/query con identificadores o contenido aportado por usuario.

### 4.2 Atributos permitidos por defecto

Se permiten únicamente metadatos técnicos no personales necesarios para diagnóstico:

- `system=ascenda-os`;
- `environment`;
- `service.name`;
- `service.version` / `release`;
- `module`;
- `component`;
- `capability`;
- `dependency`;
- `severity`;
- `event_type` técnico;
- ruta normalizada/template sin parámetros personales ni query string;
- método HTTP;
- status HTTP/status class;
- duración/latencia;
- `request_id` aleatorio no derivado de identidad;
- `trace_id` aleatorio;
- `commit_sha`;
- `deployment_id` no secreto;
- nombre de sede solo cuando sea estrictamente operativo y no permita identificar a una persona;
- conteos agregados/no identificables cuando exista una regla explícita de minimización.

### 4.3 Identidad

No se utilizará `user.id`, email, teléfono, DNI ni hash estable de persona como tag de observabilidad en la baseline. Si una fase futura necesita correlación por actor, deberá demostrar necesidad, minimización, pseudonimización no reversible y aprobación de seguridad antes de habilitarla.

## 5. Sanitización obligatoria

Toda integración futura que exporte telemetría debe aplicar dos capas como mínimo:

1. sanitización local antes de transmitir (`beforeSend`, processors OTel o equivalente);
2. data scrubbing en el backend externo cuando exista.

La segunda capa nunca sustituye a la primera.

Toda suite de instrumentación debe incluir tests negativos con fixtures sintéticos que contengan campos señuelo sensibles y demostrar que no aparecen en la salida exportable.

## 6. Session Replay y captura de contenido

Baseline Sentinel:

- Session Replay: **OFF**;
- attachments: **OFF**;
- request/response body capture: **OFF**;
- console/raw application logs a backend externo: **OFF**;
- AI prompt/output capture: **OFF**;
- DOM/form capture de áreas clínicas/comerciales: **OFF**.

Cualquier cambio requiere una fase/Impact Report específico y no puede activarse por configuración accidental.

## 7. Ambientes canónicos

- `development`: local; solo fixtures sintéticos.
- `zero-cost`: CI/staging efímero; fixtures sintéticos, sin secretos productivos ni PHI/PII real.
- `staging`: solo cuando exista una necesidad concreta; no asume datos productivos y debe mantener minimización.
- `production`: telemetría mínima, sanitizada y solo después del gate de la fase que la habilite.

Nunca mezclar eventos de ambientes bajo el mismo valor de `environment`.

## 8. Kill switches

Las fases posteriores deben implementar control independiente por capacidad. Nombres canónicos iniciales:

- `SENTINEL_ENABLED`
- `SENTINEL_SENTRY_ENABLED`
- `SENTINEL_OTEL_EXPORT_ENABLED`
- `SENTINEL_BUSINESS_PROBES_ENABLED`
- `SENTINEL_TELEGRAM_ENABLED`
- `SENTINEL_DIAGNOSTIC_RUNNER_ENABLED`
- `SENTINEL_AI_TRIAGE_ENABLED`
- `SENTINEL_REMEDIATION_ENABLED`

Regla: desactivar telemetría externa no debe tumbar ASCENDA. Sentinel debe fallar de forma aislada y reportar `UNKNOWN` cuando no pueda observar una capacidad.

Para automatización/remediation, cualquier duda o pérdida de control debe ser **fail-closed**.

## 9. Presupuesto y límites económicos

### 9.1 Presupuesto inicial autorizado

**Costo incremental cloud autorizado para F1: US$0/mes.**

No se autoriza automáticamente:

- pay-as-you-go;
- upgrade de Sentry;
- GitHub-hosted runners;
- Supabase/Railway staging adicional pagado;
- hosting 24/7 adicional para Kuma;
- almacenamiento/retención adicional facturable.

Cualquier gasto nuevo requiere Impact Report con necesidad, alternativa cero-costo descartada, costo mensual/variable, límite máximo, rollback/borrado y autorización expresa del propietario.

### 9.2 Sentry baseline observada 2026-08-16

El plan Developer se toma como baseline inicial de evaluación, no como contrato perpetuo. Antes de ampliar consumo o contratar se deben revalidar precios/cuotas vigentes.

Budget operativo Sentinel para la primera activación Sentry:

- errors: objetivo interno <= 2,500/mes durante baseline;
- warning interno al 50% de la cuota gratuita vigente;
- protective review al 80%;
- logs externos: 0 en baseline;
- Session Replay: 0 en baseline;
- application metrics Sentry: 0 en baseline;
- tracing/spans: OFF inicialmente; cualquier sampling >0 se autoriza en F4 después de medir error volume;
- pay-as-you-go: OFF.

Alcanzar una cuota nunca autoriza gasto automático. La respuesta segura es reducir/suspender señal no crítica y revisar sampling/filtering.

## 10. Asignación de responsabilidades por herramienta

| Necesidad | Herramienta primaria | Regla |
|---|---|---|
| Exceptions/stack traces | Sentry | alta señal, payload mínimo |
| Contrato portable de telemetría | OpenTelemetry | vendor-neutral |
| Filtering/redaction/sampling | OTel + SDK local | antes de exportar |
| Uptime externo | Uptime Kuma | solo con observador 24/7 independiente aprobado |
| Fallo funcional silencioso | Sentinel Business Health | no depender de excepciones |
| Incident ID / estado | Sentinel Core | `SEN-*` canónico |
| Código/release/CI | GitHub | fuente técnica |
| Runtime/deploy | Railway | fuente de deployment |
| Estado mínimo Sentinel futuro | Supabase | objetos versionados, mínimo privilegio |
| Alertas owner | Telegram | canal, no fuente de verdad |

## 11. Retención y minimización

- conservar únicamente la evidencia mínima que permita diagnóstico;
- preferir IDs/referencias a duplicar payloads;
- no adjuntar dumps, XLSX, imágenes o mensajes a incidentes;
- no retener telemetría externamente “por si acaso”;
- cada backend futuro debe documentar retención y borrado;
- los postmortems no deben copiar PHI/PII/secrets.

## 12. Respuesta ante fuga de telemetría

Si se sospecha que una señal exportó información prohibida:

1. desactivar inmediatamente el exporter/sensor mediante kill switch;
2. mantener ASCENDA operativa;
3. registrar finding de seguridad sin repetir el dato filtrado;
4. identificar backend, intervalo y tipo de dato;
5. borrar/solicitar borrado cuando sea posible;
6. rotar credenciales si algún secreto pudo exponerse;
7. corregir redaction/filtering y agregar test negativo;
8. reactivar solo después de security review y evidencia.

## 13. Vendor lock-in guard

Sentinel Hub, Incident Engine y Business Health no pueden requerir la API de Sentry para operar. Sentry puede aportar links/evidencia enriquecida, pero la salud global y el historial `SEN-*` deben sobrevivir a:

- Sentry temporalmente caído;
- agotamiento de cuota;
- cambio de plan;
- migración futura a GlitchTip/u otro backend;
- desactivación deliberada del exporter.

## 14. Reglas para secretos de configuración

- DSN/tokens/config externa se gestionan por variables de entorno/secret manager;
- no se hardcodean en GitHub, Notion, prompts o screenshots compartidos;
- documentación usa solo nombres de variables;
- no imprimir prefijos/longitudes que ayuden a reconstruir secretos;
- los tests usan valores sintéticos no válidos.

## 15. Definition of Done F1

F1 solo puede certificarse `100_COMPLETE` cuando:

1. current `main` y baseline runtime están verificados;
2. Control Maestro y roadmap de 13 fases están versionados;
3. esta política está versionada;
4. Zero-PHI/PII allowlist/denylist está definida;
5. ambientes y kill switches están definidos;
6. presupuesto US$0 y no-auto-billing están definidos;
7. arquitectura vendor-neutral está explícita;
8. anti-scope demuestra que F1 no instrumenta producción;
9. existe contrato automático de gobernanza;
10. contrato corre en self-hosted CI sin fallback facturable;
11. PR F1 contiene solo docs/control/CI, sin runtime, DB o secretos;
12. exact-head CI es PASS;
13. PR canónico se integra a `main`;
14. Validation Report final queda `100_COMPLETE`;
15. Notion F1 se marca `Cerrada/100%` y F2 queda como única `Siguiente`.

Hasta entonces, F1 permanece `EN CURSO`.