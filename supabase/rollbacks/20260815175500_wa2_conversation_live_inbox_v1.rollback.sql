-- WA-2 recovery / rollback.
-- Fail closed and preserve any conversation evidence already captured.
-- Runtime rollback is paired with reverting Railway startCommand to server-f4.js.

begin;

drop trigger if exists trg_aos_wa2_bind_conversation_v1 on public.aos_wa_messages_v1;
drop function if exists public.aos_wa2_bind_conversation_v1();

update public.aos_usuarios
set paneles_acceso = array_remove(coalesce(paneles_acceso,'{}'::text[]),'admin-whatsapp'),
    updated_at = now()
where 'admin-whatsapp' = any(coalesce(paneles_acceso,'{}'::text[]));

delete from public.aos_paneles_disponibles where id='admin-whatsapp';

-- Keep projection tables and message links private for audit/recovery; never reopen browser access.
alter table if exists public.aos_wa_conversations_v1 enable row level security;
alter table if exists public.aos_wa_conversations_v1 force row level security;
revoke all on table public.aos_wa_conversations_v1 from public, anon, authenticated;

alter table if exists public.aos_wa_conversation_events_v1 enable row level security;
alter table if exists public.aos_wa_conversation_events_v1 force row level security;
revoke all on table public.aos_wa_conversation_events_v1 from public, anon, authenticated;

commit;
