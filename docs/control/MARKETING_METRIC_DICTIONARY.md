# ASCENDA OS — DICCIONARIO CANÓNICO DE MÉTRICAS DE MARKETING

Este documento fija el significado de las métricas para evitar mezclar personas, eventos, operaciones y facturación.

## Identidad y adquisición

### Persona única
Un `numero_limpio` distinto dentro del universo analizado.

### Touchpoint / Ingreso de lead
Una fila/evento en `aos_leads`. Una persona puede tener varios touchpoints.

### Reingreso
Touchpoint adicional de una persona ya registrada anteriormente. No es automáticamente duplicado.

### Duplicado técnico
Registro repetido sin un nuevo evento comercial real. Solo se excluye cuando la regla puede demostrarse.

## Gestión

### Lead gestionado
Touchpoint con al menos una gestión atribuible posterior o un vínculo explícito por `lead_id_origen`.

### Lead con cita
Touchpoint cuya gestión atribuible generó al menos una cita.

### Lead asistente
Touchpoint cuya cita atribuible terminó en estado de asistencia/efectividad.

## Conversión

### Cliente convertido
Persona/touchpoint que genera al menos una compra atribuible. Se cuenta una vez por evento de conversión para KPIs de conversión.

### Operación de venta
Fila/transacción de `aos_ventas`. Un cliente convertido puede generar varias operaciones el mismo día o en fechas posteriores.

### Facturación
Suma monetaria de operaciones de venta atribuibles. No equivale a número de clientes ni número de operaciones.

Ejemplo validado Agosto 2026:
- 2 clientes/leads convertidos;
- 6 operaciones de venta;
- S/1,045 de facturación M0.

Los tres valores son correctos y representan conceptos distintos.

## Tipos de atribución

### Adquisición
Primera conversión del cliente atribuible a un evento de marketing.

### Reactivación
Cliente existente que reingresa por un nuevo touchpoint y cuya nueva gestión puede vincularse a dicho touchpoint.

### Seguimiento histórico
Conversión/recompra generada mediante una gestión que continúa utilizando un touchpoint anterior.

### Orgánico / no atribuible
Conversión sin evidencia suficiente para adjudicarla a una campaña/touchpoint.

## Cohortes

### M0
Revenue atribuible ocurrido durante el mes de la cohorte.

### M+1, M+2, M+3...
Revenue posterior por meses transcurridos desde la cohorte, según la regla canónica de atribución/LTV.

### `0` vs `—`
- `0`: el período ya ocurrió y no produjo resultado.
- `—`: el período todavía no ocurrió/no es observable.

## Revenue

### Revenue de adquisición
Revenue asociado a la primera conversión de clientes nuevos.

### Revenue de reactivación
Revenue generado por clientes existentes mediante un touchpoint posterior confirmado.

### LTV de la cohorte de adquisición
Revenue acumulado de los clientes originalmente adquiridos por una cohorte. Puede incluir compras futuras; no debe duplicarse en el revenue total al analizar reactivación.

## Regla de dashboard

Marketing debe mostrar datos del universo derivado de campañas/touchpoints. Las ventas globales de la clínica pertenecen al panel Ventas y no deben contaminar KPIs de Marketing.


## V4.3 — Reconciliación de valor

### Revenue atribuido pagado del período
Facturación M0 atribuible a touchpoints/campañas pagadas del período seleccionado. Debe reconciliar exactamente:

`Revenue atribuido = Adquisición + Reactivación + Seguimiento histórico`.

El revenue orgánico se informa aparte y no entra al KPI pagado.

### LTV de adquisición
Cohorte de clientes nuevos originalmente adquiridos por marketing. Sigue `M0 → M+1 → M+2 → M+3 → M+4+`. No debe absorber revenue de reactivación de clientes preexistentes.

### Valor post-reactivación
Cohorte separada de clientes ya existentes recuperados por un nuevo touchpoint. Sigue `R0 → R+1 → R+2 → R+3 → R+4+`, donde R0 es el mes de reactivación y los meses posteriores acumulan compras posteriores del cliente reactivado.

El valor post-reactivación es longitudinal y no se suma al LTV de adquisición para reconstruir el revenue M0; son cohortes analíticas distintas.

### Trazabilidad de atribución
La auditoría mensual debe mostrar, sin exponer PII completa:
- últimos 4 dígitos del teléfono;
- tipo de atribución;
- `lead_id`, fecha, campaña y anuncio;
- cantidad de llamadas/citas vinculadas;
- método de match y confidence;
- operaciones y facturación.

Jerarquía interpretativa:
1. vínculo explícito `lead_id_origen` / llamada / cita;
2. cadena directa parcial;
3. inferencia fuerte;
4. inferencia por lead único compatible.

La ambigüedad nunca debe convertirse silenciosamente en atribución fuerte.
