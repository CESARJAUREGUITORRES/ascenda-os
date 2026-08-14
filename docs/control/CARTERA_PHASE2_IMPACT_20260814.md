# ASCENDA OS — FASE 2 Cartera: Impact Report

Fecha: 2026-08-14  
Rama: `agent/phase2-cartera-reconciliation`  
Estado: `PREPARADO EN RAMA — PRODUCCIÓN SIN CAMBIOS`

## Resultado de la auditoría read-only

| Evidencia | Resultado verificado |
| --- | ---: |
| Adelantos hasta 2026-08-12 | 122 registros / S/75,222.90 |
| Adelantos hasta 2026-08-13 | 123 registros / S/75,422.90 |
| Adelantos enlazados a cotización | 0 |
| Contactos representados en los 122 | 58 |
| Contactos con múltiples filas | 24 contactos / 88 filas |
| Adelantos con transacción posterior del mismo contacto | 96 |
| Transacción posterior dentro de 30 días | 86 |
| Siguiente transacción marcada PAGO COMPLETO | 81 |
| Siguiente transacción con tratamiento exacto | 47 |
| Cotizaciones | 284 |
| Cotizaciones PAGADO_PARCIAL | 39 / saldo registrado S/74,715.77 |
| Cotizaciones parciales con identidad coincidente | 37 |
| Coincidencia exacta e inequívoca por importe | 0 |
| Libro `aos_pagos` | 1 pago / S/169.00 |
| Migración FASE 2 aplicada en Supabase productivo | No; versiones `20260814034401` y `20260814050000` ausentes al 2026-08-14 |
| Adelantos con monto no finito en productivo | 0 de 123 al 2026-08-13 |

Conclusión: un `ADELANTO` representa un pago recibido, no el saldo por cobrar. El saldo real no puede derivarse de `aos_ventas.monto` porque la fila no guarda el total esperado. Las 39 cotizaciones parciales tienen saldo aritmético consistente, pero el libro de pagos está incompleto; por ello se presentan como casos por reconciliar, no como deuda confirmada.

## Separación conservadora de falsos positivos

- `ANULADO`: 12 cotizaciones y S/11,991 de saldo residual. Excluidas de cobranza.
- `CREADO`: 3 cotizaciones y S/1,305. Tratadas como pipeline, no deuda.
- `POR_PAGAR`: 1 cotización y S/1,499. Tratada como pipeline hasta confirmar obligación.
- `ADELANTO`: 122 filas al corte histórico. Se muestran como pagos pendientes de vincular; nunca como saldo.
- `PAGADO_PARCIAL`: 39 cotizaciones. Se muestran como saldo registrado pendiente de evidencia.
- `SALDO_CONFIRMADO`: comienza en cero y solo puede establecerse mediante revisión administrativa explícita con monto positivo.

## Cambio propuesto

SQL exacto: `supabase/migrations/20260814034401_cartera_phase2_reconciliation.sql`.

1. Crea `aos_cartera_reconciliacion`, con RLS, sin lectura/escritura directa para `anon` o `authenticated`.
2. Carga el bridge desde predicados de negocio, sin IDs hardcodeados y sin alterar ventas, pagos o cotizaciones.
3. Mantiene sincronizados nuevos adelantos y nuevas cotizaciones parciales mediante triggers acotados.
4. Añade gateway y reconciliación manual protegidos por sesión 2FA, rol administrador, panel `admin-cartera` y sedes permitidas del usuario.
5. Reemplaza el flujo de abono por `aos_abonar_cotizacion_v2`:
   - bloquea la cotización con `FOR UPDATE`;
   - deriva la sede, el cajero y el asesor desde fuentes verificadas;
   - exige una caja abierta del actor en esa sede y fecha Lima actual;
   - exige una clave idempotente única, ligada criptográficamente al actor, cotización, caja y payload completo;
   - liga la sesión de caja al UUID del actor y bloquea la fila durante el abono;
   - hace que los reintentos válidos no dupliquen pagos y rechaza la reutilización cruzada de la clave;
   - rechaza montos no positivos, acceso cruzado entre sedes y sobrepagos;
   - registra `ADELANTO` o `PAGO COMPLETO` según el saldo resultante;
   - enlaza `aos_pagos`, `aos_ventas`, cotización y bridge;
   - trata el componente financiero como `SERVICIO`, evitando inflar Top Productos;
   - conserva la respuesta usada por Caja y agrega IDs trazables.
6. Habilita RLS y retira acceso REST directo a cotizaciones, ítems y pagos; Caja consulta por un gateway 2FA con alcance de sede.
7. Retira `EXECUTE` anónimo del RPC legacy y actualiza Caja al RPC con token.
8. Crea el panel operativo Cartera con filtros, control de concurrencia optimista, auditoría antes/después y recordatorios bloqueados.
9. Exige que un saldo confirmado vinculado a cotización coincida exactamente con `subtotal - total_pagado = saldo_pendiente`; no admite importes parciales inventados.
10. No instala un trigger sobre `aos_ventas`: evita convertir escrituras legacy directas en casos protegidos. El corte histórico se carga una vez y los pagos v2 escriben el bridge de forma atómica.
11. Incluye una migración de limpieza que elimina sobrecargas obsoletas y restaura el emisor de sesión certificado de FASE 1. Supabase productivo fue verificado sin ninguna migración FASE 2 aplicada, por lo que el despliegue autorizado deberá ejecutar la migración principal y luego esta limpieza, en orden.
12. Rechaza `NaN` e infinitos en saldos, totales, montos del bridge y pagos v2; el seed omite importes legacy no finitos y los constraints impiden su reingreso.

## Impacto

- Tablas financieras existentes: no se corrigen ni eliminan filas históricas.
- Nuevas escrituras: únicamente en el bridge y log de seguridad durante reconciliación; en pagos reales, la función v2 mantiene la escritura atómica ya esperada por Caja.
- UI: aparece Cartera solo para administradores con el panel asignado y 2FA.
- Agentes/recordatorios: no se crean ni activan.
- Producción: requiere aplicar migración y desplegar UI en la misma ventana para no dejar Caja apuntando al RPC legacy revocado.

## Riesgos y controles

| Riesgo | Control |
| --- | --- |
| Bloquear un abono legítimo por sobrepago | Mensaje explícito con máximo permitido; no hay escritura parcial |
| Usuario de Caja sin sesión 2FA financiera | Activación canary y verificación de panel `admin-caja` antes del corte |
| Llamar deuda a un pago | Estado inicial `PENDIENTE_RECONCILIAR`; monto confirmado obligatorio |
| Duplicar casos | Índices únicos parciales por venta y cotización |
| Concurrencia en cotización | `SELECT ... FOR UPDATE` dentro de la transacción |
| Reintento o doble clic de un pago | `request_id` UUID único + advisory lock transaccional |
| Cruce de pacientes o sedes | Sede del actor aplicada dentro de cada RPC; vínculo exige identidad compatible |
| Reutilización de idempotencia por otro actor | Huella SHA-256 del request + UUID del actor + sesión de caja, validada después del control de sede/caja |
| Sesión de caja suplantada por nombre | Propietario normalizado a `abierto_por_user_id`; la fila se bloquea antes de validar y pagar |
| Sobrescritura de una revisión reciente | `expected_updated_at`; el cliente debe refrescar ante `STALE_CASE` |
| Saldo confirmado obsoleto después de un cambio | Triggers invalidan la aprobación y devuelven el caso a `REVISAR` |
| Exposición del bridge | RLS + revocación de tabla + gateway con token opaco |
| Automatización prematura | No existe ruta de envío; bandera visible de recordatorios bloqueados |

## Pruebas y gate

- Esquema sintético sin datos reales.
- pgTAP: 96 aserciones para RLS, permisos, sesión, sedes —incluidos casos adversariales con `NULL` y valores no finitos—, sobrecargas legacy, clasificación, reconciliación, idempotencia ligada al actor, sobrepago, atomicidad y roles de pago.
- Lint de Supabase en nivel error.
- Contrato UI para menú, autorización, gateway, Caja v2 y bloqueo de recordatorios.
- Smoke requerido antes de producción: San Isidro, Pueblo Libre, administrador con panel, administrador sin panel, sobrepago rechazado y saldo exacto.

## Rollback

Rollback de aplicación: desplegar el commit anterior a FASE 2.

Rollback SQL de emergencia: `supabase/rollbacks/20260814034401_cartera_phase2_reconciliation.rollback.sql`, conservando primero snapshots de `aos_cartera_reconciliacion` y de las definiciones/ACL financieras. El rollback es **roll-forward seguro**: no restaura ejecución anónima ni acceso REST directo a tablas financieras.

```sql
begin;
drop trigger if exists trg_aos_cartera_sync_venta on public.aos_ventas;
drop trigger if exists trg_aos_cartera_sync_cotizacion on public.aos_cotizaciones;
revoke all on function public.aos_cartera_gateway(text,text,text,integer,integer) from public,anon,authenticated;
revoke all on function public.aos_cartera_reconcile(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text) from public,anon,authenticated;
revoke all on function public.aos_caja_cotizaciones_gateway(text,text,text,text) from public,anon,authenticated;
revoke all on function public.aos_abonar_cotizacion_v2(text,uuid,text,numeric,text,text,text,text,text) from public,anon,authenticated;
drop function if exists public.aos_cartera_gateway(text,text,text,integer,integer);
drop function if exists public.aos_cartera_reconcile(text,uuid,timestamptz,text,text,numeric,numeric,text,text,text);
drop function if exists public.aos_caja_cotizaciones_gateway(text,text,text,text);
drop function if exists public.aos_abonar_cotizacion_v2(text,uuid,text,numeric,text,text,text,text,text);
drop function if exists public.aos_cartera_actor(text,text);
drop function if exists public.aos_cartera_sync_venta();
drop function if exists public.aos_cartera_sync_cotizacion();
delete from public.aos_paneles_disponibles where id='admin-cartera';
alter table public.aos_cartera_reconciliacion rename to aos_cartera_reconciliacion_rollback_20260814;
commit;
```

El RPC legacy permanece restringido a `service_role`. Si la UI necesita retroceder, debe hacerse mediante un adaptador autenticado o un roll-forward; nunca mediante un `GRANT` a `anon`.

### Deuda técnica de seguridad preexistente

- El emisor de sesión administrativa de FASE 1 continúa dependiendo del contrato 2FA ya certificado, pero su verificación de contraseña y limitación de intentos necesitan un hardening separado antes de una activación general de Cartera.
- `aos_caja_abrir()` y `aos_caja_cerrar()` son funciones legacy de Caja y requieren su propio endurecimiento de identidad, sesión y privilegios.
- `aos_ventas` conserva acceso legacy directo para módulos existentes. FASE 2 evita ampliar ese riesgo al no instalar un trigger de sincronización; su migración integral a gateways/RLS queda como gate de seguridad independiente.
- Estas dependencias no son introducidas por este diff, pero mantienen la activación productiva general **BLOQUEADA**. El PR puede probarse como canary administrativo controlado; no habilita recordatorios ni agentes.

## Gate productivo

No aplicar hasta que:

1. el PR esté verde;
2. el diff de seguridad no tenga hallazgos críticos;
3. se verifiquen los administradores que recibirán `admin-cartera` y `admin-caja`;
4. se tome snapshot del bridge y definiciones de funciones;
5. exista autorización expresa para migración productiva y despliegue coordinado.
6. se endurezca el emisor de sesión 2FA y la apertura/cierre de Caja, o se apruebe explícitamente un canary limitado con riesgo residual documentado.
