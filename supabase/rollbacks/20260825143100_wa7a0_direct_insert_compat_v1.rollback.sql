begin;
do $$
begin
  if exists(select 1 from public.aos_wa_messages_v1 where from_user_id is not null or from_parent_user_id is not null or to_user_id is not null or to_parent_user_id is not null)
     or exists(select 1 from public.aos_wa_conversations_v1 where contact_address_type='BSUID' or contact_bsuid is not null or contact_parent_bsuid is not null)
     or exists(select 1 from public.aos_wa_channel_aliases_v1 where alias_type in ('BSUID','PARENT_BSUID'))
     or exists(select 1 from public.aos_wa_outbound_requests_v1 where recipient_kind='BSUID') then
    raise exception 'WA7A0_ROLLBACK_BLOCKED_BSUID_DATA' using errcode='55000';
  end if;
end
$$;
drop trigger if exists trg_aos_wa7a0_conversation_address_compat_v1 on public.aos_wa_conversations_v1;
drop function if exists public.aos_wa7a0_conversation_address_compat_v1();
commit;
