-- F17 P0: compatibility-preserving legacy WhatsApp ACL hardening.
-- Observed current browser consumer needs SELECT on aos_plantillas_whatsapp.
-- Remove mutation/configuration privileges only; SELECT migration follows gateway cutover.

begin;

revoke insert, update, delete, truncate, references, trigger
  on table public.aos_plantillas_whatsapp
  from anon, authenticated;

-- Explicitly preserve the observed read-only compatibility contract.
grant select on table public.aos_plantillas_whatsapp to anon, authenticated;

-- aos_whatsapp_mensajes remains SELECT-only in this P0 migration.
-- No additional privilege is granted here.

commit;