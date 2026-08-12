# ASCENDA OS — MASTER CONTROL, STABILIZATION & SAAS ROADMAP

**Estado:** Documento canónico de control — Baseline 2026-08-12  
**Rama de auditoría:** `audit/ascenda-control-2026-08-12`  
**Baseline GitHub:** `44b6ee83342cbefd69343e9a5b8a8b1db9c0791c`  
**Supabase actual:** proyecto operativo `ituyqwstonmhnfshnaqz`  
**Última migración detectada al levantar la baseline:** `20260808220954` (`fix_importar_ventas_dedup_by_id`)  
**Clasificación:** Arquitectura y gobierno. Los detalles sensibles de seguridad se mantienen fuera de este documento mientras el repositorio sea público.

---

## 1. MISIÓN DEL PROYECTO

ASCENDA debe pasar por cuatro estados claramente separados:

1. **CONTROLAR** — conocer y documentar el sistema real, sus fuentes de verdad, dependencias, despliegue, datos y riesgos.
2. **ESTABILIZAR** — corregir seguridad, deuda técnica, datos inconsistentes, procesos de despliegue y fallos sin romper producción.
3. **MIGRAR A PROPIEDAD CORPORATIVA** — mover la versión probada a cuentas, repositorios, proyectos y credenciales propiedad de la empresa.
4. **PRODUCTIZAR COMO SaaS** — construir una versión independiente, multi-clínica, administrable y escalable, usando ASCENDA probado como referencia funcional, no como una copia improvisada de producción.

La regla principal es: **no convertir producción en SaaS directamente**. Primero se estabiliza el producto operativo; después se crea una arquitectura SaaS separada.

---

## 2. DEFINICIÓN OPERATIVA DE “100% DE CONTROL”

No significa que el software deje de evolucionar. Significa que para una baseline determinada podemos responder con evidencia:

- qué código está en producción;
- qué versión de base de datos está activa;
- qué archivo/panel usa qué RPC, tabla, endpoint o integración;
- qué tabla es fuente de verdad para cada entidad de negocio;
- qué automatizaciones y triggers generan efectos secundarios;
- qué permisos existen y quién puede ejecutar cada acción;
- cómo se despliega, valida, revierte y recupera cada cambio;
- qué componentes son productivos, legacy, documentación, backup o experimento;
- qué datos deben migrarse y cuáles no;
- qué pruebas protegen los flujos críticos.

### Gates obligatorios para declarar CONTROL 100%

- [ ] G01 — GitHub inventariado y clasificado por archivo/directorio.
- [ ] G02 — Supabase inventariado: tablas, vistas, RPC, triggers, índices, políticas, Storage y extensiones.
- [ ] G03 — Matriz UI → API/RPC → tabla → efectos secundarios terminada.
- [ ] G04 — Fuentes de verdad de negocio definidas.
- [ ] G05 — Mapa de dependencias de alto impacto terminado.
- [ ] G06 — Autenticación, autorización y sesiones completamente modeladas.
- [ ] G07 — Integraciones y secretos inventariados sin exponer valores.
- [ ] G08 — CI/CD, Railway y versionado de DB documentados.
- [ ] G09 — Backups, restore y rollback probados.
- [ ] G10 — Datos críticos validados mediante reglas reproducibles.
- [ ] G11 — Flujos E2E críticos probados.
- [ ] G12 — Documentación canónica actualizada y documentos históricos marcados como tales.

Hasta que los doce gates estén cerrados, no se usará la etiqueta “100% controlado”.

---

## 3. BASELINE TÉCNICA VERIFICADA

### 3.1 GitHub

Estado levantado:

- repositorio actual: `CESARJAUREGUITORRES/ascenda-os`;
- rama principal: `main`;
- baseline: commit `44b6ee83342cbefd69343e9a5b8a8b1db9c0791c`;
- no se detectó un flujo histórico de Pull Requests como mecanismo normal de entrega;
- solo se detectó una rama principal antes de esta auditoría;
- se creó una rama documental aislada para este control;
- el repositorio está actualmente expuesto públicamente, por lo que los anexos confidenciales no deben publicarse aquí.

### 3.2 Producción / Railway

La aplicación productiva usa `app/` como raíz de servicio. `app/railway.json` y `app/nixpacks.toml` confirman:

- instalación con npm;
- no se ejecuta un build de Vite para las pantallas productivas;
- `node server.js` es el proceso de arranque;
- `app/public/` contiene el frontend servido directamente;
- el modelo de despliegue actual está fuertemente acoplado a cambios de código en la rama conectada a Railway.

### 3.3 Supabase

Inventario medido directamente en la base al crear esta baseline:

| Objeto | Cantidad |
|---|---:|
| Tablas físicas `aos_*` | 166 |
| Views `aos_*` | 3 |
| Materialized views `aos_*` | 1 |
| Funciones/RPC `aos_*` | 239 |
| Funciones `SECURITY DEFINER` | 191 |
| Triggers `aos_*` | 21 |
| Primary Keys | 165 |
| Foreign Keys | 35 |
| Unique constraints | 26 |
| Check constraints | 35 |
| Índices | 351 |
| Tablas con RLS habilitado | 37 |
| Políticas RLS detectadas | 69 |
| Migraciones registradas | 438 |

La base `aos_*` ocupa aproximadamente **78 MB** en la baseline y concentra alrededor de **139 mil filas estimadas**.

### 3.4 Vistas

- `aos_notif_no_leidas`
- `aos_team_full`
- `aos_v_profesional_stats`
- materialized view: `aos_llamadas_ultimo`

### 3.5 Edge Functions / Realtime

- no se detectaron Edge Functions desplegadas;
- Realtime publica actualmente un conjunto reducido de tablas operativas;
- la mayor parte de la lógica vive en PostgreSQL RPC + Node/Railway + frontend estático.

---

## 4. TOPOLOGÍA REAL DEL REPOSITORIO

El repositorio contiene varias generaciones de ASCENDA. No deben confundirse.

### A. `app/` — PRODUCCIÓN ACTUAL

Es la fuente de código que debe considerarse primaria para la aplicación desplegada actualmente.

Componentes principales:

- `app/server.js` — servidor Node, APIs e integraciones.
- `app/public/app.html` — shell principal.
- `app/public/login.html` — acceso.
- `app/public/admin-*.html` — módulos administrativos.
- `app/public/*.html` y `*.js` — módulos asesor/operación.
- `app/public/agents.html`, `cerebro.html`, `studio.html` — IA/agents/studio.
- `app/railway.json`, `app/nixpacks.toml` — ejecución Railway.

### B. `src/` — GENERACIÓN HISTÓRICA / LEGACY A CLASIFICAR

Contiene versiones anteriores, entre ellas frontend y backend asociados al modelo de sincronización histórica.

No debe borrarse hasta completar el mapa de equivalencias con `app/`.

### C. `docs/` + documentos raíz — MEMORIA HISTÓRICA

Contiene conocimiento valioso, pero varios documentos describen estados ya superados. Debe añadirse una política explícita de vigencia documental:

- `CURRENT` — verdad vigente;
- `HISTORICAL` — útil como historia, no como arquitectura actual;
- `SUPERSEDED` — reemplazado;
- `ARCHIVED` — conservado solo para trazabilidad.

### D. `aos_codigo_fuente` — FUENTE HISTÓRICA EN SUPABASE

Se detectó que mantiene código/documentación principalmente de abril 2026. El workflow de GitHub `sync-supabase.yml` sincroniza este contenido hacia `src/` y `docs/`, no hacia `app/`.

Por tanto, **`aos_codigo_fuente` no puede tratarse hoy como fuente de verdad de producción**.

### E. `.github/workflows/sync-supabase.yml`

Workflow horario que conserva la arquitectura histórica Supabase → GitHub para `src/` y `docs/`.

Debe ser revisado antes de establecer el nuevo modelo canónico de repositorio porque puede seguir generando ruido o reintroduciendo documentación/código antiguo.

---

## 5. DOMINIOS FUNCIONALES ACTUALES

Las 166 tablas se agrupan preliminarmente en estos dominios. La clasificación definitiva se cerrará en G02/G04.

### CRM / comercial

`aos_leads`, `aos_leads_en_curso`, `aos_llamadas`, `aos_seguimientos`, `aos_pacientes`, `aos_base_etiquetas`, `aos_ventas`, `aos_metas_ventas`, `aos_metas_llamadas`, `aos_inversion_campanas`.

### Agenda y atención clínica

`aos_agenda_citas`, `aos_atenciones`, `aos_filiacion_medica`, `aos_notas_clinicas`, `aos_evaluaciones_clinicas`, `aos_evoluciones`, `aos_historia_clinica`, `aos_planes_trabajo`, `aos_plan_trabajo_items`, `aos_sesiones_tratamiento`, `aos_prescripciones`, `aos_consentimientos`, `aos_fotos_clinicas`, `aos_fotos_paciente`, `aos_documentos_pacientes`.

### Caja, ventas, pagos y facturación

`aos_caja_sesiones`, `aos_caja_gastos`, `aos_caja_log`, `aos_cotizaciones`, `aos_cotizacion_items`, `aos_pagos`, `aos_ventas`, `aos_comprobantes`, `aos_documentos_fiscales`, `aos_razones_sociales`, `aos_metodos_pago`, `aos_tipos_comprobante`, `aos_reglas_fiscales`.

### Inventario

`aos_inventario`, `aos_movimientos_inv`, `aos_transferencias_inv`, `aos_reportes_conteo`, `aos_incidencias_conteo`, `aos_alertas_inv`, `aos_inv_alertas_agente`, `aos_inv_patrones`, `aos_pedidos_internos`.

### Catálogo

`aos_catalogo_categorias`, `aos_catalogo_servicios`, `aos_catalogo_variantes`, `aos_catalogo_productos_detalle`, `aos_catalogo_servicio_producto`, `aos_catalogo_toppings`, `aos_cat_tratamientos`, `aos_cat_anuncios`, `aos_promociones`, `aos_pricing`.

### Equipo, identidad y permisos

`aos_usuarios`, `aos_rrhh`, `aos_auth_codes`, `aos_sesiones_acceso`, `aos_security_log`, `aos_turnos`, `aos_horarios_personal`, `aos_horarios_doctoras`, `aos_horarios_profesional`, `aos_perfiles_profesional`, `aos_paneles_disponibles`, `aos_sedes_geo`.

### Comunicación

`aos_mensajes`, `aos_canales`, `aos_grupos`, `aos_notificaciones`, `aos_log_notificaciones`, `aos_plantillas_mensajes`, `aos_plantillas_whatsapp`, `aos_whatsapp_mensajes`.

### Email

`aos_email_*`, `aos_emails_*`.

### IA / agentes / KronIA

`aos_agentes`, `aos_agente_*`, `aos_kronia_*`, `aos_maya_conversaciones`, `aos_snapshot_global`, `aos_predicciones_paciente`.

### Studio / marketing de contenido

`aos_studio_*`, `aos_brand_assets`, `aos_redes_sociales`, `aos_meta_*`.

### Configuración, auditoría y memoria

`aos_configuracion`, `aos_integraciones`, `aos_codigo_fuente`, `aos_memory`, `aos_session_log`, `aos_log_auditoria`, `aos_auditoria_ediciones`, `aos_webhook_log`.

### Backup / no operativo

`aos_ventas_backup_julio_20260808` — copia de estructura de `aos_ventas`, pendiente de política formal de retención.

---

## 6. NÚCLEOS DE DEPENDENCIA

Se realizó un análisis semántico de las definiciones RPC contra nombres de tablas. La baseline contiene aproximadamente **633 relaciones RPC → tabla** detectables estáticamente.

Tablas con mayor radio de dependencia:

| Tabla | RPC que la referencian aprox. |
|---|---:|
| `aos_ventas` | 54 |
| `aos_agenda_citas` | 41 |
| `aos_llamadas` | 34 |
| `aos_pacientes` | 24 |
| `aos_inventario` | 23 |
| `aos_leads` | 23 |
| `aos_movimientos_inv` | 18 |
| `aos_rrhh` | 18 |
| `aos_horarios_personal` | 13 |
| `aos_catalogo_servicios` | 12 |

RPC de alto radio:

- `aos_fusionar_pacientes` — referencia decenas de tablas;
- `aos_fusionar_multiple` — referencia decenas de tablas;
- `aos_admin_cambiar_username` — identidad y auditoría transversal;
- `aos_kronia_explorar` — múltiples dominios;
- `aos_detalle_atencion` — clínica/comercial;
- `aos_grabar_venta_caja` — caja, venta, cotización y sesiones;
- `aos_paciente_360` — vista transversal del paciente;
- `aos_siguiente_lead` — call center/agenda/seguimiento/ventas.

**Regla futura:** ninguna modificación en estos nodos se realizará sin un Impact Report previo.

---

## 7. FLUJOS MADRE QUE DEBEN QUEDAR PROTEGIDOS

### F01 — Lead a venta

Lead → clasificación → cola → llamada → seguimiento → cita → paciente → venta.

### F02 — Flujo clínico

Agenda → llegada/asistencia → atención → triaje/evaluación → plan de trabajo → cotización/pago → sesiones/procedimiento → evolución/seguimiento.

### F03 — Caja y facturación

Cotización/venta → pago → sesión de caja → comprobante/documento fiscal → conciliación.

### F04 — Inventario

Ingreso → stock → reserva/consumo → movimiento → conteo → incidencia → transferencia/alerta.

### F05 — Marketing

Campaña/inversión → lead → llamada → cita → venta → atribución → CPL/CAC/ROAS.

### F06 — Equipo e identidad

Usuario/RRHH → rol/permisos → acceso → actividad → auditoría → comisiones/metas.

### F07 — IA/KronIA

Identidad de usuario → contexto → consulta/acción → RPC permitida → confirmación → auditoría → resultado.

Cada flujo tendrá posteriormente pruebas de contrato y E2E reproducibles.

---

## 8. MODELO DE DATOS: HALLAZGO ESTRUCTURAL

ASCENDA tiene pocas Foreign Keys en relación con la cantidad de tablas. El core comercial y clínico se vincula principalmente mediante contratos lógicos como:

- `numero_limpio`;
- IDs de texto (`cita_id`, `atencion_id`, `plan_id`, `plan_item_id`, `cotizacion_id`, etc.);
- `codigo_asesor`;
- nombres/roles heredados.

Esto implica:

1. no se puede inferir el impacto únicamente con Foreign Keys;
2. el grafo lógico es parte esencial de la documentación;
3. antes de añadir constraints deben validarse datos históricos;
4. `numero_limpio` debe estudiarse como identificador transversal y no modificarse sin análisis global.

El esquema también conserva columnas legacy de pacientes con nombres mixtos/espacios/acentos junto a campos normalizados. Se deberá diseñar una capa canónica antes de productizar el sistema.

---

## 9. SEGURIDAD — ESTADO DE CONTROL

**Nota:** por tratarse hoy de un repositorio público, este documento no contiene valores de secretos, recetas de explotación ni detalle ofensivo.

La auditoría verificó áreas P0/P1 que deben resolverse antes de migración corporativa o SaaS:

### P0 — Identidad y autorización

- autenticación actual todavía depende de un modelo propio y no de una identidad Supabase Auth plenamente enlazada;
- existen usuarios sin vínculo efectivo con `auth.users`;
- el manejo histórico de contraseñas requiere migración a un esquema criptográfico/managed-auth;
- autorización de varias acciones se basa en parámetros de rol/usuario y no siempre en identidad derivada de JWT.

### P0 — Permisos de base

- RLS no está habilitado de forma restrictiva en todo el esquema expuesto;
- muchas políticas actuales son permisivas;
- el rol anónimo tiene una superficie de privilegios que debe reducirse drásticamente;
- las funciones `SECURITY DEFINER` deben auditarse una a una y concederse mediante allowlist por rol.

### P0 — Secretos

- se detectó material sensible/configuración histórica en código e historial;
- todos los secretos operativos deberán rotarse y centralizarse en variables de entorno/Vault/secret manager;
- una futura migración corporativa debe considerar que transferir Git conserva el historial, por lo que la higiene de secretos es un proyecto separado de cambiar el propietario del repo.

### P0 — Storage

- las políticas de objetos requieren revisión antes de considerar aislados los buckets privados;
- documentos clínicos y archivos de pacientes deben quedar sujetos a autorización efectiva, no solo a la propiedad `public=false` del bucket.

### P1 — APIs Railway

- endpoints con capacidad de envío/publicación deben incorporar autenticación/autorización, CORS limitado, rate limiting y validación robusta;
- ningún fallback de secreto debe permanecer dentro del código.

### P1 — Vistas y funciones

- las views y funciones que exponen información transversal se revisarán bajo principio de mínimo privilegio;
- las RPC dinámicas y de escritura requieren controles de identidad y permisos independientes de parámetros manipulables por cliente.

---

## 10. SINGLE-TENANT ACTUAL VS SAAS FUTURO

La base actual **no posee una abstracción general de tenant/organization/clinic** presente transversalmente en las tablas de negocio. Por tanto ASCENDA actual es, arquitectónicamente, **single-tenant**.

No se añadirá `tenant_id` masivamente a producción antes de estabilizarla.

### Arquitectura SaaS objetivo — proyecto separado

Se estudiarán dos modelos:

#### Modelo A — Base compartida multi-tenant

- una plataforma Supabase;
- `tenant_id` en todos los objetos de negocio;
- RLS obligatorio por tenant + usuario + rol;
- Storage namespaced por tenant;
- menor coste operativo;
- exige disciplina extrema de aislamiento.

#### Modelo B — Proyecto/data-plane por clínica

- una instancia/proyecto de datos por clínica;
- aislamiento más fuerte;
- actualizaciones y observabilidad orquestadas desde un control plane;
- mayor coste y complejidad operativa.

#### Dirección recomendada para diseño

Usar una **arquitectura híbrida de control plane + data plane**:

- un SaaS Core independiente del proyecto Zi Vital;
- control plane central para tenants, planes, configuración, billing, provisioning y estado;
- definir durante la fase de arquitectura si el data plane será compartido con RLS fuerte o aislado por cliente según requisitos de privacidad, coste y operación;
- nunca mezclar los datos reales de Zi Vital con los tenants SaaS.

---

## 11. PLAN MAESTRO DE EJECUCIÓN

# FASE 0 — CONTROL Y FREEZE LÓGICO

**Objetivo:** crear la verdad canónica sin cambiar comportamiento productivo.

Entregables:

- baseline Git + DB;
- inventario de repositorio;
- inventario de DB;
- mapa de dominios;
- mapa triggers;
- mapa RPC/table;
- mapa UI/RPC/table;
- inventario de integraciones;
- inventario de secretos sin valores;
- matriz de criticidad;
- documento Master Control.

**Gate:** G01–G08 documentados.

# FASE 1 — CONTENCIÓN DE SEGURIDAD

Orden seguro propuesto:

1. establecer destino privado para el código/documentación sensible;
2. inventariar y rotar secretos expuestos/históricos;
3. eliminar secretos hardcodeados y fallbacks;
4. centralizar configuración por entorno;
5. definir modelo de Auth/JWT;
6. revisar GRANT por tabla;
7. migrar RLS por dominio con pruebas;
8. revisar/revocar EXECUTE RPC innecesario;
9. endurecer `SECURITY DEFINER`;
10. endurecer Storage;
11. autenticar APIs Railway y limitar CORS/rate;
12. validar sesiones, 2FA y auditoría.

**Principio:** seguridad se migra por dominios y pruebas; no mediante un “cerrar todo” que deje la clínica sin operar.

# FASE 2 — DATABASE AS CODE

**Objetivo:** GitHub debe poder reconstruir la estructura de Supabase.

Acciones:

- inicializar estructura Supabase CLI en el repositorio canónico;
- recuperar/sincronizar las 438 migraciones o crear baseline reproducible validada;
- versionar schema, policies, functions y Storage config;
- dejar de depender de cambios manuales no representados en Git;
- toda nueva DDL entra por migration;
- separar seed de datos y migraciones estructurales;
- reconciliar Git HEAD ↔ versión de DB.

**Gate:** una base vacía de staging debe poder recrearse a partir del repositorio.

# FASE 3 — GOBIERNO GIT + CI/CD

Modelo objetivo:

`feature/*` → PR → CI → preview/staging → aprobación → `main` → producción.

Controles:

- proteger `main`;
- prohibir push directo normal;
- requerir PR;
- requerir checks;
- añadir lint/syntax checks;
- pruebas SQL/contract;
- smoke tests;
- pruebas de flujos críticos;
- Railway despliega producción solo tras checks aprobados;
- usar entornos preview/staging para cambios de aplicación y DB.

# FASE 4 — DATA QUALITY & SOURCE OF TRUTH

Definir contrato por entidad:

- Paciente;
- Lead;
- Llamada;
- Seguimiento;
- Cita;
- Atención;
- Plan;
- Cotización;
- Pago;
- Venta;
- Sesión;
- Producto/stock;
- Usuario/colaborador;
- Campaña.

Para cada uno:

- PK canónica;
- identificadores legacy;
- campos obligatorios;
- unicidad;
- relaciones;
- estados permitidos;
- reglas de deduplicación;
- auditoría;
- lifecycle;
- fuente de verdad.

Luego ejecutar validaciones de datos y corregir anomalías mediante migraciones/scripts auditables.

# FASE 5 — ESTABILIZACIÓN FUNCIONAL

Crear matriz de pruebas E2E para F01–F07.

Solo después:

- corregir bugs;
- eliminar código muerto;
- unificar duplicidades;
- mejorar rendimiento;
- completar paneles;
- optimizar UX;
- optimizar RPC y consultas;
- añadir observabilidad.

Cada cambio incluirá Impact Report + rollback.

# FASE 6 — RECUPERACIÓN Y OPERACIÓN

- estrategia de backup DB;
- estrategia de backup Storage;
- prueba real de restore;
- RPO/RTO definidos;
- runbook de incidente;
- health checks;
- alertas de errores;
- métricas de DB/API;
- limpieza/retención de logs;
- auditoría de costes y capacidad.

# FASE 7 — MIGRACIÓN A PROPIEDAD CORPORATIVA

Destino:

- GitHub Organization de la empresa;
- repositorio privado;
- Supabase Organization de la empresa;
- Railway/proveedor de despliegue bajo cuenta de empresa;
- emails/tokens/API keys propiedad de empresa;
- mínimo dos administradores/owners humanos autorizados;
- recuperación y MFA institucional.

Dos estrategias Git posibles:

**Transferencia de repo:** conserva historial y configuración, pero conserva también historial que pueda contener secretos.

**Migración limpia:** crea repositorio corporativo nuevo a partir de una versión saneada y permite excluir material legacy/confidencial. Requiere conservar un archivo histórico controlado para trazabilidad.

La decisión se toma tras finalizar la auditoría de secretos.

Migración Supabase:

1. crear proyecto corporativo vacío;
2. reconstruir schema desde migrations;
3. validar Auth/config/policies;
4. migrar datos por lotes y reconciliar conteos/checksums;
5. migrar Storage;
6. configurar secretos/integraciones nuevas;
7. staging paralelo;
8. freeze de escritura corto;
9. delta final;
10. cutover;
11. smoke/E2E;
12. rollback disponible;
13. retirar infraestructura antigua solo tras período de seguridad.

# FASE 8 — ASCENDA SaaS

Crear un proyecto **nuevo**:

- repositorio SaaS independiente;
- proyecto(s) Supabase independiente(s);
- entorno dev/staging/prod independiente;
- branding configurable;
- tenant provisioning;
- roles por tenant;
- aislamiento de datos;
- aislamiento Storage;
- planes/limits;
- billing;
- logs por tenant;
- auditoría;
- feature flags;
- soporte/impersonation controlada y auditada;
- exportación/portabilidad;
- backups;
- panel de administración del proveedor;
- onboarding y offboarding de clínicas.

ASCENDA Zi Vital se convierte en **reference implementation + caso real validado**, no en la misma base de datos del SaaS.

---

## 12. PROTOCOLO DE CAMBIO DESDE ESTA BASELINE

Toda modificación futura debe documentar:

1. objetivo funcional;
2. problema/hipótesis;
3. archivos afectados;
4. RPC afectadas;
5. tablas afectadas;
6. triggers/side effects;
7. permisos/seguridad;
8. migración necesaria;
9. pruebas antes;
10. pruebas después;
11. rollback;
12. resultado real;
13. actualización de documentación.

### Semáforo

- 🟢 bajo impacto — UI aislada/lectura;
- 🟡 impacto medio — módulo funcional con contratos conocidos;
- 🔴 alto impacto — ventas, pacientes, agenda, clínica, caja, identidad, inventario;
- ⚫ crítico — Auth, permisos, RLS, migraciones, secrets, fusiones masivas, deploy.

---

## 13. DEFINITION OF DONE PARA UN CAMBIO

Un cambio NO está terminado porque “se ve bien”. Está terminado cuando:

- código versionado;
- migración versionada si aplica;
- tests pasan;
- permisos verificados;
- deploy verificado;
- datos de prueba reconciliados;
- no rompe flujos madre;
- rollback conocido;
- documentación actualizada.

---

## 14. PRIORIDAD INMEDIATA

### P0 — antes de nuevas mejoras

1. completar matriz de seguridad confidencial;
2. decidir/crear destino privado corporativo para documentación sensible;
3. reconciliar migrations Supabase ↔ Git;
4. establecer staging;
5. crear CI mínimo;
6. definir futura Auth/RLS;
7. rotar/centralizar secretos;
8. validar backups/restore.

### P1 — estabilización

1. matriz UI→RPC→tabla completa;
2. validación de datos core;
3. pruebas F01–F07;
4. corregir bugs por severidad;
5. eliminar ambigüedades de funciones/legacy tras comprobar dependencias;
6. observabilidad.

### P2 — propiedad corporativa

Migración controlada GitHub + Supabase + Railway + integraciones.

### P3 — producto SaaS

Arquitectura multi-tenant independiente, onboarding de primeras clínicas y operación administrada.

---

## 15. LO QUE NO DEBE HACERSE

- no borrar `src/`, `docs/` ni tablas legacy por apariencia;
- no añadir multi-tenancy directamente a la DB productiva sin diseño;
- no hacer refactor masivo durante la estabilización;
- no mover secretos copiándolos entre repositorios;
- no asumir que `bucket public=false` equivale a autorización correcta;
- no asumir que RLS habilitado equivale a RLS seguro;
- no usar la existencia de una FK como único mapa de dependencias;
- no modificar `main` para experimentar;
- no declarar un bug resuelto sin prueba del flujo completo afectado;
- no migrar la empresa hasta poder reconstruir la plataforma desde código/migrations.

---

## 16. ESTADO DE COBERTURA DE ESTA AUDITORÍA

### Verificado

- baseline Git;
- estructura de ejecución Railway en repo;
- fuente productiva `app/`;
- coexistencia de legacy `src/`/`aos_codigo_fuente`;
- inventario cuantitativo de DB;
- views/materialized view;
- triggers;
- dependencias RPC→tabla de alto nivel;
- dominios funcionales;
- Storage y RLS a nivel de riesgo;
- modelo Auth actual a nivel arquitectónico;
- agentes/KronIA a nivel estructural;
- ausencia de abstracción multi-tenant global;
- divergencia Git ↔ historial de migrations de DB;
- flujo de despliegue base.

### Pendiente para cerrar G01–G12

- inventario archivo por archivo con estado CURRENT/LEGACY/ARCHIVE;
- matriz exhaustiva de cada UI → cada RPC/REST → tabla;
- matriz exhaustiva de cada RPC → permisos → caller;
- catálogo de endpoints Node con autenticación y consumidor;
- data profiling/quality por entidad;
- pruebas de restauración;
- pruebas E2E formalizadas;
- CI/staging implantados;
- anexo confidencial de seguridad en destino privado;
- plan de cutover corporativo con cuentas definitivas.

---

## 17. PRINCIPIO DE ARQUITECTURA A PARTIR DE HOY

> **ASCENDA deja de ser un conjunto de fixes acumulados y pasa a ser un sistema gobernado.**

Cada decisión debe poder rastrearse desde requerimiento → arquitectura → cambio → prueba → deploy → dato → documentación.

Este documento es el punto de partida canónico para lograrlo.

---

**Última actualización:** 2026-08-12  
**Próxima actualización obligatoria:** al cerrar cada gate de CONTROL o al modificar arquitectura estructural.
