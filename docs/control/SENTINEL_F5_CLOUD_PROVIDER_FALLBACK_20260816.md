# Sentinel F5 — Cloud Availability Provider Fallback

**Fecha:** 2026-08-16  
**Fase:** F5 — Availability Layer  
**Estado:** cloud provider fallback in progress

## Hallazgo

El formulario de Sentry Uptime rechazó la creación del monitor para:

`https://ascenda-os-production.up.railway.app/health`

con el mensaje visible de que el dominio compartido `*.railway.app` ya había sido usado en **1000 uptime monitoring alerts**, alcanzando el límite y bloqueando nuevos monitores para ese dominio.

Railway Network Logs demostraron que `/health` seguía respondiendo HTTP 200 de forma estable y CREACTIVE seguía observándolo correctamente. No se evidenció una falla de ASCENDA, Railway, DNS del servicio ni del endpoint `/health`.

## Decisión

Sentry permanece como sensor de errores F4. No se fuerza Sentry Uptime, no se compra dominio, no se crea un VPS y no se modifica Railway únicamente para evadir un límite externo de un dominio compartido.

La capa de disponibilidad cloud continua de F5 cambia a **UptimeRobot Free**:

- target: `GET https://ascenda-os-production.up.railway.app/health`
- sin headers
- sin autenticación
- sin body
- sin PHI/PII
- intervalo cloud baseline: 300 segundos
- costo incremental objetivo: USD 0/mes
- Sentinel Core no dependerá de la API de UptimeRobot

CREACTIVE mantiene la capa local profunda:

- Uptime Kuma local
- Sentinel Local Observer
- intervalo local: 60 segundos
- validación semántica de `ok`, `service`, `child_alive`, `inner_ready`
- `UNKNOWN` durante coverage gaps
- reconciliación al regresar

## Arquitectura resultante

```text
ASCENDA / Railway
      |
      +--> Sentry Error Monitoring       (F4, cloud)
      +--> UptimeRobot HTTP availability (F5, cloud, 5 min)
      +--> CREACTIVE / Kuma + Observer   (F5, local, 1 min while available)
                    |
                    +--> coverage-gap reconciliation
```

## Regla de costo

No se autoriza gasto automático. No se requiere custom domain, hosting adicional ni plan pago para cerrar la baseline híbrida de F5.

## Gates pendientes

1. Configurar `ASCENDA Production Health` en UptimeRobot Free.
2. Verificar primer check cloud exitoso contra `/health`.
3. Ejecutar/registrar outage-recovery sintético sin afectar producción.
4. Certificar F5 y avanzar F6.
