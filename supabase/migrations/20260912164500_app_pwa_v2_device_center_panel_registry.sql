-- APP-PWA-V2 #517 — register Device & Notification Center in governed Team panel authority.
-- Additive catalog row only. Does NOT grant the panel to any user.

insert into public.aos_paneles_disponibles(id,nombre,icono,categoria,descripcion,orden)
values (
  'devices-notifications',
  'Dispositivos y avisos',
  '🔔',
  'asesor',
  'Registro de dispositivos, capacidades PWA y preferencias de notificación por usuario.',
  39
)
on conflict (id) do update
set nombre=excluded.nombre,
    icono=excluded.icono,
    categoria=excluded.categoria,
    descripcion=excluded.descripcion,
    orden=excluded.orden;
