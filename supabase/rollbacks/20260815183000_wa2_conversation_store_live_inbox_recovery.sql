-- WA-2 recovery: disable automation/client RPC surface without reopening private data.
begin;

drop trigger if exists trg_aos_wa_bind_conversation_v1 on public.aos_wa_messages_v1;
drop trigger if exists trg_aos_wa_rollup_conversation_v1 on public.aos_wa_messages_v1;

drop function if exists public.aos_wa_bind_conversation_v1();
drop function if exists public.aos_wa_rollup_conversation_v1();

revoke all on function public.aos_wa_inbox_v1(text,text,text,integer,timestamptz) from public,anon,authenticated;
revoke all on function public.aos_wa_conversation_v1(text,uuid,integer) from public,anon,authenticated;
revoke all on function public.aos_wa_mark_inbox_read_v1(text,uuid) from public,anon,authenticated;
revoke all on function public.aos_wa_close_conversation_v1(text,uuid) from public,anon,authenticated;

-- Preserve canonical history and keep it fail-closed.
alter table public.aos_wa_conversations_v1 enable row level security;
alter table public.aos_wa_conversations_v1 force row level security;
alter table public.aos_wa_conversation_events_v1 enable row level security;
alter table public.aos_wa_conversation_events_v1 force row level security;
revoke all on table public.aos_wa_conversations_v1 from public,anon,authenticated;
revoke all on table public.aos_wa_conversation_events_v1 from public,anon,authenticated;

comment on table public.aos_wa_conversations_v1 is 'WA-2 canonical history retained after fail-closed recovery; client RPC surface disabled.';
commit;
