# ASCENDA Conversations — WA-1 Secure WhatsApp Gateway — Impact Report

**Estado:** IMPLEMENTED / PRE-CERTIFICATION  
**Riesgo:** CRITICAL  
**Baseline inicial:** `f05982e7a6af6a85d158693dffa6a693b27df54f`  
**Branch:** `security/wa1-secure-whatsapp-gateway`

## Objetivo
Cerrar la frontera WhatsApp/Meta antes de construir inbox, routing o IA: autenticar webhooks, hacer idempotente el ingreso, crear almacenamiento privado normalizado, habilitar outbound gobernado y conservar un canary fail-closed.

## Vulnerable path revalidado
El backend legado aceptaba `POST /webhook`, respondía `200`, parseaba y persistía el payload sin validar `X-Hub-Signature-256`. El verify token del flujo histórico también quedó expuesto en código y por tanto debe considerarse comprometido/retirado.

## Security invariants
1. Ningún POST WhatsApp se procesa sin HMAC SHA-256 válido sobre los bytes exactos.
2. `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_APP_SECRET`, `WHATSAPP_ACCESS_TOKEN` y `SUPABASE_SERVICE_ROLE_KEY` existen solo como secretos de runtime.
3. Si falta configuración de seguridad, el gateway falla cerrado; no proxifica al webhook legado.
4. Payload máximo inbound: 1 MiB.
5. La base canónica WA no es accesible por `anon` ni `authenticated`.
6. `provider_message_id`, `event_key` e `idempotency_key` evitan duplicidad/replay operativo.
7. Outbound requiere sesión administrativa 2FA válida y panel `admin-chats`.
8. Canary outbound bloquea números fuera de `WA_CANARY_ALLOW_TO` mientras `WA_CANARY_MODE=true`.
9. El gateway no almacena raw webhook completo; solo hechos normalizados y metadata sanitizada.
10. Recovery nunca reabre escritura legacy ni el POST unsigned.

## Código
- `app/server-f4.js`: enforcement boundary productivo; intercepta `/webhook` y `/api/wa/*` antes del backend.
- `app/wa-gateway.js`: HMAC, normalización, parsing y validación outbound.
- `ci/wa1-secure-gateway/*`: regresiones y contratos DB.
- `.github/workflows/wa1-secure-whatsapp-gateway.yml`: certificación Zero-Cost.

## Datos
### Nuevas tablas aditivas
- `aos_wa_messages_v1`: mensaje normalizado, estado delivery/read/failure, attribution mínima y ledger económico.
- `aos_wa_events_v1`: eventos idempotentes/sanitizados.

Ambas usan RLS + FORCE RLS y no tienen acceso `anon/authenticated`; writes del gateway requieren `service_role` server-side.

### Legacy
`aos_whatsapp_mensajes` se conserva para compatibilidad/historia, pero sus writes directos `anon/authenticated` quedan revocados. No se toca `aos_webhook_log`, porque es compartida por integraciones no inventariadas completamente y WA-1 ya no la usa como store raw.

## Contratos externos
### Inbound
- `GET /webhook`: challenge Meta; token solo desde `WHATSAPP_VERIFY_TOKEN`.
- `POST /webhook`: `X-Hub-Signature-256` obligatorio; 401 ante firma inválida; 413 >1 MiB; 503 si security config falta.

### Outbound
- `POST /api/wa/send`
- Header: `X-AOS-App-Token` de sesión administrativa 2FA.
- Payload soportado WA-1: `text`, `template`, `image`, `document`, `audio` mediante link HTTPS.
- `idempotency_key` obligatorio.
- Canary allowlist obligatorio por defecto.

### Status
- `GET /api/wa/status`: admin+2FA; expone solo booleanos de configuración y estado canary, nunca secretos.

## Variables runtime requeridas
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `WHATSAPP_VERIFY_TOKEN` — **nuevo valor rotado**, no reutilizar el valor histórico del repo.
- `WHATSAPP_APP_SECRET`
- `WHATSAPP_ACCESS_TOKEN`
- `WHATSAPP_PHONE_NUMBER_ID`
- `WHATSAPP_GRAPH_VERSION`
- `WA_CANARY_MODE=true`
- `WA_CANARY_ALLOW_TO=<números de canary autorizados>`

No registrar los valores en GitHub, Notion, logs, prompts ni documentación.

## Pruebas
### Runtime
- `node --check app/wa-gateway.js`
- `node --check app/server-f4.js`
- `node --test ci/wa1-secure-gateway/wa-gateway.test.js`
- firma válida/forjada/malformed;
- bytes exactos;
- CTWA/referral;
- status/pricing;
- payload outbound permitido/prohibido;
- idempotency key;
- canary allowlist.

### Database
- migración exacta en Supabase local efímero;
- lint;
- pgTAP RLS/GRANT positivo y negativo;
- recovery fail-closed;
- zero-residue al finalizar.

## Production read-only preflight
Antes del primer release productivo:
1. confirmar `main` exacto y ausencia de drift en `server-f4.js`/Railway start command;
2. confirmar tabla legacy sin tráfico productivo no explicado durante la ventana;
3. confirmar names/configuración Meta sin leer ni imprimir secretos;
4. confirmar que las variables requeridas existen en Railway mediante un mecanismo autorizado;
5. confirmar WABA subscription/callback target.

## Canary
1. `WA_CANARY_MODE=true`.
2. allowlist mínima del propietario/admin de prueba.
3. inbound: evento real firmado llega una sola vez y queda persistido en `aos_wa_messages_v1`/`aos_wa_events_v1`.
4. replay del mismo payload no duplica mensajes/eventos.
5. firma alterada obtiene 401 y genera cero rows.
6. outbound texto al número allowlisted produce `provider_message_id` y retry con mismo `idempotency_key` no reenvía.
7. recibir al menos un status `sent/delivered/read` y actualizar la misma fila.
8. número fuera de allowlist obtiene 403 sin llamada a Meta.

## Rollback / recovery
- Nunca volver al POST unsigned.
- Mantener inbound firmado.
- Para incidente outbound: conservar `WA_CANARY_MODE=true` y retirar/deshabilitar `WHATSAPP_ACCESS_TOKEN`; resultado esperado: 503 fail-closed sin envíos.
- La migration es aditiva y recovery conserva las tablas/evidencia; no borra chats.
- La tabla legacy conserva lecturas, pero no recupera writes anónimos.

## Gate de certificación
WA-1 solo puede declararse `100_COMPLETE / PRODUCTION CERTIFIED` cuando:
- Zero-Cost exact-SHA está verde;
- no quedan findings HIGH/CRITICAL WA-1 abiertos;
- production preflight read-only está verde;
- secretos activos han sido rotados/configurados fuera del repo;
- canary real firmado + outbound allowlisted + delivery status están probados;
- post-deploy smoke y reconciliación no muestran regresiones.
