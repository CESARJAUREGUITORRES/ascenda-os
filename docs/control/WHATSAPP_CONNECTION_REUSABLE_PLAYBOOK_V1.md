# Reusable Playbook V1 — WhatsApp Cloud API + CRM/OS Integration

**Origen:** lessons learned from ASCENDA Conversations 2026-08-14/15  
**Objetivo:** patrón reusable para futuros proyectos sin copiar secretos, tablas o decisiones específicas de Zi Vital.

## 0. Principio rector

No construir “un chatbot de WhatsApp”. Construir una **frontera conversacional gobernada** que conecte:

`Campaign/Organic → WhatsApp Cloud API → secure gateway → message ledger → conversation store → routing/ownership → human/AI → business tools → outcome/revenue`.

Cada capa debe poder probarse y recuperarse por separado.

## 1. Fase A — Discovery antes de tocar código

Inventariar primero:

- CRM/sistema existente;
- identidad de cliente y normalización de teléfono;
- lead/campaign provenance;
- agenda/booking existente;
- catálogo/precios;
- usuarios/roles/permisos;
- infraestructura runtime;
- secretos existentes;
- tablas/chat interno que **no** deben reutilizarse;
- estado real del webhook/productive WABA.

Regla: no crear un CRM paralelo si ya existe una fuente de verdad.

## 2. Fase B — Secure WhatsApp Gateway

### Inbound

Requisitos mínimos:

- `GET /webhook` para challenge;
- `POST /webhook` con `X-Hub-Signature-256` obligatorio;
- HMAC SHA-256 sobre bytes exactos del body;
- payload size limit;
- fail-closed si falta `APP_SECRET`/config;
- parser normalizado para messages/status/referral;
- idempotencia por `provider_message_id` / `event_key`.

### Outbound

- sender server-side;
- `idempotency_key` obligatoria;
- canary/allowlist al inicio;
- templates/media/text soportados explícitamente;
- ledger de requests y estados;
- jamás token de Meta en frontend.

### Secret boundary

Variables sensibles únicamente en runtime/Vault:

- Meta verify token;
- app secret;
- access token;
- phone number ID;
- service-role/database privileged key;
- provider AI keys.

Nunca guardar valores en Git, documentación, prompts o browser-readable catalogs.

## 3. Fase C — Message Ledger separado del Conversation Store

### Ledger

Tabla append/update-by-provider-id que conserva la evidencia normalizada del mensaje:

- provider message id;
- direction;
- from/to;
- type/body/media reference;
- provider timestamps;
- delivery/read/failure;
- provenance mínima;
- actor cuando sea outbound.

### Conversation projection

No copiar mensajes. Crear una proyección por conversación con:

- deterministic conversation key;
- contact/phone channel;
- state;
- last message;
- unread count;
- first/last inbound/outbound;
- campaign/lead provenance;
- owner/box cuando corresponda.

### Lección crítica de idempotencia

No incrementar contadores en un trigger que también pueda correr ante `ON CONFLICT`. Separar:

1. bind conversation;
2. project only genuinely inserted message.

## 4. Fase D — Auth + permisos

Todo inbox operativo requiere autorización server-side.

Patrón recomendado:

- token fuerte de sesión;
- 2FA cuando el negocio lo justifique;
- panel/permission explícito;
- segunda validación de rol/nivel para vistas sensibles;
- service-role solamente detrás del servidor;
- RLS/FORCE RLS o equivalente en stores privados.

No confiar en esconder rutas del menú.

## 5. Fase E — Live Inbox

Primera versión debe ser read-mostly:

- lista de conversaciones;
- timeline;
- unread;
- search;
- provenance;
- mark read;
- health endpoint;
- polling acotado o Realtime medido.

Antes de construir IA, demostrar que un **evento real** llega y es visible.

## 6. Fase F — Shell integration

Una shadow page sirve para canary, pero no es el producto final.

Checklist para integración real:

- sidebar/navigation entry;
- permission-aware visibility;
- route/view registry;
- canonical workspace mount;
- same-origin context;
- topbar/sidebar preservados;
- CSS aislado para que un panel no contamine al shell;
- acceso directo legacy redirigido al shell.

### Técnica útil

Si el panel heredado es un HTML completo con estilos globales, un iframe same-origin puede ser un puente seguro temporal para aislar CSS mientras se migra a componente nativo.

No usarlo como excusa para mantener dos aplicaciones para siempre.

## 7. Fase G — Session bridge y service worker

Problema reusable: `sessionStorage` es tab-scoped.

Si una arquitectura usa páginas/iframes same-origin y el token fuerte debe viajar entre superficies:

- almacenar el token de forma gobernada en un mecanismo same-origin apropiado;
- inyectarlo solo en endpoints allowlisted;
- mantener validación final en servidor;
- usar `Cache-Control: no-store`;
- versionar assets/service worker explícitamente.

Nunca convertir el bridge en una autorización client-side.

## 8. Fase H — Resilient bootstrap

No diseñar:

`bootstrap().then(inbox()).then(messages())`

sin recovery.

Diseño robusto:

- timeout controlado;
- retry con backoff;
- `Promise.allSettled` o fallbacks independientes para datos auxiliares;
- inbox crítico debe cargar aunque falle un panel lateral;
- fallback read-only a una capa inferior certificada;
- status persistente visible al operador;
- recovery nunca habilita escrituras legacy inseguras.

### Degradation ladder recomendada

1. full operational mode;
2. partial mode sin analytics/auxiliares;
3. read-only inbox;
4. health/diagnostic mode;
5. fail closed para writes.

## 9. Fase I — Boxes, routing y ownership

Separar WhatsApp de la cola de llamadas aunque existan patrones compartidos.

Objetos mínimos:

- boxes;
- box members;
- assignments;
- routing events;
- global controls.

Estados humanos recomendados:

- queued;
- human requested;
- human active;
- AI copilot;
- waiting customer;
- closed/won/lost según negocio.

Invariantes:

- un owner actual;
- sender humano solo si owner;
- capacidad máxima por agente;
- claim concurrente con locking;
- routing automático OFF por defecto;
- kill switch global.

## 10. Fase J — Human send

Antes de IA autónoma:

- activar canary humano;
- probar texto real a número allowlisted;
- persistir provider id;
- comprobar sent/delivered/read/failure;
- retry con misma idempotency key no reenvía;
- mensajes enviados aparecen en el mismo timeline.

Esto debe estar certificado antes de permitir AI outbound.

## 11. Fase K — AI copilot-first

Primero sugerencias, no auto-send.

El copilot debe:

- leer contexto limitado;
- consultar facts aprobados;
- citar catálogo/precios internos;
- clasificar intención;
- detectar escalamiento humano/clínico/legal;
- auditar modelo, tokens, costo, latency y safety;
- no guardar raw prompts/responses si no son necesarios.

### Router por capability

El negocio solicita capacidades como:

- fast chat;
- reasoning;
- classify;
- summarize;
- transcribe;
- vision.

No acoplar la lógica a un modelo único.

### Regla de salud/medicina

En proyectos clínicos, el bot comercial no diagnostica, no interpreta imágenes médicamente y no decide contraindicaciones personalizadas. Escala a profesional.

## 12. Fase L — Multimedia

### Audio

- recuperar media mediante Meta server-side;
- private storage con TTL/retention;
- transcripción STT;
- transcript visible;
- texto original/audio ligados al mismo message id;
- controles de costo/duración.

### Imagen/documento

- media metadata en ledger;
- storage privado;
- signed URLs de vida corta;
- thumbnails/UI;
- antivirus/type/size validation cuando aplique;
- vision solo para tareas autorizadas.

## 13. Fase M — Business tools

La IA/conversación no duplica motores existentes. Expone wrappers gobernados:

- search catalog;
- search availability;
- create appointment;
- reschedule/cancel;
- generate booking link;
- create follow-up;
- escalate to call center;
- create/update lead only through canonical contracts.

Writes:

- idempotentes;
- auditados;
- con autorización server-side;
- con preview/confirmation cuando la acción tenga impacto.

## 14. Fase N — Attribution & Revenue

Persistir provenance desde el primer evento:

- referral/CTWA;
- campaign source;
- ad id;
- lead id;
- conversation id;
- booking source;
- closer/owner;
- AI/human assistance;
- handoff count.

No atribuir revenue únicamente por coincidencia de teléfono.

Métricas finales:

- inbound conversations;
- qualified conversations;
- first response time;
- appointment rate;
- show rate;
- sale rate;
- revenue per conversation;
- AI assisted conversion;
- human assisted conversion;
- cost per conversation/appointment/sale;
- CAC/ROAS con evidencia suficiente.

## 15. Fase O — Canary → Production

Secuencia recomendada:

1. synthetic tests;
2. admin canary;
3. allowlisted real number;
4. one box / one agent;
5. limited business hours;
6. measured load;
7. wider agent group;
8. auto-routing;
9. copilot;
10. only later, bounded AI auto-reply if policy permits.

Cada step con rollback explícito.

## 16. Recovery design

Rollback no significa borrar evidencia.

Preferir:

- kill switches OFF;
- revert runtime layer;
- release assignments;
- revoke panels;
- keep ledger/conversations/events under restrictive access;
- never reopen unsigned webhook;
- never restore leaked secrets.

## 17. Observability mínima

- gateway health;
- webhook signature failures;
- message ingest rate;
- projection lag;
- bootstrap/API latency;
- 4xx/5xx by endpoint;
- queue age;
- active assignments;
- outbound delivery funnel;
- AI runs/cost/errors;
- media failures;
- booking failures;
- attribution coverage.

## 18. Architecture smell aprendido: wrapper chain

Los wrappers incrementales son excelentes para introducir seguridad sin reescribir un sistema vivo. Pero demasiadas capas/procesos anidados aumentan:

- startup complexity;
- debugging hops;
- port choreography;
- failure propagation.

Patrón recomendado:

- usar wrappers para migración segura;
- documentar la cadena exacta;
- añadir health por capa;
- una vez certificadas las funciones, consolidar gradualmente en un front controller modular **sin cambiar contratos externos**.

No consolidar durante una fase de incident recovery.

## 19. Definition of Done reusable

No declarar integración al 100% hasta probar:

1. webhook real firmado;
2. replay idempotente;
3. conversation projection;
4. authorized inbox;
5. shell integration;
6. timeline real visible;
7. human outbound + delivery receipt;
8. routing/ownership;
9. recovery path;
10. media si está en alcance;
11. booking/business action si está en alcance;
12. attribution/revenue if applicable;
13. observability/cost guardrails;
14. documented runbook and secrets rotation policy.

## 20. Regla final

**Diagnosticar desde la evidencia hacia la interfaz:** provider → gateway → DB ledger → conversation projection → auth → API → shell → frontend. Nunca al revés.
