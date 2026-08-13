# ASCENDA OS — Impact Report: OTROS → SERVICIO

Fecha: 2026-08-13
Rama: `fix/otros-service-type`
Estado: PRE-PRODUCTION / VALIDADO CON ROLLBACK
Riesgo: HIGH + CRITICAL (toca `aos_ventas` y reemplaza RPC `SECURITY DEFINER`)

## 1. Problema observado

El panel de Ventas permite editar el campo `tipo`, pero `aos_editar_venta()` no incluía `tipo` en su allowlist. El frontend enviaba el cambio y la RPC devolvía `ok=true`, pero el campo era descartado silenciosamente.

Además, la importación legacy `aos_importar_ventas()` clasifica explícitamente `OTROS` como `PRODUCTO`. Esto contradice la regla comercial vigente:

> `tratamiento = OTROS` → `tipo = SERVICIO` siempre.

## 2. Evidencia productiva previa

Baseline inmediatamente antes del hotfix:

- `OTROS + SERVICIO`: 48 filas / S/17,225.67.
- `OTROS + PRODUCTO`: 11 filas / S/3,062.40.
- Caso visible reportado por usuario: venta `id=2315`, `tratamiento=OTROS`, `tipo=PRODUCTO`.

IDs afectados al momento de la auditoría:
`2315, 2289, 2194, 2244, 2174, 2172, 2170, 2235, 2137, 2232, 2122`.

No se modifica fecha, paciente, sede, pago, monto, estado de pago, asesor ni descripción.

## 3. Impacto financiero esperado

La corrección NO cambia:

- número total de ventas;
- facturación total;
- monto de ninguna venta;
- métodos de pago;
- estados de pago.

Sí cambia la clasificación analítica de 11 registros:

- Servicios: +11 filas / +S/3,062.40 de facturación clasificada como servicio.
- Productos: -11 filas / -S/3,062.40 de facturación clasificada como producto.
- Facturación total: delta S/0.00.

Con la lógica de comisión actualmente usada por el panel:

- comisión de esas 11 filas antes: S/21.00;
- comisión correcta tratándolas como servicio: S/14.90;
- delta esperado: -S/6.10.

Ese ajuste es intencional porque corrige la naturaleza comercial de las operaciones.

## 4. Causa raíz

### A. Editor

`app/public/admin-sales.html` incluye `tipo` al construir `p_campos`.

`public.aos_editar_venta()` omitía `tipo` de `v_allowed`, por lo que el cambio no se ejecutaba aunque la respuesta fuese exitosa.

### B. Importación histórica

`public.aos_importar_ventas()` contiene una regla legacy equivalente a:

`COMPRA / PRODUCTO / OTROS => PRODUCTO`.

El hotfix no depende de que todos los productores de datos sean corregidos inmediatamente: instala un invariante central BEFORE INSERT/UPDATE sobre `aos_ventas`, de modo que `OTROS` no pueda persistir como `PRODUCTO` desde importación, Caja, RPC, frontend o escritura directa.

## 5. Cambio propuesto

Migration:
`supabase/migrations/20260813115000_fix_otros_service_type.sql`

Acciones:

1. Guardrail: aborta si aparecen más de 25 registros afectados antes del deploy.
2. Crea `fn_normalizar_tipo_venta_otros()`.
3. Crea trigger `trg_normalizar_tipo_venta_otros` BEFORE INSERT/UPDATE OF `tratamiento,tipo`.
4. Añade `tipo` al allowlist de `aos_editar_venta()` manteniendo su contrato de retorno.
5. Registra en `aos_auditoria_ediciones` las filas normalizadas por la migration.
6. Actualiza únicamente registros `OTROS` cuyo tipo no sea `SERVICIO`.
7. Postcondition obligatoria: 0 registros `OTROS` no-servicio.

## 6. Validación ya ejecutada

Se ejecutó una prueba sobre el esquema real usando:

`BEGIN -> aplicar cambios -> probar -> ROLLBACK`.

Resultados dentro de la transacción:

- `aos_editar_venta(2315, {tipo: SERVICIO})` compiló y ejecutó.
- El ID 2315 quedó temporalmente como `SERVICIO`.
- Se intentó forzar de nuevo `tipo=PRODUCTO`; el trigger lo normalizó a `SERVICIO`.
- Tras normalizar el universo, quedaron 0 `OTROS` no-servicio.
- Se ejecutó ROLLBACK.

Post-rollback verificado:

- ID 2315 volvió a `PRODUCTO`.
- el trigger de prueba no quedó instalado.
- producción no fue modificada por la prueba.

## 7. Pruebas post-deploy obligatorias

1. Checksum total ventas al 12/08/2026 debe permanecer:
   - 1,275 registros;
   - S/555,373.27.
2. `OTROS AND tipo <> SERVICIO` = 0.
3. Abrir venta ID 2315 en panel:
   - Tipo debe mostrar SERVICIO.
4. Filtro Productos:
   - ningún `OTROS` debe aparecer.
5. Filtro Servicios:
   - los registros `OTROS` deben aparecer como SERV.
6. Totales Servicio + Producto = Facturación total.
7. Comisiones:
   - delta agregado esperado sobre las 11 filas = -S/6.10 respecto a la clasificación errónea.
8. Test de persistencia del editor:
   - cambiar un tipo permitido, recargar y comprobar que persiste.
9. Test de invariante:
   - un intento controlado de escribir `OTROS + PRODUCTO` debe terminar almacenado como `SERVICIO`.

## 8. Rollback

Si aparece una regresión:

1. Desactivar/eliminar trigger `trg_normalizar_tipo_venta_otros`.
2. Restaurar la versión anterior de `aos_editar_venta()` (sin `tipo` en allowlist) solo si el problema proviene de esa RPC.
3. Para restaurar exclusivamente filas cambiadas por esta migration, usar `aos_auditoria_ediciones` con:
   - `origen='migration_fix_otros_service_20260813'`
   - `campo='tipo'`
   - restaurar `valor_anterior` por `registro_id`.
4. Revalidar checksum 1,275 / S/555,373.27.

No se requiere restaurar montos porque la migration nunca los modifica.

## 9. Dependencias / consumidores

Afectados positivamente:

- Ventas Admin.
- filtros Servicios/Productos.
- Top Servicios / Top Productos.
- Comisiones basadas en `tipo`.
- Sales Intelligence V2.
- futuras importaciones y Caja.

No se modifica el contrato JSON de `aos_ventas_admin` ni `aos_ventas_admin_anio`.

## 10. Gate

No promover a producción hasta completar revisión de branch/PR. Al ser una RPC `SECURITY DEFINER`, la política de ASCENDA exige validación y aprobación humana explícita antes del deploy productivo.
