# KRONIA V2 — K1 IDENTITY, SESSION & SECRETS HARDENING — IMPACT REPORT

**Estado:** READY FOR IMPLEMENTATION BRANCH — NO PRODUCTION CHANGE  
**Fecha:** 2026-08-13 America/Lima  
**Dependencia:** `KRONIA_V2_COMPLETE_AUDIT_20260813.md`  
**Riesgo:** CRITICAL

## Objetivo
Cerrar las fronteras de confianza de KronIA y agentes sin cambiar aún su UX funcional: identidad/rol server-authoritative, sesión segura, secretos fuera de superficie browser, tools sensibles no ejecutables directamente por roles públicos, endpoints privilegiados protegidos y auditoría confiable.

## Código afectado previsto
- `app/server.js`
- `app/public/kronia-core.js`
- consumidores de auth KronIA en `app/public/app.html` y `app/public/cerebro.html`
- `chrome-extension/*` únicamente si requiere compatibilidad de sesión
- tests/fixtures de seguridad

## Datos / DB previstos
- grants/policies de `aos_integraciones`
- grants/policies de `aos_usuarios` relacionados con exposición pública
- `aos_kronia_tokens`
- `aos_kronia_acciones`
- `aos_kronia_conversaciones`
- RPC `aos_kronia_*` sensibles
- `aos_editar_venta` y otras tools de escritura únicamente en su frontera de ejecución, sin alterar semántica comercial en K1

Toda DDL/GRANT/RLS debe entrar mediante migration versionada y backward-compatible.

## Consumidores
- chat principal KronIA
- Brain/cerebro/Brime
- Chrome extension
- agentes y endpoints `/api/agents/*`
- editor de ventas si consume RPC directa
- otros paneles que llamen RPC compartidas

Antes de revocar cualquier EXECUTE se debe generar matriz real de consumidores por búsqueda Git + logs/REST conocidos.

## Invariantes
1. El navegador nunca es autoridad de `rol`, `nivel`, `paneles`, `sede` o permiso de tool.
2. Ningún secret/API key se entrega a `anon`/`authenticated` vía REST.
3. Ninguna Tool HIGH puede ejecutarse mediante llamada directa pública a RPC saltándose el gateway.
4. KronIA conserva lectura/funcionalidad existente tras el hardening mediante gateway compatible.
5. Confirmaciones actuales no ganan nuevas capacidades en K1.
6. No modificar ventas/pacientes/citas históricas para probar.
7. No cortar Chrome/Brain sin ruta de compatibilidad probada.

## Implementación propuesta

### K1.1 — Consumer Matrix
- mapear todas las llamadas Git a cada RPC scoped;
- identificar calls directas desde navegador;
- clasificar READ / MUTATE;
- registrar dependencia por panel.

### K1.2 — Server Authoritative Identity
- crear resolver server-side de sesión/usuario;
- derivar rol/nivel/sede/paneles desde fuente canónica;
- ignorar role claims del body para autorización;
- mantenerlos solo como metadata no confiable si se requieren temporalmente.

### K1.3 — KronIA Session Contract
- sesión opaca vinculada a identidad real;
- expiración/revocación;
- token no usado como bearer de privilegios sin verificación;
- evitar almacenamiento de credenciales reutilizables innecesarias;
- proteger emisión/verificación/revocación.

### K1.4 — Secrets Boundary
- retirar `anon`/browser read/write de `aos_integraciones`;
- server obtiene secretos desde env/secret source autorizada;
- inventariar secretos heredados en source/config y preparar rotación separada;
- nunca registrar valores en CI/logs/audit docs.

### K1.5 — Tool RPC Boundary
- revocar ejecución pública de RPC MUTATE una vez que el gateway seguro esté listo;
- READ RPC se clasifican individualmente por sensibilidad;
- no depender de `p_rol` como autorización;
- mantener wrapper/gateway compatible para consumidores aprobados.

### K1.6 — Agent Endpoint Gate
- proteger `/api/agents/run|tick|chat|costs|status` según sensibilidad;
- CORS allowlist/origin policy;
- rate limiting y request limits aplicables;
- separar health público mínimo de datos internos.

### K1.7 — Audit Integrity
- solo gateway/rol interno autorizado puede escribir eventos de seguridad/acciones;
- browser roles no pueden UPDATE/DELETE/TRUNCATE auditoría;
- registrar auth failure, tool denied, tool proposed/executed y agent run.

## Tests obligatorios

### Auth negative tests
- caller válido + rol ADMIN falsificado → DENY privilegio;
- anon directo a RPC MUTATE → DENY;
- authenticated directo sin permission → DENY;
- token revocado/expirado → DENY;
- sesión A no puede usar proposal/session de B.

### Secrets
- anon SELECT `aos_integraciones` → no secret exposure;
- authenticated SELECT → no secret exposure;
- browser network trace no contiene provider keys.

### Compatibility
- admin/asesor KronIA chat READ funciona;
- Brain chat READ funciona;
- whisper/transcripción compatible hasta K5;
- Chrome extension auth path funciona o queda feature-gated con mensaje controlado;
- sales editor continúa funcionando por ruta autorizada.

### Regression
- `node --check app/server.js`;
- repository CI;
- Supabase lint/pgTAP;
- no unexpected diff fuera de scope;
- smoke staging por rol.

## Staging gates
1. aplicar migrations únicamente en entorno staging/fixture;
2. ejecutar consumer tests;
3. ejecutar bypass tests desde rol `anon` real;
4. validar navegador principal, Brain y Chrome;
5. medir logs de deny sin PII/secrets;
6. security scan final;
7. rollback rehearsal.

## Rollback
1. conservar definiciones/grants previos en migration compensatoria controlada;
2. no borrar funciones/tables en K1;
3. reactivar temporalmente solo el wrapper mínimo requerido si un consumidor legítimo falla;
4. revertir server gateway a versión previa sin restaurar exposición de secrets salvo decisión explícita de incidente;
5. repetir smoke/auth negative tests después del rollback.

## Criterio de cierre K1
K1 = 100_COMPLETE únicamente si los bypass directos están cerrados, los secretos no son accesibles a roles browser, identidad/rol son server-authoritative, consumidores siguen operativos, CI/staging/security scan están verdes y rollback fue probado.

## No incluido en K1
- Realtime Voice/WebRTC;
- Tool Registry V2;
- Modal Registry;
- Alarm/Watch Engine;
- nueva autonomía de agentes;
- cambios de lógica financiera/clínica.

Esos frentes dependen de K1 y no deben adelantarse.
