# ASCENDA OS — Phase 2 `aos_secure_write_v2` JSONB P0 Impact Report

**Fecha:** 2026-08-14  
**Riesgo:** HIGH — gateway de escritura protegido / compatibilidad operativa  
**Estado:** PREPRODUCTION ONLY

## Objetivo
Corregir un fallo de runtime detectado por Zero-Cost CI: `aos_secure_write_v2` usa `jsonb_object_length(jsonb)`, función inexistente en PostgreSQL, al validar `p_match` para `PATCH`/`DELETE`.

## Código / datos
- migration nueva: `supabase/migrations/20260814201500_fix_secure_write_v2_jsonb_match_count.sql`
- función: `public.aos_secure_write_v2(text,text,text,jsonb,jsonb)`
- no cambia tablas, datos productivos, allowlists, roles ni contrato de retorno.

## Consumidores
El gateway protege escrituras allowlisted sobre catálogo y planes de trabajo. La corrección mantiene exactamente el mismo comportamiento esperado: `PATCH`/`DELETE` sin match devuelven `MATCH_REQUIRED`; los matches no vacíos continúan por el flujo existente.

## Seguridad
- conserva `SECURITY DEFINER` + `search_path=''`;
- conserva autoridad derivada de `aos_app_actor_v3`;
- conserva allowlists de tablas/campos/match;
- no amplía grants;
- no usa PII/PHI ni secretos en CI.

## Plan de prueba
1. construir fixture sintético Phase 2/Auth V3;
2. aplicar cadena exacta hasta `20260814195300_fix_auth_v3_btrim.sql`;
3. demostrar que el hotfix elimina la referencia inválida;
4. sesión sintética autorizada: `DELETE` con `p_match={}` debe devolver `MATCH_REQUIRED`, no `WRITE_REJECTED`;
5. tabla fuera de allowlist debe seguir devolviendo `TABLE_NOT_ALLOWED`;
6. `supabase db lint --level error` sin el finding de `aos_secure_write_v2`;
7. ejecutar contratos Phase 2 relevantes.

## Rollback / recovery
La migration solo redefine la función. Recovery: restaurar la definición inmediatamente anterior si apareciera regresión, pero **no** restaurar `jsonb_object_length`; en emergencia se puede degradar temporalmente el gateway antes que reintroducir una función inválida.

## Gate productivo
No aplicar directamente en producción. Branch → Zero-Cost V2 → PR → integración → preflight read-only → autorización conforme a gobernanza HIGH.