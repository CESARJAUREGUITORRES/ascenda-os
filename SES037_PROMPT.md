# SES-037 — PROMPT COMPLETO DE CONTINUIDAD
## Cerrar CRM AscendaOS — Validar, Pulir, Integrar, Optimizar
## Fecha: 5 mayo 2026 | Presentación: miércoles 7 mayo

---

## PASO 1 OBLIGATORIO — LEER MEMORIA DE SUPABASE

Antes de hacer CUALQUIER cosa, ejecuta estos queries con Supabase MCP (project: ituyqwstonmhnfshnaqz):

```sql
SELECT categoria, clave, substring(valor from 1 for 300) as preview 
FROM aos_memory 
WHERE categoria IN ('INICIO_SESION','PROYECTO','ESTADO','REGLAS','PENDIENTE','TECNICO','OPTIMIZACION') 
ORDER BY categoria, clave;
```

```sql
SELECT nombre, tipo, estado, api_key 
FROM aos_integraciones 
WHERE estado='conectado' AND api_key IS NOT NULL AND api_key != '';
```

Luego clona el repo (token de GitHub leer de aos_memory clave='github_token') y verifica Railway:
```bash
# Token de clone: leer de Supabase → aos_memory WHERE clave='github_token'
cd ascenda-os && git log --oneline -5
curl -s -o /dev/null -w "%{http_code}" https://ascenda-os-production.up.railway.app/app
```

---

## CONEXIONES Y CREDENCIALES COMPLETAS

### Supabase AscendaOS
- Project ID: ituyqwstonmhnfshnaqz
- Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dXlxd3N0b25taG5mc2huYXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NDQyMTgsImV4cCI6MjA5MDMyMDIxOH0.w_pU4ecrrgekB7WzWrQrQd_7Deu_Cxm5ybUCZry5Mh0
- 162 tablas, 205 RPCs, 162+ registros en aos_memory

### Supabase Creactive-core
- Project ID: tgnezlhtqkiucwmrdirw

### GitHub
- Repo: CESARJAUREGUITORRES/ascenda-os
- Token: LEER de aos_memory WHERE clave='github_token'
- 1,012+ commits

### Railway
- URL: ascenda-os-production.up.railway.app
- Auto-deploy desde GitHub main

### APIs con keys (LEER de aos_integraciones WHERE estado='conectado')
- Gemini: key en BD → imágenes 500/día GRATIS
- Groq: key en BD → copys GRATIS ilimitados
- Resend: info@zivital.pe (emails)

---

## ESTADO DEL PROYECTO — 4 MAYO 2026

- 7,166 pacientes | 17,046 llamadas | 1,619 citas | 692 ventas
- 31,490 líneas de código (28,403 frontend + 3,087 server)
- 38 archivos HTML/JS + server.js

### Paneles ✅ Completos:
Login, Home Admin/Asesor, Call Center, Agenda, Caja, Seguimientos, Comisiones, Equipo, Catálogo, Inventario, Configuración, Email Mkt, Facturación, Coordinación

### Paneles 🟡 Parciales:
Flujo clínico (falta descuento insumos), Ventas (falta etiquetas), Marketing (falta redes), Comprobantes (validar PDF)

### Paneles 🔴 Falta:
Pacientes 360, Panel Cliente, Panel doctora, Chat central, Notificaciones, Turnos config

---

## PLAN DE TRABAJO (14 pasos en orden)

1. Flujo clínico completo (agenda→atención→insumos)
2. Inventario (descuento auto por tratamiento)
3. Catálogo (validar)
4. Agenda (Calendar+Contacts+links)
5. Call Center (card contextual+AI asesor con Groq)
6. Llamadas Admin (bases+agentes)
7. Marketing (redes reales)
8. Ventas+Comisiones (etiquetas+sedes)
9. Comprobantes (PDF+QR)
10. Home+Notificaciones
11. Pacientes 360 (8 zonas)
12. Panel Cliente
13. Chat central+KronIA
14. Ciberseguridad

---

## REGLAS (12 post-1000 commits)

1. AUDITAR→PLANIFICAR→CONSTRUIR
2. Syntax check después de CADA edición
3. fetch con .catch + getElementById con null guard
4. UN marker FIN en server
5. Datos dinámicos no hardcoded
6. Preview antes de acciones masivas
7. Auditoría cada 50 commits
8. Ratio fix/feature < 0.5
9. CHECK constraints ANTES de codificar
10. Función compartida en 2+ lugares
11. SESSION LOG al cierre
12. Tabla nueva: id default + CHECK + created_at

---

## DATOS TÉCNICOS

- aos_pacientes: campos MAYÚSCULA → USAR RPCs no REST
- aos_ventas: fecha=date, estado_pago="PAGO COMPLETO"
- aos_agenda_citas: fecha_cita (no fecha)
- Horarios: aos_horarios_personal = fuente verdad
- RPCs: SECURITY DEFINER (anon key)
- RLS: Deshabilitado en todas aos_*
- Deploy: git push → Railway auto-deploy 1-2 min

---

## EQUIPO

César(admin), Wilmer/Ruvila/Mireya(enfermería), Carmen(ventas), Carolina/Pamela/Yessica(doctoras), Renato(mkt)
Sedes: San Isidro + Pueblo Libre | Email: info@zivital.pe

---

## PENDIENTES HEREDADOS

- DEUDA-2A: Card contextual asesor
- Fix buscador pacientes modal Agendar
- Panel atención doctoras
- Optimizar polling
- Turnos/horarios en config

---

## PARA INICIAR: Pegar este prompt y decir "SES-037 empezamos"
