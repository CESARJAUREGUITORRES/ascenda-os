# ASCENDA Conversations — Expansion Roadmap Beyond WA-8

**Fecha:** 2026-08-15 (America/Lima)  
**Propósito:** registrar mejoras y fases adicionales posteriores al core WA-0→WA-8, sin mezclar deuda de estabilización con innovación futura.

## Core obligatorio antes de expansión

El producto debe completar primero:

- WA-0 arquitectura;
- WA-1 gateway seguro;
- WA-2 inbox/store;
- WA-3 routing/handoff;
- PHASE S estabilización + outbound humano;
- WA-4 copilot;
- WA-5 multimedia/audio;
- WA-6 agenda/follow-up/call center;
- WA-7 attribution/revenue;
- WA-8 production/FinOps/observability.

Las fases siguientes son expansión estratégica, no atajos para saltarse gates.

## WA-9 — Conversation Intelligence & Supervisor Command Center

Objetivo: transformar conversaciones en señales operativas y comerciales accionables.

Capacidades:

- SLA de primera respuesta;
- queue age y alertas de conversación sin atender;
- lead intent/temperature scoring;
- detección estructurada de objeciones;
- next-best-action para asesores;
- supervisor dashboard por box/agente/sede;
- tasa de respuesta, agenda y cierre por agente;
- calidad conversacional con evals auditables;
- motivos de pérdida estructurados;
- abandono de conversación;
- conversaciones reactivables;
- coaching basado en patrones agregados, no exposición indiscriminada de PII.

Principio: IA recomienda; las métricas de performance deben tener definiciones transparentes y auditables.

## WA-10 — Customer 360 & Omnichannel Journey

Objetivo: una sola línea de tiempo del cliente dentro de ASCENDA.

Customer Timeline:

`Meta touchpoint → WhatsApp → llamada → seguimiento → cita → asistencia → venta → pago/cartera → email → nueva conversación`.

Capacidades:

- identidad resolvida por fuentes canónicas;
- timeline unificado sin duplicar pacientes;
- conversación + llamadas + agenda + ventas + email;
- deduplicación controlada;
- provenance explícito;
- vista de historial relevante para el agente;
- handoff entre canales sin perder contexto;
- restricciones por rol para información clínica/financiera.

## WA-11 — Lifecycle Automation & Revenue Recovery

Objetivo: automatizar oportunidades repetitivas de seguimiento sin convertir el sistema en spam.

Casos:

- preguntó precio y dejó de responder;
- recibió disponibilidad y no agendó;
- cita pendiente de confirmación;
- no-show;
- post-atención comercial;
- recompra/retratamiento permitido;
- cartera/recontacto bajo reglas;
- campañas de reactivación segmentadas con opt-in y templates correctos.

Cada automatización requiere:

- motivo;
- elegibilidad;
- ventana temporal;
- opt-in/template policy;
- frequency cap;
- kill switch;
- attribution de resultado.

## WA-12 — Controlled AI Autonomy

Objetivo: permitir autonomía incremental solo después de que Copilot, tools y policies estén certificados.

Escalera de autonomía:

1. `SUGGEST_ONLY` — humano envía;
2. `AUTO_CLASSIFY` — IA clasifica sin escribir al cliente;
3. `AUTO_INTERNAL_ACTION` — tareas internas allowlisted;
4. `AUTO_REPLY_LOW_RISK` — respuestas informativas previamente aprobadas;
5. `AUTO_BOOK_WITH_CONFIRMATION` — agenda bajo confirmación explícita;
6. autonomía comercial ampliada solo mediante nuevos gates.

Nunca autónomo:

- diagnóstico clínico;
- interpretación médica de imágenes;
- cambios financieros sensibles sin policy;
- SQL arbitrario;
- decisiones de acceso/permisos;
- attribution inventada.

## WA-13 — Revenue Optimization Engine

Objetivo: usar la evidencia de WA-7/WA-9 para optimizar operación y marketing.

Capacidades:

- costo por conversación calificada;
- costo por cita;
- costo por asistencia;
- CAC;
- revenue/ROAS;
- AI_ONLY vs HUMAN_ONLY vs HYBRID;
- box/agent conversion;
- campaign-to-sale funnel;
- tratamiento/producto demand signals;
- forecasting de carga conversacional;
- staffing recommendations;
- budget allocation recommendations con aprobación humana.

## WA-14 — Platformization / Reusable Conversation Core

Objetivo: extraer el patrón reusable aprendido en ASCENDA para otros proyectos sin clonar deuda ni secretos.

Separación propuesta:

- provider adapters;
- secure webhook gateway;
- message ledger;
- conversation engine;
- routing/ownership;
- policy engine;
- AI capability router;
- business-tool adapters;
- attribution adapter;
- observability/FinOps.

Configuración por proyecto:

- tenant/business identity;
- roles/permisos;
- CRM/ERP adapters;
- knowledge sources;
- channels;
- privacy policy;
- models/providers;
- cost budgets.

No convertir ASCENDA directamente en multi-tenant durante WA-0→WA-8. Primero certificar el producto real; después extraer patrones estables.

## Mejoras transversales registradas

- unread badge global;
- browser notifications gobernadas;
- queue SLA colors;
- keyboard shortcuts;
- quick replies/templates;
- attachments/media library aprobada;
- audio transcript + summary;
- conversation summary estructurado;
- source/campaign card;
- patient/lead context card;
- booking card in-chat;
- payment/cartera context cuando el rol lo permita;
- saved views y filtros supervisor;
- tags estructuradas;
- search full-text con límites de privacidad;
- export/audit controlado;
- observability por trace/event id;
- incident dashboard;
- model/provider failover;
- cost ceilings por capability;
- retention/deletion policies;
- eval registry y regression suites.

## Orden estratégico

`PHASE S → WA-4 → WA-5 → WA-6 → WA-7 → WA-8 → WA-9 → WA-10 → WA-11 → WA-12 → WA-13 → WA-14`

La prioridad no es “más IA”. La prioridad es **más evidencia, más control, menos fricción y más capacidad de convertir conversaciones en resultados medibles**.
