-- APP-PWA-V2 #517 — rollback governed Device Center panel registration.
-- Revoke assignment first so no user retains an unknown panel identifier.

update public.aos_usuarios
set paneles_acceso=array_remove(coalesce(paneles_acceso,'{}'::text[]),'devices-notifications'),
    updated_at=now()
where coalesce(paneles_acceso,'{}'::text[]) @> array['devices-notifications']::text[];

delete from public.aos_paneles_disponibles
where id='devices-notifications';
