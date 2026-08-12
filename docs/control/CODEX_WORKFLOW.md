# ASCENDA OS — CODEX WORKFLOW

## Objetivo

Usar Codex como agente de implementación dentro de un proceso controlado por arquitectura, pruebas y revisión humana.

## Repositorio

`CESARJAUREGUITORRES/ascenda-os`

## Reglas de inicio de tarea

Codex debe:

1. leer `AGENTS.md`;
2. leer `docs/control/ASCENDA_CONTROL_MASTER.md`;
3. confirmar la rama de trabajo;
4. identificar si el cambio afecta producción, datos o seguridad;
5. producir Impact Report para HIGH/CRITICAL;
6. no modificar `main` directamente.

## Modos de trabajo

### Ask / investigación

Usar para:

- comprender flujo;
- localizar bug;
- construir dependency map;
- revisar código;
- proponer diseño;
- no realizar cambios.

### Code / implementación

Usar después de definir alcance y pruebas.

## Contexto obligatorio en tareas visuales

Cuando el requerimiento venga de screenshot:

- indicar pantalla/rol;
- adjuntar imagen;
- describir comportamiento actual;
- describir comportamiento objetivo;
- indicar restricciones móviles/desktop;
- pedir validación del flujo de datos antes de editar.

## Prompt base recomendado

```text
Trabaja sobre ASCENDA OS. Lee AGENTS.md y docs/control/ASCENDA_CONTROL_MASTER.md antes de modificar nada.

Objetivo: [describir]
Evidencia: [screenshot/error/dato]

Primero:
1. identifica archivo productivo, RPC/tablas y efectos secundarios;
2. clasifica riesgo;
3. presenta un Impact Report breve;
4. define pruebas y rollback.

Después implementa en una rama nueva. No modifiques main directamente. No cambies datos de producción salvo autorización explícita. Ejecuta los checks aplicables y resume exactamente qué cambió.
```

## Resultado esperado de cada tarea

- branch;
- archivos modificados;
- migraciones si aplica;
- tests/checks ejecutados;
- riesgos restantes;
- screenshots de validación si aplica;
- PR preparado;
- rollback.
