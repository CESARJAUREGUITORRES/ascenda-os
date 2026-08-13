create or replace function public.aos_cia_refresh_email_cache_v2()
returns jsonb language plpgsql security definer set search_path=public as $$
declare t timestamptz:=statement_timestamp();n integer;
begin
 if not pg_try_advisory_xact_lock(hashtext('cia_email_cache_v2')) then return jsonb_build_object('ok',false,'busy',true);end if;
 insert into public.aos_cia_email_runtime_cache_v2(contact_key,identity_confidence,sent_count,never_sent,last_sent_at,days_since_last,delivered_count,opened_count,clicked_count,bounced_count,last_event_at,cache_refreshed_at)
 select contact_key,identity_confidence,sent_count,never_sent,last_sent_at,days_since_last,delivered_count,opened_count,clicked_count,bounced_count,last_event_at,t from public.aos_cia_email_facts_v1
 on conflict(contact_key) do update set identity_confidence=excluded.identity_confidence,sent_count=excluded.sent_count,never_sent=excluded.never_sent,last_sent_at=excluded.last_sent_at,days_since_last=excluded.days_since_last,delivered_count=excluded.delivered_count,opened_count=excluded.opened_count,clicked_count=excluded.clicked_count,bounced_count=excluded.bounced_count,last_event_at=excluded.last_event_at,cache_refreshed_at=excluded.cache_refreshed_at;
 get diagnostics n=row_count;return jsonb_build_object('ok',true,'rows',n,'refreshed_at',t);
end;$$;
revoke all on function public.aos_cia_refresh_email_cache_v2() from public,anon,authenticated;
grant execute on function public.aos_cia_refresh_email_cache_v2() to service_role;
