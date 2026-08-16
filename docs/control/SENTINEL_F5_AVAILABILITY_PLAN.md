# Sentinel F5 — Availability Layer / Uptime Kuma

**Fecha:** 2026-08-16 (America/Lima)  
**Estado inicial:** `FOUNDATION_IN_PROGRESS`  
**Dependencia:** F4 `100_COMPLETE / 18/18 PASS`  
**Costo cloud incremental autorizado en foundation:** `US$0`

## 1. Objetivo

Añadir un observador externo capaz de detectar que ASCENDA no responde aunque el runtime interno no pueda reportar su propio fallo. F5 no reemplaza Sentry y no introduce todavía Business Health, Telegram ni Incident Engine.

## 2. Decisión de observador

Se adopta Uptime Kuma como engine self-hosted de disponibilidad.

Verificación técnica al 2026-08-16:

- rama mayor oficial: `2`;
- release estable observada al diseñar F5: `2.3.2`;
- compose oficial usa `louislam/uptime-kuma:2`;
- almacenamiento `/app/data` requiere volumen/local filesystem compatible con file locking; NFS no se admite para esta baseline.

El artefacto ASCENDA mantiene `:2` como major soportado oficialmente. Actualizaciones de major/minor no se consideran automáticas ni forman parte de F5.

## 3. Principio de independencia

El observer 24/7 debe cumplir:

1. no ejecutarse dentro del proceso ASCENDA;
2. no ejecutarse en el mismo Railway service;
3. idealmente no depender de Railway como proveedor de cómputo;
4. si el observer queda sin heartbeat, Sentinel debe mostrar `UNKNOWN`, nunca `HEALTHY`;
5. la caída del observer no puede bloquear ASCENDA.

## 4. Probe baseline autorizado

### `ascenda-production-health`

```text
GET https://ascenda-os-production.up.railway.app/health
```

Esperado:

```json
{
  "ok": true,
  "service": "ascenda-phase-s",
  "child_alive": true,
  "inner_ready": true
}
```

Política:

- interval: 60 s;
- timeout: 10 s;
- 3 muestras fallidas acumuladas consecutivamente para `DOWN`;
- 1–2 fallos consecutivos ⇒ `DEGRADED`;
- 2 éxitos consecutivos para recuperar `UP`;
- observador stale/no evidence ⇒ `UNKNOWN`.

No se fija todavía SLA por latencia; primero se recogerá baseline real antes de convertir latencia en severidad.

## 5. Endpoints expresamente excluidos de Kuma en F5

- `/api/phase-s/status` por requerir sesión/token;
- endpoints clínicos;
- endpoints de WhatsApp/email con contenido;
- Supabase REST/RPC que requieran `apikey`, bearer o service role;
- bodies de login/2FA;
- cualquier probe que necesite identidad de paciente/persona.

Dependency health profundo corresponde a F6/F7 mediante probes sanitizados, no credenciales pegadas en Uptime Kuma.

## 6. Privacidad

Kuma recibe únicamente información de disponibilidad técnica. Prohibido almacenar:

- PHI/PII;
- nombres, teléfonos, DNI, emails de pacientes;
- mensajes WhatsApp/email;
- cookies/tokens;
- `service_role`;
- request bodies;
- credenciales de proveedores.

La UI de Kuma se liga inicialmente a localhost `127.0.0.1:3001`. Cualquier exposición remota futura debe tener autenticación, 2FA/reverse proxy seguro y gate específico.

## 7. Noise / anti-flapping

F5 produce señal de disponibilidad, no alerta final.

- Kuma notifications: OFF en baseline;
- Telegram: reservado a F9;
- fingerprint baseline: `availability:production:ascenda-production-health`;
- maintenance windows deben poder suprimir transición a incidente;
- repetición del mismo outage mantiene un solo fingerprint/caso lógico;
- recovery requiere estabilidad de dos muestras.

## 8. Estados

| Kuma/F5 | Sentinel |
|---|---|
| UP | HEALTHY |
| partial failures | DEGRADED |
| DOWN | INCIDENT |
| observer stale / insufficient evidence | UNKNOWN |

F5 todavía no asigna `CRITICAL`; esa severidad requiere contexto de impacto/Incident Engine.

## 9. Deployment artifact

Archivo: `sentinel/availability/compose.yaml`

Propiedades:

- `louislam/uptime-kuma:2`;
- restart `unless-stopped`;
- UI localhost-only;
- volumen persistente local;
- `no-new-privileges`;
- sin secretos en código;
- sin Docker socket montado.

CI puede levantarlo temporalmente y destruir contenedor + volumen. Eso certifica el artefacto sin convertir CI en monitor 24/7.

## 10. Host decision — F5-HOST-01

F5 no desplegará automáticamente infraestructura pagada. El host productivo debe elegirse entre una opción realmente independiente y disponible 24/7.

Criterios obligatorios:

- encendido 24/7;
- salida HTTPS hacia Railway;
- storage local persistente;
- Docker/Compose;
- backup de `/app/data`;
- administración restringida;
- no introducir costo no autorizado;
- no usar el mismo Railway service observado.

Posibles categorías:

1. host Linux propio siempre encendido;
2. nodo FORGE futuro 24/7;
3. VPS pequeño aprobado expresamente;
4. otro host independiente documentado.

Un runner CI que se apaga al terminar el trabajo no cuenta como observer 24/7.

## 11. Gates F5

| Gate | Evidencia | Estado inicial |
|---|---|---|
| F5-G01 | F4 `100_COMPLETE / 18/18` | PASS |
| F5-G02 | contrato `sentinel-availability/v1` | EN CI |
| F5-G03 | Zero-PHI/PII + sin credenciales | EN CI |
| F5-G04 | `/health` probe seguro versionado | EN CI |
| F5-G05 | state mapping + UNKNOWN explícito | EN CI |
| F5-G06 | anti-flapping + fingerprint | EN CI |
| F5-G07 | Docker Compose localhost-only | EN CI |
| F5-G08 | disposable Kuma container smoke | EN CI |
| F5-G09 | host 24/7 independiente seleccionado/aprobado | PENDING HUMAN BOUNDARY |
| F5-G10 | deployment persistente + observer heartbeat | PENDING |
| F5-G11 | outage sintético + recovery + dedup | PENDING |
| F5-G12 | checkpoint final + Notion F5=100 + F6 siguiente | PENDING |

## 12. Definition of Done

F5 cierra solo cuando:

- el observer independiente funciona 24/7;
- `/health` puede declararse DOWN sin depender de Sentry;
- observer failure produce UNKNOWN;
- outage/recovery sintéticos respetan anti-flapping;
- no existen PHI/PII/secrets en configuración/evidencia;
- costo incremental está dentro de lo autorizado;
- GitHub y Notion coinciden;
- F6 queda como única fase siguiente.
