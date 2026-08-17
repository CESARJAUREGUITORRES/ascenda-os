-- Emergency rollback for 20260817170500_f17_legacy_whatsapp_acl_final.sql.
-- Use only if post-cutover compatibility smoke fails.

grant select on table public.aos_plantillas_whatsapp to anon, authenticated;
grant select on table public.aos_whatsapp_mensajes to anon, authenticated;

alter table public.aos_plantillas_whatsapp no force row level security;
alter table public.aos_plantillas_whatsapp disable row level security;
alter table public.aos_whatsapp_mensajes no force row level security;
alter table public.aos_whatsapp_mensajes disable row level security;
