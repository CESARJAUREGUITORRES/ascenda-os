-- F17 final legacy WhatsApp ACL closure.
-- Preconditions: governed server gateway deployed and browser template consumer cut over.
-- Server-side service_role access remains intact; browser roles are fail-closed.

alter table public.aos_plantillas_whatsapp enable row level security;
alter table public.aos_plantillas_whatsapp force row level security;
alter table public.aos_whatsapp_mensajes enable row level security;
alter table public.aos_whatsapp_mensajes force row level security;

revoke all on table public.aos_plantillas_whatsapp from anon, authenticated;
revoke all on table public.aos_whatsapp_mensajes from anon, authenticated;

grant select, insert, update, delete on table public.aos_plantillas_whatsapp to service_role;
grant select, insert, update, delete on table public.aos_whatsapp_mensajes to service_role;

comment on table public.aos_plantillas_whatsapp is 'F17 legacy WhatsApp templates: server-authoritative service_role access only; browser direct access retired 2026-08-17.';
comment on table public.aos_whatsapp_mensajes is 'F17 legacy WhatsApp messages: server-authoritative service_role access only; browser direct access retired 2026-08-17.';
