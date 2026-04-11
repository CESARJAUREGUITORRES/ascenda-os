---
name: skill-clinica-crm
description: Lógica de negocio específica de clínicas estéticas y wellness para AscendaOS. Usar cuando se construyan módulos de call center, pacientes, citas, ventas, comisiones o seguimientos. Contiene el modelo de datos, terminología, flujos operativos y reglas de negocio validadas con Zi Vital (Lima, Perú).
---

# Clínica CRM — AscendaOS / Zi Vital

## CONTEXTO DEL NEGOCIO

**Cliente piloto:** Zi Vital — clínica de estética y wellness
**Sedes:** San Isidro y Pueblo Libre (Lima, Perú)
**Equipo:** 1 Admin (César) + 4 Asesoras (Wilmer, Ruvila, Mireya, Carmen)
**Credenciales:**
```
ZIV-001 ADMIN  cesar123
ZIV-002 ASESOR ruvila123
ZIV-003 ASESOR mireya123
ZIV-004 ASESOR wilmer123
ZIV-005 ASESOR carmen123
```

## TAXONOMÍA DE BASES (3 dimensiones aprobadas)

```
DIM1 — ESTADO del lead/paciente:
  Virgen          → nunca contactado, nunca tuvo cita
  SinContacto     → contactado antes pero sin respuesta reciente
  Contactado      → se habló pero sin cita agendada
  ConCita         → tiene cita programada
  PacienteActivo  → vino al menos una vez, sigue activo
  Inactivo        → más de 90 días sin actividad
  Provincia       → fuera de Lima, no viable
  Retirado        → pidió no ser contactado
  ConAdelanto     → pagó adelanto, espera servicio

DIM2 — ORIGEN del lead:
  Campaña         → viene de campaña de marketing pagada
  Tratamiento     → interés en tratamiento específico
  Orgánico        → referido o búsqueda orgánica
  MesIngreso      → clasificación temporal
  BaseAntigua     → lead de más de 6 meses
  PacientesHistóricos → atendidos antes, potencial recompra

DIM3 — AGENDA:
  Asistió         → vino a su cita
  NoAsistió       → no se presentó
  Canceló         → canceló con aviso
  CitaPendiente   → tiene cita futura
  ConVentaEnCita  → vino y compró
  ControlRecurrente → cita de seguimiento de tratamiento
```

## SEMÁNTICA DE CAMPAÑA VS TRATAMIENTO

```
CAMPAÑA (campo marketing):
  = LEAD_COL.TRAT = LLAM_COL.TRATAMIENTO
  = tipo de campaña que capturó el lead
  Valores: HIFU, ENZIMAS FACIALES, CAPILAR, HIDROFACIAL, etc.
  → Es el gancho que usó marketing para atraer al lead

TRATAMIENTO (campo clínico):
  = VENT_COL.TRATAMIENTO
  = servicio realmente aplicado en clínica
  → Puede ser distinto a la campaña de origen
  
⚠️ NUNCA mezclar estos dos campos en cálculos de conversión
```

## DEFINICIÓN DE CONVERSIÓN

```
Un lead se considera CONVERTIDO cuando:
  → Tuvo su PRIMERA cita en el período analizado
  → O tiene un VENTA_ID vinculado a su número

La tasa de conversión = convertidos / total leads del período
```

## LÓGICA MADRE DE CALL CENTER (8 pasos — columna vertebral)

```
El call center opera con esta priorización diaria:

PASO 1: Vírgenes mes actual
  → Leads nuevos que ingresaron este mes, nunca llamados
  → Prioridad máxima: están "frescos"

PASO 2: No asistió cita en últimas 2 semanas
  → Tenían cita, no vinieron → oportunidad de re-agendado

PASO 3: Vírgenes históricos
  → Leads de meses anteriores nunca contactados
  → Base de recuperación

PASO 4: Sin contacto mes actual
  → Leads que no recibieron llamada este mes

PASO 5: Canceló o reprogramó
  → Querían venir pero algo pasó → segundo intento

PASO 6: Base antigua sin convertir
  → Más de 6 meses sin convertir → último intento

PASO 7: Pacientes activos recompra 90 días
  → Vinieron hace ~90 días → proponer siguiente tratamiento

PASO 8: Sin contacto histórico
  → Base fría, último recurso del día

ANTI-DUPLICADO DIARIO:
  CacheService key: COLA_HOY_[ASESOR]_[FECHA]
  → Cada asesor no recibe el mismo lead dos veces en el día

DISTRIBUCIÓN:
  PropertiesService key: DIST_CONFIG_[ASESOR_NORM]
  → Configura cuántos de cada tipo recibe cada asesor
```

## TIPIFICACIONES DE LLAMADA

```
CONTACTADO_INTERESADO    → habló, quiere agendar
CONTACTADO_NO_INTERESADO → habló, no le interesa ahora
NO_CONTESTA             → llamada sin respuesta
BUZÓN                   → llegó a buzón de voz
NÚMERO_EQUIVOCADO       → dato incorrecto en base
CITA_AGENDADA           → éxito: tiene cita
REAGENDADO              → tenía cita, se movió a nueva fecha
CANCELÓ                 → canceló definitivamente
VOLVER_A_LLAMAR         → pidió que llamen en otro momento
PROVINCIA               → confirmado fuera de Lima
```

## SEGUIMIENTOS PROGRAMADOS POR TRATAMIENTO

```
Toxina botulínica    → recontactar a los 4-6 meses
Ácido hialurónico   → recontactar a los 12-18 meses
HIFU                → recontactar a los 12 meses
Productos con dosis → calcular fin = (unidades / dosis_diaria) días
                      alertar X días antes de fecha fin
```

## HISTORIA CLÍNICA MINSA (campos obligatorios)

```
Identificación: DNI, nombre completo, fecha_nac, sexo, estado_civil,
                ocupación, distrito, dirección, contacto_emergencia

Antecedentes: alergias, enfermedades_crónicas, medicamentos_actuales,
              cirugías_previas, tratamientos_estéticos_previos,
              queloides (sí/no), implantes (tipo/ubicación)

Campos para mujer: embarazo, lactancia, anticonceptivos, fecha_última_menstruación

Hábitos: tabaco, alcohol, ejercicio, hidratación, protector_solar

Consentimiento: obligatorio por procedimiento, firma digital o física
```

## ROLES Y PERMISOS

```
ADMIN:      todo + delete + merge pacientes + ver todas las sedes
ASESOR:     lectura + notas_ventas + crear_citas + su propia cartera
RECEPCIÓN:  citas + notas_recepción + ver datos básicos
DOCTOR:     notas_médicas + recetas + historia_clínica_completa + descuentos
ENFERMERO:  notas_enfermería + receta_enfermería + plan_cuidados
```

## TIPOS DE PDF

```
1. Comprobante de compra    → QR + código interno + datos de venta
2. Cotización editable      → presupuesto para el paciente
3. Receta médica            → requiere CMP del doctor
4. Receta enfermería        → requiere registro técnico/licenciado
```

## SCORE DE PACIENTE

```
ACTIVO:   última visita < 90 días
RIESGO:   última visita 90-180 días
INACTIVO: última visita > 180 días

Campo: PACIENTES.SCORE_ESTADO + PACIENTES.DIAS_ULTIMA_VISITA
Alerta visual: verde / amarillo / rojo en ficha del paciente
```

## FUNNEL DE CONVERSIÓN

```
LEADS → join LLAMADAS (por NUMERO_LIMPIO) 
      → join AGENDA_CITAS (por numero)
      → join VENTAS (por NUMERO_LIMPIO)

KPIs clave:
  tasa_contacto    = contactados / total_leads
  tasa_cita        = citas_agendadas / contactados  
  tasa_asistencia  = asistidos / citas_agendadas
  tasa_conversión  = ventas / asistidos
  ticket_promedio  = total_ventas / cantidad_ventas
```

## VERTICALES FUTUROS — ADAPTACIONES CLAVE

```
AscendaNails:    sin historia clínica MINSA, agenda por técnica
AscendaLegal:    pacientes → clientes/casos, citas → audiencias
AscendaPsych:    historia clínica psicológica, sesiones recurrentes
AscendaBarber:   sin historial médico, servicios rápidos, fidelización
AscendaEcommerce: sin agenda, pipeline de ventas, seguimiento pedidos
```
