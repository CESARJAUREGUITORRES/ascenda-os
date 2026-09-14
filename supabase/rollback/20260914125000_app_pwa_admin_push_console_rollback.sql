begin;
update public.aos_paneles_disponibles set categoria='asesor', descripcion='Registro de dispositivos, capacidades PWA y preferencias de notificación por usuario.' where id='devices-notifications';
drop function if exists public.aos_push_admin_targets_v1(jsonb);
drop function if exists public.aos_push_admin_overview_v1(jsonb);
commit;
