\set ON_ERROR_STOP on
do $$
declare r1 jsonb; r2 jsonb; rid uuid; i1 jsonb; i2 jsonb;
begin
  if has_table_privilege('anon','public.aos_plantillas_whatsapp','select') then raise exception 'legacy template anon select remains'; end if;
  if has_table_privilege('authenticated','public.aos_whatsapp_mensajes','select') then raise exception 'legacy messages authenticated select remains'; end if;
  if not has_function_privilege('service_role','public.aos_cia_channel_register_canary_recipient_v1(jsonb)','execute') then raise exception 'canary RPC service role missing'; end if;
  if has_function_privilege('anon','public.aos_cia_channel_register_canary_recipient_v1(jsonb)','execute') then raise exception 'canary RPC anon execute'; end if;
  perform public.aos_cia_channel_register_canary_recipient_v1(jsonb_build_object('channel','WHATSAPP','recipient_contact','999111222','allowlist_verified',true,'ttl_minutes',30));
  r1:=public.aos_cia_channel_prepare_send_v1(jsonb_build_object('channel','WHATSAPP','recipient_contact','999111222','purpose','HISTORY_REPLAY','message_class','TEXT','idempotency_key','f17-history-replay-0001','context',jsonb_build_object('canary',true)));
  r2:=public.aos_cia_channel_prepare_send_v1(jsonb_build_object('channel','WHATSAPP','recipient_contact','999111222','purpose','HISTORY_REPLAY','message_class','TEXT','idempotency_key','f17-history-replay-0001','context',jsonb_build_object('canary',true)));
  if coalesce((r1->>'dispatch_allowed')::boolean,false) is not true then raise exception 'canary not READY'; end if;
  if r1->>'request_id' <> r2->>'request_id' then raise exception 'prepare idempotency broken'; end if;
  rid:=(r1->>'request_id')::uuid;
  perform public.aos_cia_channel_mark_dispatch_v1(jsonb_build_object('request_id',rid,'outcome','ACCEPTED','provider','META_WHATSAPP','provider_message_id','wamid.history.replay'));
  perform public.aos_cia_channel_record_provider_event_v1(jsonb_build_object('channel','WHATSAPP','provider_message_id','wamid.history.replay','event_key','meta:history:delivered:1','event_type','DELIVERED','status','delivered'));
  perform public.aos_cia_channel_record_provider_event_v1(jsonb_build_object('channel','WHATSAPP','provider_message_id','wamid.history.replay','event_key','meta:history:delivered:1','event_type','DELIVERED','status','delivered'));
  if (select count(*) from public.aos_cia_channel_send_events_v1 where event_key='meta:history:delivered:1')<>1 then raise exception 'provider replay duplicate'; end if;
  i1:=public.aos_cia_channel_ingest_inbound_v1(jsonb_build_object('channel','WHATSAPP','provider_message_id','wamid.history.inbound','sender_contact','999111222','message_type','text'));
  i2:=public.aos_cia_channel_ingest_inbound_v1(jsonb_build_object('channel','WHATSAPP','provider_message_id','wamid.history.inbound','sender_contact','999111222','message_type','text'));
  if coalesce((i1->>'inserted')::boolean,false) is not true or coalesce((i2->>'inserted')::boolean,true) is not false then raise exception 'inbound replay idempotency broken'; end if;
  if to_regprocedure('public.aos_cia_channel_canary_control_v1(text,boolean,text)') is not null then raise exception 'superseded canary RPC rebuilt'; end if;
  if to_regprocedure('public.aos_cia_channel_record_inbound_v1(jsonb)') is not null then raise exception 'superseded inbound RPC rebuilt'; end if;
end $$;
select 'F17_HISTORY_REPLAY_PASS';
