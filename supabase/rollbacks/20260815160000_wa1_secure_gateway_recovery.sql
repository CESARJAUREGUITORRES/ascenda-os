-- WA-1 recovery is intentionally fail-closed.
-- Preserve captured WA evidence; disable all non-service access and never reopen legacy anon writes.

alter table if exists public.aos_wa_messages_v1 enable row level security;
alter table if exists public.aos_wa_messages_v1 force row level security;
revoke all on table public.aos_wa_messages_v1 from public, anon, authenticated;

alter table if exists public.aos_wa_events_v1 enable row level security;
alter table if exists public.aos_wa_events_v1 force row level security;
revoke all on table public.aos_wa_events_v1 from public, anon, authenticated;

revoke insert, update, delete, truncate, references, trigger on table public.aos_whatsapp_mensajes from anon, authenticated;

alter table if exists public.aos_meta_config enable row level security;
alter table if exists public.aos_meta_config force row level security;
revoke all on table public.aos_meta_config from public, anon, authenticated;

-- Runtime recovery: disable outbound by removing/invalidating WHATSAPP_ACCESS_TOKEN or keeping WA_CANARY_MODE=true.
-- Inbound must remain signature-validating; do not roll back to the legacy unsigned /webhook path.
-- Credential stores remain closed during recovery; a rollback must never re-expose Meta secrets to clients.
