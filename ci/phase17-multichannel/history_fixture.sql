\set ON_ERROR_STOP on
create table if not exists public.aos_plantillas_whatsapp(id uuid primary key default gen_random_uuid());
create table if not exists public.aos_whatsapp_mensajes(id uuid primary key default gen_random_uuid());
grant select,insert,update,delete on public.aos_plantillas_whatsapp to anon,authenticated;
grant select,insert,update,delete on public.aos_whatsapp_mensajes to anon,authenticated;
