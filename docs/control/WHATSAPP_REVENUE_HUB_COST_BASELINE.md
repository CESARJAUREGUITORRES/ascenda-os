# ASCENDA Conversations — WA-0 Cost Baseline

**Fecha:** 2026-08-14  
**Objetivo:** modelar costos y límites antes de automatizar tráfico real.  
**Regla:** los precios son variables externas. Este documento conserva snapshot + fuente; el runtime futuro debe registrar `rate_snapshot` por evento y no depender de valores hardcodeados eternamente.

---

## 1. Principio FinOps

El objetivo no es “hacerlo gratis” a cualquier costo. El objetivo es:

1. aprovechar ventanas gratuitas/incluidas de forma legítima;
2. evitar templates de pago innecesarios;
3. usar el modelo de IA mínimo que cumpla calidad;
4. resumir/mantener memoria para no reenviar contexto masivo;
5. reutilizar Railway/Supabase/Resend existentes antes de crear servicios nuevos;
6. medir costo por resultado comercial, no solo costo por API.

Métricas económicas objetivo:

- costo WhatsApp / conversación;
- costo IA / conversación;
- costo audio / conversación;
- infraestructura incremental / conversación;
- costo total / conversación calificada;
- costo / cita;
- costo / asistencia;
- costo / venta;
- CAC total;
- ROAS atribuible;
- costo AI-only vs human-only vs hybrid;
- horas humanas evitadas/recuperadas.

## 2. WhatsApp

### Ventanas que deben modelarse

ASCENDA debe persistir por conversación/contacto:

- `customer_service_window_expires_at`;
- `free_entry_point_expires_at`;
- `free_window_reason`;
- `message_category`;
- `template_name/version` cuando aplique;
- `estimated_cost`;
- `actual_cost`;
- `currency`;
- `rate_snapshot_at`.

Conceptualmente:

- dentro de la Customer Service Window vigente pueden existir mensajes elegibles sin cargo de mensajería;
- entradas elegibles desde Click-to-WhatsApp/entry points pueden habilitar una Free Entry Point extendida bajo reglas de Meta;
- fuera de ventanas gratuitas, los templates entregados pueden generar cargo según categoría/país/rate card;
- marketing masivo debe presupuestarse separadamente de Ads spend.

**Gate financiero:** antes de activar mensajes pagos o masivos, confirmar el rate card efectivo del WABA/Billing Hub y registrar snapshot. Los valores PEN explorados durante WA-0 se consideran referencias, no tarifa contractual certificada.

### Qué no hacer

- no mandar marketing template si un canal gratuito/utility adecuado resuelve la necesidad;
- no enviar campañas a contactos sin opt-in/base legal aplicable;
- no confundir costo Ads con costo mensajería;
- no asumir que una ventana gratuita actual seguirá igual indefinidamente.

## 3. Modelos IA — snapshot verificado

### DeepSeek

Fuente oficial: `https://api-docs.deepseek.com/quick_start/pricing/`

| Modelo | Input cache hit / 1M | Input miss / 1M | Output / 1M | Contexto |
|---|---:|---:|---:|---:|
| DeepSeek V4 Flash | US$0.0028 | US$0.14 | US$0.28 | 1M |
| DeepSeek V4 Pro | US$0.003625 | US$0.435 | US$0.87 | 1M |

Ambos soportan JSON y tool calls según documentación CURRENT.

**Uso candidato:** V4 Flash para conversación normal; V4 Pro solo para reasoning que justifique su costo/latencia.

### Groq GPT-OSS

Fuentes oficiales:

- `https://console.groq.com/docs/model/openai/gpt-oss-20b`
- `https://console.groq.com/docs/model/openai/gpt-oss-120b`

| Modelo | Input / 1M | Cached input / 1M | Output / 1M | Velocidad aprox. | Contexto |
|---|---:|---:|---:|---:|---:|
| GPT-OSS 20B | US$0.075 | US$0.037 | US$0.30 | ~1000 t/s | 131,072 |
| GPT-OSS 120B | US$0.15 | US$0.075 | US$0.60 | ~500 t/s | 131,072 |

Ambos ofrecen tool use, reasoning y JSON Schema Mode.

### Groq Free Plan como laboratorio, no SLA

Fuente: `https://console.groq.com/docs/rate-limits`

Snapshot para GPT-OSS 20B/120B:

- 30 RPM;
- 1,000 requests/día;
- 8K TPM;
- 200K tokens/día.

Esto puede cubrir desarrollo/evals/canary pequeño, pero producción no debe diseñarse suponiendo disponibilidad gratuita infinita.

### Groq deprecations

Fuente: `https://console.groq.com/docs/deprecations`

`llama-3.1-8b-instant` y `llama-3.3-70b-versatile` tienen shutdown Free/Developer el 2026-08-16. Reemplazos recomendados por Groq incluyen GPT-OSS 20B/120B y Qwen según caso.

**Consecuencia:** ningún contrato nuevo WA debe nombrar directamente los Llama legacy.

## 4. Audio

Fuente oficial: `https://console.groq.com/docs/model/whisper-large-v3-turbo`

`whisper-large-v3-turbo`: **US$0.04 por hora de audio**.

Ejemplo puramente matemático con audio promedio de 30 s:

| Audios | Horas | STT aprox. |
|---:|---:|---:|
| 1,000 | 8.33 | US$0.33 |
| 5,000 | 41.67 | US$1.67 |
| 10,000 | 83.33 | US$3.33 |

El principal riesgo de audio no es el STT: es privacidad, almacenamiento, egress y retención de media.

## 5. Batch / insights offline

Groq Batch API ofrece actualmente 50% de descuento sobre pricing síncrono para modelos soportados.

Fuente: `https://console.groq.com/docs/batch`

Casos apropiados:

- resumir conversaciones cerradas;
- extraer objeciones/intenciones;
- evaluar calidad nocturna;
- recalcular insights no interactivos.

No usar batch en paths donde el paciente espera respuesta inmediata.

## 6. Supabase — referencia de escala

Fuente oficial: `https://supabase.com/pricing`

Snapshot público:

### Free

- US$0/mes;
- 500 MB database;
- 1 GB file storage;
- 5 GB egress + 5 GB cached egress.

### Pro

- desde US$25/mes;
- 8 GB disk por proyecto antes de overage;
- 100 GB file storage, luego US$0.0213/GB;
- 250 GB egress y 250 GB cached egress incluidos;
- overages según tarifa vigente.

WA-0 no autoriza upgrade. Primero se mide plan/invoice/uso real y costo marginal del módulo.

## 7. Railway — referencia de escala

Fuentes:

- `https://railway.com/pricing`
- `https://docs.railway.com/pricing`

Snapshot:

- Hobby: US$5 mínimo/incluido de uso;
- Pro: US$20 mínimo/incluido de uso;
- RAM: ~US$10 / GB-mes;
- CPU: ~US$20 / vCPU-mes;
- egress: US$0.05 / GB;
- volume storage: ~US$0.15 / GB-mes.

WA debe reutilizar el runtime actual inicialmente. Un worker/servicio separado solo se justifica si load, aislamiento o confiabilidad lo exige y debe tener Impact Report/costo.

## 8. Resend / email complementario

Fuente oficial: `https://resend.com/pricing`

Snapshot transactional:

- Free: US$0, 3,000 emails/mes, 100/día;
- Pro: US$20/mes, 50,000 emails/mes;
- overage Pro: US$0.90/1,000 emails.

Email puede descargar trabajo de WhatsApp para confirmaciones/información extensa cuando sea comercialmente y legalmente adecuado. No se duplicarán notificaciones sin necesidad.

## 9. Rutas chinas gratuitas / experimentales

SiliconFlow/ModelScope y otros proveedores pueden reducir costo de evals/desarrollo, pero WA-0 no los clasifica como SLA único de producción.

Reglas:

- validar onboarding/KYC y disponibilidad desde Perú;
- verificar data processing/privacy;
- registrar rate limits reales;
- nunca enrutar PII/PHI a un provider nuevo sin aprobación de seguridad/privacidad;
- usar provider abstraction para poder retirarlo sin reescribir negocio.

## 10. Simulación LLM por conversación

Hipótesis conservadora de ingeniería: `20,000 input + 4,000 output tokens` por conversación completa.

| Modelo | costo aprox. / conversación | 1,000 conv. | 10,000 conv. |
|---|---:|---:|---:|
| GPT-OSS 20B | US$0.0027 | US$2.70 | US$27.00 |
| DeepSeek V4 Flash (cache miss) | US$0.00392 | US$3.92 | US$39.20 |
| GPT-OSS 120B | US$0.0054 | US$5.40 | US$54.00 |

No incluye WhatsApp, Ads, infra, storage ni humanos. Es una simulación para dimensionar que el LLM probablemente no será el principal costo variable frente a marketing templates/ad spend.

## 11. Cost ledger objetivo

Cada evento facturable/relevante debe poder generar un registro conceptual:

```json
{
  "conversation_id": "...",
  "provider": "meta|groq|deepseek|resend|...",
  "service": "whatsapp_marketing|llm|stt|email|...",
  "model_or_template": "...",
  "quantity": 0,
  "unit": "tokens|message|seconds|email|gb",
  "currency": "USD|PEN",
  "unit_rate": 0,
  "estimated_cost": 0,
  "actual_cost": null,
  "campaign_id": null,
  "lead_id_origen": null,
  "appointment_id": null,
  "sale_id": null,
  "rate_snapshot_at": "..."
}
```

No se exige una tabla con este nombre exacto; el contrato final se define en WA-1/WA-2.

## 12. Presupuesto seguro por etapas

### Desarrollo / WA-0..WA-4

Objetivo de costo incremental pagado: cercano a cero usando:

- Zero-Cost CI V2;
- proveedores free para evals cuando sea seguro;
- fixtures/synthetic data;
- infraestructura ya existente;
- ningún blast promocional.

### Canary

Definir hard limits por:

- conversaciones/día;
- templates pagos/día;
- tokens/día por provider;
- audio minutos/día;
- spend USD/PEN;
- error/retry budget.

### Producción

Los dueños deben ver costo por outcome y alertas de presupuesto, no solo facturas técnicas.

## 13. Fuente de verdad económica

1. Billing/usage del proveedor real.
2. Rate snapshot/version de ASCENDA.
3. Cost ledger interno.
4. Notion como capa ejecutiva derivada.

Si una tarifa externa cambia, el dashboard debe conservar el costo histórico real de mensajes anteriores y usar la tarifa nueva solo hacia adelante.
