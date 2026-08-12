# ASCENDA OS — Marketing Safe Release Loop

## Objetivo

Aplicar mejoras de Marketing sin volver a introducir regresiones visibles, inconsistencias de atribución ni pérdida de trazabilidad.

## Principio operativo

El panel legacy se mantiene visible como fallback. Una mejora V2 solo reemplaza un bloque después de que su RPC responda correctamente con el mismo rol usado por el navegador y sus resultados pasen reconciliación de datos.

## Loop obligatorio por bloque

1. **Baseline** — congelar cifras actuales y casos patrón del bloque.
2. **Fuente de verdad** — identificar tablas/RPC/eventos exactos que alimentan la métrica.
3. **Causalidad** — impedir que llamadas, citas o ventas anteriores al touchpoint se atribuyan al lead nuevo.
4. **Unidad de medida** — declarar si la cifra representa ingresos/touchpoints, personas únicas, clientes o operaciones.
5. **Preview paralelo** — construir cálculo V2 sin retirar el renderer legacy.
6. **QA SQL propietario** — validar resultados y anomalías contra casos conocidos.
7. **QA runtime real** — ejecutar la RPC con `SET ROLE anon`/rol usado por frontend y confirmar permisos de toda la cadena.
8. **Gateway mínimo** — exponer solo la RPC agregada necesaria; no abrir funciones internas ni PII innecesariamente.
9. **Frontend progressive enhancement** — legacy renderiza primero; V2 sustituye únicamente el bloque validado; cualquier error conserva legacy.
10. **Feature/fix branch** — nunca editar `main` para desarrollo normal.
11. **Syntax/CI** — `node --check`, `git diff --check`, Ascenda CI y checks existentes.
12. **PR → staging** — revisar diff exacto y confirmar ausencia de cambios ajenos.
13. **Staging CI** — no promover si el head de staging no está verde.
14. **PR → main** — promoción pequeña y reversible del bloque aprobado.
15. **Main CI** — verificar el run post-merge de `push: main`.
16. **QA visual real** — captura desde ASCENDA productivo con filtros relevantes.
17. **Reconciliación** — comparar UI ↔ RPC ↔ tablas para cifras clave.
18. **Observación** — revisar primera actividad real posterior al cambio cuando aplique.
19. **Documentación** — registrar decisiones, casos ambiguos y deuda pendiente.
20. **Rollback** — ante regresión visible, desactivar solo el enhancement y conservar datos/trazabilidad.

## Gates obligatorios

Un bloque no avanza al siguiente si falla cualquiera de estos gates:

- **G1 Datos:** cifras reconciliadas con casos patrón.
- **G2 Causalidad:** cero atribuciones anteriores al lead.
- **G3 Runtime:** RPC ejecuta bajo el rol real del navegador.
- **G4 Seguridad:** no se amplían permisos más allá de lo necesario.
- **G5 Código:** diff acotado + sintaxis/CI verde.
- **G6 Staging:** staging verde.
- **G7 Producción:** main verde.
- **G8 Visual:** captura productiva correcta.

## Regla de despliegue por lotes

Orden actual:

1. Leads del período — aprobado visualmente.
2. Histórico anual — siguiente bloque.
3. LTV/cohortes.
4. Top Anuncios.
5. Campañas.
6. Paginación/búsqueda avanzada.
7. Intención → compra.
8. Nuevos bloques de atribución/reactivación.
9. Marketing Intelligence.

No agrupar varios bloques de alto impacto en un mismo cutover.
