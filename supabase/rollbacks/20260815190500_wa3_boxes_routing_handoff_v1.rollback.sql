-- ASCENDA Conversations — WA-3 recovery / rollback.
-- Fail-closed: disable routing and outbound, preserve evidence tables.

begin;

update public.aos_wa_routing_control_v1
set auto_routing_enabled=false,human_send_enabled=false,ai_send_enabled=false,updated_at=now()
where id=1;

drop trigger if exists trg_aos_wa3_auto_route_new_conversation_v1 on public.aos_wa_conversations_v1;

-- Any live owner is released into a non-sending state. Historical rows/events remain.
update public.aos_wa_assignments_v1
set state='RELEASED',released_at=coalesce(released_at,now()),terminal_reason=coalesce(terminal_reason,'WA3_ROLLBACK'),updated_at=now()
where state in ('QUEUED','ACTIVE');

update public.aos_wa_conversations_v1
set owner_user_id=null,
    state=case when state in ('HUMAN_ACTIVE','AI_COPILOT') then 'HUMAN_REQUESTED' else state end,
    ownership_version=ownership_version+1,
    updated_at=now()
where owner_user_id is not null or state in ('HUMAN_ACTIVE','AI_COPILOT');

-- Explicit agent permission is removed on rollback. Admin WA-2 permission is untouched.
update public.aos_usuarios
set paneles_acceso=array_remove(coalesce(paneles_acceso,'{}'::text[]),'whatsapp-agent'),updated_at=now()
where 'whatsapp-agent'=any(coalesce(paneles_acceso,'{}'::text[]));
delete from public.aos_paneles_disponibles where id='whatsapp-agent';

revoke all on function public.aos_wa3_actor_v1(text) from anon,authenticated;
revoke all on function public.aos_wa3_human_send_authorize_v1(text,uuid) from anon,authenticated;

drop function if exists public.aos_wa3_auto_route_new_conversation_v1();
drop function if exists public.aos_wa3_human_send_authorize_v1(text,uuid);
drop function if exists public.aos_wa3_admin_set_control_v1(uuid,boolean,boolean);
drop function if exists public.aos_wa3_request_handoff_v1(uuid,text);
drop function if exists public.aos_wa3_set_mode_v1(uuid,uuid,text);
drop function if exists public.aos_wa3_release_v1(uuid,uuid,text);
drop function if exists public.aos_wa3_claim_next_v1(uuid,uuid);
drop function if exists public.aos_wa3_route_v1(uuid,uuid,uuid,uuid,text);
drop function if exists public.aos_wa3_box_member_set_v1(uuid,uuid,uuid,boolean,integer,integer);
drop function if exists public.aos_wa3_box_upsert_v1(uuid,uuid,text,text,text,text,boolean,integer);
drop function if exists public.aos_wa3_actor_v1(text);
drop function if exists public.aos_wa3_is_admin_v1(uuid);

-- Keep append-only guard and all WA-3 evidence tables/columns for forensic recovery.

commit;
