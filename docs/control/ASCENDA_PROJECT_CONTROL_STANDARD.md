# ASCENDA OS — PROJECT CONTROL STANDARD

**Estado:** CURRENT  
**Fecha:** 2026-08-14 (America/Lima)  
**Notion visual:** `ASCENDA OS — Estándar de Control de Proyectos`  
**URL:** `https://app.notion.com/p/3bc0e4fe84148160ad18d30d380782db?pvs=204`

---

## 1. Objetivo

Todo programa/subproyecto relevante de ASCENDA debe poder recuperarse sin depender de memoria conversacional.

La continuidad vive en capas:

1. **GitHub/docs + código/migrations** — fuente de verdad técnica y decisiones versionadas.
2. **Runtime/Supabase live** — evidencia operacional y estado ejecutable.
3. **Memoria técnica (`aos_memory` cuando aplique)** — checkpoint compacto recuperable.
4. **Notion** — capa visual derivada para roadmap, fases, hallazgos y consulta ejecutiva.

Si existe discrepancia, GitHub/runtime prevalecen y Notion debe corregirse.

---

## 2. Estructura mínima por proyecto

### `[Proyecto] — Control Maestro`

Debe incluir:
- misión;
- scope / anti-scope;
- arquitectura/cadena lógica;
- estado ejecutivo;
- índice maestro de fases;
- Definition of Done;
- fuentes canónicas;
- protocolo de recovery;
- próximo checkpoint.

### `Fases [Proyecto]`

Database visual con:
- fase;
- estado;
- progreso;
- riesgo;
- objetivo;
- input contract;
- output contract;
- dependencias;
- gate de salida;
- último checkpoint;
- branch;
- commit/PR;
- actualizado.

Estados estándar:
- `Cerrada`
- `Siguiente`
- `En curso`
- `Bloqueada`
- `Pendiente`

### `Hallazgos & Mejoras [Proyecto]`

Database visual con:
- ID;
- hallazgo;
- tipo;
- estado;
- severidad;
- fase destino;
- dominio;
- origen/evidencia;
- riesgo;
- solución propuesta;
- dependencias;
- criterio de cierre;
- branch/PR;
- actualizado.

Un hallazgo puede resolverse en la fase activa, planificarse, bloquear un gate o quedar aceptado como deuda explícita. Nunca desaparecer por conveniencia.

---

## 3. Loop de actualización

Al cerrar un loop/fase:

1. validar estado técnico real;
2. cerrar GitHub/CI/staging/runtime;
3. actualizar docs/Validation Report/Roadmap;
4. actualizar `aos_memory` si existe;
5. actualizar la fila de la fase en Notion;
6. registrar nuevos hallazgos;
7. marcar `Resuelto` solo con evidencia;
8. dejar exactamente una fase `Siguiente` o `En curso`;
9. registrar próximo checkpoint exacto.

Notion es el último paso de sincronización visual, no el primero.

---

## 4. Recovery desde otro chat/agente

1. leer reglas del repo (`AGENTS.md`, `SECURITY.md` si aplica);
2. leer Master/Bootstrap/índice canónico GitHub;
3. leer la fase activa y último Validation Report;
4. consultar `aos_memory`/checkpoint técnico;
5. consultar Notion Control Maestro + Fases + Hallazgos;
6. verificar branch/PR/commit y runtime live;
7. continuar desde el último checkpoint sin repetir trabajo cerrado.

---

## 5. Proyectos actuales bajo este estándar

### KronIA V2

Notion Control Maestro:
`https://app.notion.com/p/3bc0e4fe8414812db4b6f73e71e3c018?pvs=204`

### Commercial Intelligence & Audience OS V3

Notion Control Maestro:
`https://app.notion.com/p/3bc0e4fe841481489c8ad11bb55acaf3?pvs=204`

Fases:
`https://app.notion.com/p/1a24a1f7e7ab4a299f4848f1eaeff74d`

Hallazgos:
`https://app.notion.com/p/4b3d3d6180ef4fb2b8d978f324e66dfd`

---

## 6. Observabilidad / Sentry

Sentry puede integrarse como evidencia transversal de errores, trazas, performance y releases, pero no sustituye este sistema de control.

Antes de declararlo operativo deben quedar definidos:
- environments;
- releases;
- PII/data scrubbing;
- server tracing;
- frontend error boundaries;
- alertas relevantes;
- acceso/roles;
- vínculo entre eventos Sentry y hallazgos/fases.

Hasta existir evidencia técnica, Sentry se registra como `Planificado`, no como activo.
