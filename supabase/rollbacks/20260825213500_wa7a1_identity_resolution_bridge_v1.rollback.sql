-- WA-7A.1 rollback — derived bridge only. No canonical or WhatsApp business data is deleted.
begin;
drop function if exists public.aos_wa7a1_resolve_conversation_identity_v1(text,uuid);
drop view if exists public.aos_wa_identity_resolution_v1;
select pg_notify('pgrst','reload schema');
commit;
