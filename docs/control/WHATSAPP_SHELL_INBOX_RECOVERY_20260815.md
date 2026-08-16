# ASCENDA Conversations — Shell Integration & Inbox Recovery

**Fecha de cierre:** 2026-08-15 (America/Lima)  
**Estado:** RESUELTO / LECCIONES CAPTURADAS  
**Baseline visible al cierre:** `main@73990606d3e5aa89c2e4eade163ab6a2faf206a3`

## 1. Resultado logrado

Se logró completar el primer flujo visible end-to-end de WhatsApp dentro del shell principal de ASCENDA:

`Meta/WhatsApp → gateway firmado → ledger WA-1 → conversation store WA-2 → routing/ownership WA-3 → sesión ASCENDA → WhatsApp Hub embebido → conversación visible → mensaje inbound visible`.

Evidencia productiva al cierre:

- conversación real `zi vital` / `51960618468`;
- estado `HUMAN_ACTIVE`;
- owner asignado al administrador canary;
- mensaje inbound real `ASCENDA INBOUND REAL 02` visible en timeline;
- conversación de prueba adicional visible;
- WhatsApp Hub renderizado dentro del workspace central de ASCENDA;
- recovery automático reportando `WA-3 recuperado automáticamente`.

## 2. Problema original

WA-2 fue construido deliberadamente como shadow page `/admin-whatsapp.html` y no como panel nativo dentro de `app.html`. WA-3 añadió routing, boxes, ownership y human handoff, pero la integración al shell central quedó pendiente.

El resultado era funcionalmente confuso:

- WhatsApp se abría como una superficie separada;
- la sesión/tab podían no compartir el mismo `sessionStorage`;
- el usuario salía del contexto operativo de ASCENDA;
- se intentaba corregir autenticación cuando la causa principal también era de composición UI.

## 3. Causas raíz

### RC-1 — Shadow page ≠ módulo nativo

Tener `/admin-whatsapp.html` funcionando no significa que el producto esté integrado al shell. Debe existir explícitamente:

- entrada de sidebar;
- permiso de panel;
- route/view contract;
- montaje dentro del workspace canónico;
- preservación del contexto de sesión.

### RC-2 — `sessionStorage` es tab-scoped

El token 2FA fuerte estaba disponible en la pestaña principal de ASCENDA, pero una navegación/pestaña independiente no puede asumir que `sessionStorage` se comparte.

Solución aplicada: el service worker usa el cache same-origin gobernado `aos-phase2-auth` para inyectar `X-AOS-App-Token` en las APIs WhatsApp. La autorización final continúa ocurriendo server-side; el bridge no concede permisos.

### RC-3 — Bootstrap demasiado frágil

El frontend WA-3 ejecutaba:

`boot().then(refreshInbox)...`

Si `/api/wa3/bootstrap` fallaba una sola vez, no se ejecutaba `refreshInbox`, no había retry persistente y el usuario veía la maqueta inicial vacía aunque la base tuviera conversaciones.

La captura con `Routing & Handoff` vacío fue evidencia clave: no era solo inbox vacío; el bootstrap no había completado.

### RC-4 — Dependencias auxiliares no deben tumbar el inbox

El bootstrap WA-3 agrupa control, boxes, members y users. Una lectura auxiliar transitoria no debería volver invisibles conversaciones existentes.

Principio aprendido: **el inbox es una capacidad crítica y debe degradar funcionalidad auxiliar antes que desaparecer**.

### RC-5 — Cache/service worker puede conservar comportamiento antiguo

Cambiar el archivo JS no basta si el HTML inyectado conserva la misma URL/version. Se requirió bump explícito del asset para forzar recuperación limpia.

## 4. Hotfixes que resolvieron el incidente

### `e89f950cd354d3909f3d64692c2cd5d615b2aa61`
`Hotfix WA shell: mount WhatsApp inside ASCENDA workspace`

- creó `app/public/wa-shell-integration.js`;
- agregó `WhatsApp Hub` al sidebar según permisos;
- preparó `whatsapp-agent` para agentes explícitamente autorizados;
- montó WA-3 same-origin dentro del workspace.

### `5857f83b8607680f2c94141e2a7128696eef3401`
`Hotfix WA shell: integrate WhatsApp with canonical app navigation`

- inyectó la integración mediante el service worker;
- convirtió el acceso directo antiguo en compatibility entrypoint hacia el shell principal.

### `63f75730539579d634d6b3b77ef03af2f5dc95c3`
`Hotfix WA shell: recover inbox when WA3 bootstrap aborts`

- añadió recovery automático desde el shell;
- reintenta WA-3;
- permite recuperar conversaciones aunque el bootstrap auxiliar no complete;
- muestra diagnóstico persistente en el panel derecho.

### `fc1476a1136f2d5d2af0bf813dafc5f8cab370f1`
`Hotfix WA shell: bridge token to WA2 recovery API`

- extendió el bridge 2FA a `/api/wa/*` además de `/api/wa3/*`;
- habilitó fallback WA-2 manteniendo autorización server-side.

### `73990606d3e5aa89c2e4eade163ab6a2faf206a3`
`Bump WA shell recovery asset version`

- forzó carga del recovery asset actualizado y evitó cache viejo.

## 5. Patrón de recovery aplicado

Orden de degradación:

1. UI WA-3 normal;
2. retry de `/api/wa3/bootstrap`;
3. lectura `/api/wa3/inbox` aunque bootstrap auxiliar falle;
4. fallback read-only a `/api/wa/inbox` de WA-2;
5. diagnóstico persistente visible;
6. nunca fallback a escritura legacy insegura.

Esto se considera un patrón reusable para interfaces críticas.

## 6. Invariantes de seguridad preservados

- el navegador no recibe `service_role`;
- el bridge de token no sustituye autorización;
- `aos_app_actor_v3`/WA-3 actor sigue validando panel + 2FA;
- el fallback WA-2 también exige sesión autorizada;
- no se reabrió el webhook unsigned;
- no se concedió `whatsapp-agent` automáticamente;
- IA outbound permanece OFF;
- los stores WA siguen con acceso server-side;
- rollback conserva evidencia y no borra chats.

## 7. Lecciones de diagnóstico

1. **Primero verificar la verdad en DB.** Si existen conversación y mensajes, no diagnosticar “Meta no está llegando”.
2. **Leer la pantalla como evidencia.** Sidebar correcto + panel derecho vacío + maqueta central = bootstrap abortado.
3. **Separar capas:** ingress, storage, authorization, API, shell, cache y UI.
4. **No arreglar síntomas de una capa con parches en otra.** Un problema de shell no se resuelve solo con auth.
5. **Validar permisos reales** (`paneles_acceso`) antes de culpar al frontend.
6. **Recovery debe ser visible y fail-closed**, no silencioso.
7. **Un sistema crítico no puede depender de un único Promise chain sin retry/degradación.**

## 8. Deuda técnica que NO debe confundirse con el incidente cerrado

El incidente de visibilidad está resuelto, pero quedan tareas de producto:

- eliminar la dependencia permanente del recovery una vez estabilizado bootstrap WA-3;
- certificar respuesta humana real desde el composer;
- convertir boxes de prueba en boxes de negocio;
- habilitar y evaluar WA-4 copilot;
- desarrollar WA-5 multimedia;
- desarrollar WA-6 agenda/follow-up;
- desarrollar WA-7 attribution/revenue;
- cerrar WA-8 production/cost governance.

## 9. Regla reusable

> Nunca declarar “WhatsApp integrado” únicamente porque el webhook responde o existe una página de inbox. La certificación mínima requiere: evento real persistido, conversación proyectada, identidad/autorización correcta, panel montado dentro del producto, timeline visible y recovery probado.
