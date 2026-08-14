# ASCENDA OS — Canary 2FA context hotfix

Fecha: 2026-08-14
Rama: `fix/sales-intelligence-canary-2fa-context`
Estado: PREPRODUCCIÓN — ACTIVACIÓN GENERAL BLOQUEADA

## Objetivo

Corregir la pérdida de `nivel`, `paneles_acceso`, `area` y demás contexto después de un 2FA válido. El síntoma observado era un usuario reconocido como ADMINISTRADOR pero degradado localmente a nivel 4, ocultando Sales Intelligence V2.

## Impact Report

Riesgo: CRITICAL (Auth/sesión/2FA, SECURITY DEFINER y deploy).

### Código

- `app/public/app.html`: versión de caché `20260814.1` y revalidación read-only del contexto ADMIN.
- `supabase/migrations/20260814020434_fix_2fa_context_canary.sql`: contrato 2FA completo.
- CI: esquema sintético y pgTAP sin usuarios reales.

### Datos y efectos

La función conserva los efectos existentes:
- consume un código 2FA válido una sola vez;
- registra éxito o fallo en `aos_security_log`.

No modifica ventas, pacientes, caja, comisiones, metas, RLS ni activación general.

### Seguridad

- `SECURITY DEFINER` conserva el mismo propósito.
- `search_path` queda vacío y todas las relaciones se califican con `public.`.
- EXECUTE se revoca de PUBLIC y se conserva explícitamente para `anon`, `authenticated` y `service_role`, necesarios en el runtime legacy actual.
- La navegación nivel 1 sigue siendo un gate funcional; la migración completa a identidad/JWT/RLS continúa fuera de este hotfix.

## Snapshot previo

- Ventas: 1,279.
- Facturado: S/556,097.27.
- Checksum: `a402c606d3b38d1354c32ad44afb951a`.
- Hash de definición 2FA previa: `57e2e9837bc69df01d8289c3ea303935`.

## Pruebas

1. Compilación de la migración en Supabase efímero.
2. 2FA válido devuelve nivel 1, paneles, área, cargo y sedes.
3. El código válido se consume una vez.
4. Código consumido e inválido se rechazan.
5. Login exitoso se audita.
6. PUBLIC no puede ejecutar; el caller legacy anon conserva EXECUTE.
7. El shell fuerza caché nueva y revalida la sesión ADMIN.
8. CI y smoke de Sales Intelligence permanecen verdes.

## Rollback

1. Revertir exclusivamente el merge del hotfix para restaurar el shell anterior.
2. Aplicar una migración compensatoria que restaure `aos_verificar_2fa(text,text)` desde la definición previa identificada por hash `57e2e9837bc69df01d8289c3ea303935`.
3. Repetir checksum financiero y smoke de login.

No se activa el módulo para niveles 2–5.
