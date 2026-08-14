# ASCENDA OS — Sales Intelligence V2 / Phase 1 Production Preflight

Fecha: 2026-08-14
Rama: `feat/sales-intelligence-v2-phase1-canary`
PR: #66
Estado: **STAGING GATE APROBADO — PRODUCCIÓN PENDIENTE DE APROBACIÓN HUMANA**

## 1. Evidencia de staging vivo

- `/health`: HTTP 200 con `{"status":"ok","mode":"staging-fixture"}`.
- `/`: HTTP 200, header `X-ASCENDA-ENV: staging-fixture`.
- Escrituras HTTP: POST rechazado con 405.
- La raíz y el panel servidos coinciden exactamente con los blobs Git de la rama canary:
  - `admin-sales-intelligence-staging.html`: `9ce7dbff6690dcfe70c8f424a5a5141b8d857b9f`.
  - `admin-sales-intelligence.html`: `7a3bb3e2441af0f78d15ae4e0a0949522e8d5a9b`.
- UI desktop: KPIs, comparativa anual, proyección, MTD y tabla mensual visibles sin error de RPC.
- Consola de la página: sin errores propios del panel.

## 2. CI certificado

- Ascenda CI: SUCCESS.
- Sales Intelligence Phase 1: SUCCESS.
- Zero-Cost Staging: SUCCESS.
- pgTAP: 40 pruebas previstas tras hardening ACL.
- Presupuesto de performance certificado previo: ejecución 8.015 ms; 1,132 buffers; límites 250 ms / 1,500.

## 3. Snapshot financiero preflight

Corte inmutable: 2026-01-01 a 2026-08-12.

- Ventas: 1,275.
- Facturado: S/555,373.27.
- Servicios: 882 / S/498,040.17.
- Productos: 393 / S/57,333.10.
- OTROS clasificado incorrectamente como producto: 0.
- Checksum determinístico: `9c508ba0e8ec4b9866115c26c1ac32f3`.

## 4. Estado productivo observado

- `public.aos_sales_intelligence_summary(integer,text,text)`: no existe todavía.
- Migraciones `20260813173000` y `20260813174500`: no aplicadas.
- No se modificaron filas ni objetos productivos durante este preflight.

## 5. Impact Report

Cambio propuesto: crear o reemplazar una sola función SQL `STABLE SECURITY INVOKER` que realiza exclusivamente lecturas agregadas sobre `aos_ventas` y `aos_metas_ventas`.

No incluye:
- UPDATE, INSERT, DELETE o TRUNCATE;
- modificación de ventas históricas;
- nuevas tablas o índices;
- cambios a RLS;
- activación inmediata del módulo para todos los usuarios.

ACL final:
- revocar EXECUTE de `PUBLIC`;
- conceder EXECUTE explícitamente a `anon`, `authenticated` y `service_role`.

Nota de seguridad: ASCENDA actualmente usa la clave anon incluso después de su login personalizado y `aos_ventas` conserva políticas legacy permisivas. Por ello el canary superadmin es un control funcional de interfaz, no una frontera criptográfica nueva. Cerrar ese riesgo requiere una migración de autenticación/RLS separada y no debe mezclarse con esta liberación analítica.

## 6. Verificación posterior obligatoria

1. Repetir snapshot y checksum; debe permanecer `9c508ba0e8ec4b9866115c26c1ac32f3`.
2. Confirmar función `STABLE`, `SECURITY INVOKER` y ACL.
3. Ejecutar el RPC para 2026 y cotejar el contrato certificado.
4. Ejecutar EXPLAIN ANALYZE + BUFFERS.
5. Confirmar que no existe escritura ni cambio financiero.
6. Publicar shadow page.
7. Habilitar canary únicamente para nivel jerárquico 1.
8. Activar el módulo general solo después de aceptación humana.

## 7. Rollback

```sql
DROP FUNCTION IF EXISTS public.aos_sales_intelligence_summary(integer,text,text);
```

El rollback elimina únicamente el RPC nuevo. No toca ventas, metas, pacientes, cotizaciones ni pagos.

## 8. Gate

No aplicar el SQL, fusionar a `main`, desplegar producción ni activar el módulo sin aprobación expresa del usuario.
