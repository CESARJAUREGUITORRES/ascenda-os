# ASCENDA OS — PERFORMANCE GUARD / INCIDENT 2026-08-12

**Estado:** ACTIVE REMEDIATION  
**Rama:** `fix/performance-guard`  
**Producción:** Railway temporalmente OFF durante diagnóstico  
**Supabase:** `ituyqwstonmhnfshnaqz`  
**Riesgo:** HIGH/CRITICAL por disponibilidad, sin cambios destructivos

## 1. Invariantes

La corrección NO puede alterar lógica funcional de ventas, agenda, marketing, llamadas, pacientes, agentes o Studio. El objetivo es reducir trabajo redundante, impedir solapamiento y degradar con elegancia cuando Supabase está bajo presión.

Baseline de datos protegida durante el incidente:

- Enero 2026: 191 ventas.
- Enero 2026: S/ 91,029.60.
- No ejecutar correcciones de enero mientras el runtime no esté estable.

## 2. Evidencia del incidente

Antes del aislamiento se observaron:

- HTTP 521/522/525/503/504 en PostgREST/health.
- `statement timeout` repetidos en PostgreSQL.
- conexiones terminadas por `idle-in-transaction timeout`.
- API success rate degradada en Dashboard Supabase.

Se reinició el proyecto Supabase y PostgreSQL volvió a responder. Railway volvió a ejecutar procesos automáticos y reaparecieron fallos 521. Al retirar el deployment Railway:

- Postgres quedó con ~1 consulta activa de diagnóstico;
- 0 `idle in transaction`;
- 0 consultas >5 s;
- las llamadas periódicas de agentes/Studio dejaron de aparecer en logs.

Esto confirma que el runtime ASCENDA es un amplificador relevante de carga. No implica que un solo worker sea la única causa.

## 3. Perfil real de carga

`pg_stat_statements` muestra acumulación histórica aproximada:

| Objeto | Llamadas | Mean ms | Total ms aprox. |
|---|---:|---:|---:|
| `aos_panel_admin` | 163,414 | 241.7 | 39,494,099 |
| `aos_ticker_mkt` | 152,249 | 149.6 | 22,777,384 |
| `aos_actividad_minutos` | 286,013 | 63.4 | 18,145,307 |
| `aos_generar_snapshot` | 29,695 | 422.9 | 12,557,359 |
| `aos_panel_asesor` | 51,369 | 156.4 | 8,035,804 |
| `aos_actividad_reciente` | 142,808 | 55.9 | 7,975,898 |
| `aos_actividad_benchmark` | 30,222 | 173.4 | 5,240,807 |
| `aos_agentes` | ~400,885 | 3.3 | 1,308,452 |
| `aos_execute_agent_query` | 15,543 | 68.4 | 1,063,190 |

Conclusión: el GET de `aos_agentes` es frecuente pero barato. El mayor costo proviene de RPC de panel y actividad ejecutadas excesivamente, más snapshot y bursts de agentes.

## 4. Defecto confirmado en Home Admin

`app/public/admin-home.html` actualmente:

- ejecuta `ahLoad()` al cargar;
- `ahLoad()` vuelve a llamar `ahTicker()`, `ahRank()`, `ahChart()` y `ahSparklines()`;
- además ejecuta `ahChart()` directamente en inicialización;
- registra `setInterval(ahLoad, 30000)`;
- registra adicionalmente `setInterval(ahChart, 30000)`.

Por tanto `aos_actividad_minutos` puede ejecutarse dos veces por ciclo de 30 s en una sola pestaña, además de las demás RPC y de una consulta de ranking de hasta 5,000 ventas.

## 5. Defectos confirmados en runtime Railway

`app/server.js` actualmente:

- revisa agentes cron cada 30 s aunque sus cron funcionales son mucho menos frecuentes;
- genera `aos_generar_snapshot` cada 5 min;
- revisa Studio cada 60 s;
- no existe un Performance Guard común que aplique timeout, circuit breaker y backoff a esos workers;
- los intervalos pueden seguir disparando aun cuando la infraestructura esté degradada.

Agente `centinela` (Dante) tiene cron `*/30 * * * *` y varias tareas por ejecución. El polling de 30 s no aporta potencia funcional: solo comprueba repetidamente si ya toca una ejecución de 30 min.

## 6. Diseño de Performance Guard

### 6.1 Frontend

- una sola cadencia de refresco para Home Admin;
- no duplicar `ahChart`;
- refresco completo en carga y cuando la pestaña vuelve a estar visible;
- suspender polling cuando `document.hidden=true`;
- evitar solapamiento de requests;
- cadencias diferenciadas por costo: datos core frecuentes, ranking/benchmark menos frecuentes;
- mantener botón/eventos de actualización inmediata cuando el usuario vuelve al módulo.

### 6.2 Railway workers

- Agent scheduler: check menos frecuente que 30 s, sin cambiar cron funcional de cada agente;
- mutex para no iniciar un ciclo si el anterior sigue ejecutándose;
- snapshot: 30 min por background + cache/on-demand existente;
- Studio: mantener precisión operativa razonable pero con mutex y backoff;
- timeout por request;
- circuit breaker para 5xx/timeouts;
- exponential backoff y recuperación automática.

### 6.3 Principio de potencia

Reducir polling redundante NO elimina capacidades. Los eventos de usuario siguen siendo inmediatos y los cron mantienen su frecuencia de negocio. Solo se evita preguntar a Supabase cientos de veces si nada cambió.

## 7. Gate de validación

Antes de reactivar Railway:

1. `node --check app/server.js`.
2. comprobar que Home Admin no tenga doble timer de `ahChart`.
3. confirmar que los workers tengan mutex/backoff.
4. CI verde.
5. desplegar primero de forma controlada.
6. observar 10–15 min: conexiones, 5xx, consultas largas y CPU/RAM.
7. verificar flujos funcionales críticos.
8. solo después continuar remediación de enero.

## 8. Rollback

Rollback de código: redeploy del último commit productivo anterior al Performance Guard.  
Rollback de datos: no aplica; esta fase no modifica datos clínicos/financieros ni esquema.
