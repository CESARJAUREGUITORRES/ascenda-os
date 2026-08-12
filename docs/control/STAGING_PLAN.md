# ASCENDA OS — STAGING PLAN

**Fecha:** 2026-08-12  
**Objetivo:** crear un entorno de preproducción seguro antes de introducir cambios funcionales de alto impacto.

## 1. Componentes

### GitHub

- `main` = producción.
- `staging` = integración/preproducción.
- `feature/*`, `fix/*`, `security/*`, `data/*`, `chore/*` = trabajo aislado.

### Supabase

Objetivo: crear una branch/proyecto de desarrollo separado de producción.

Reglas:

- no usar datos clínicos reales completos salvo dataset explícitamente autorizado/sanitizado;
- schema y migrations deben reflejar producción;
- las pruebas de RLS/Auth/Storage se realizan primero aquí;
- cualquier migration HIGH/CRITICAL debe pasar por staging antes de producción.

### Railway

Objetivo: crear un servicio/environment de staging conectado a la rama GitHub `staging` y apuntando únicamente al Supabase de staging.

Variables requeridas deben existir como secretos del environment, nunca en Git.

## 2. Flujo

```text
feature/fix/security/*
        ↓
       PR
        ↓
      staging
        ↓
  GitHub Actions
        ↓
Supabase staging
        ↓
Railway staging
        ↓
 validación humana
        ↓
      main
        ↓
   producción
```

## 3. Criterios antes de conectar Railway staging

- [ ] Supabase staging creado.
- [ ] URL/key de staging configuradas solo como variables del environment.
- [ ] secrets productivos no reutilizados cuando no sea necesario.
- [ ] endpoint/login básico responde.
- [ ] CI verde.
- [ ] smoke tests definidos.
- [ ] no hay datos clínicos reales expuestos en un entorno menos protegido.

## 4. Datos de prueba

Crear un dataset sintético mínimo que cubra:

- usuario ADMIN;
- usuario ASESOR;
- paciente ficticio;
- lead ficticio;
- llamada/seguimiento;
- cita;
- atención;
- cotización/pago;
- venta;
- comisión;
- inventario.

Nunca utilizar el dataset de staging como fuente de verdad comercial.

## 5. Definition of Ready para un cambio

Un cambio puede pasar a staging cuando:

- Impact Report completo si es HIGH/CRITICAL;
- código en branch;
- CI verde;
- migration incluida si aplica;
- rollback descrito;
- no contiene secretos;
- pruebas propuestas.

## 6. Definition of Ready para producción

- validación en staging completada;
- datos reconciliados;
- comportamiento por roles probado;
- mobile/desktop probado si es UI;
- logs sin errores nuevos;
- rollback ejecutable;
- aprobación humana.
