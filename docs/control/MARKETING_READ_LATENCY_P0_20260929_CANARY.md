# Canary · Marketing Read Latency P0

- Abrir Marketing Septiembre 2026 con sesión admin 2FA.
- Confirmar que KPIs/embudo/campañas/anuncios/ventas aparecen sin esperar la cadena profunda completa.
- Abrir `Ver Leads`; debe resolver datos reales del rango por `/api/marketing/rpc`.
- Abrir `Citas Web`; con 0 reservas landing debe terminar rápido en estado vacío, no quedar cargando.
- En paralelo, abrir/usar landing booking; múltiples solicitudes `/days` equivalentes deben coalescerse.
- Revisar Railway/Supabase: sin ráfaga nueva de 57014/504 bajo uso normal.
- Confirmar que `/availability` y `/book` siguen siendo tiempo real y que un booking invalida el cache de días.
