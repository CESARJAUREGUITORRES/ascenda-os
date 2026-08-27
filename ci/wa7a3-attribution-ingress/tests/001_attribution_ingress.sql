\set ON_ERROR_STOP on

-- A normal inbound message binds to the existing canonical WA conversation projection.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at
) values (
  'wamid.wa7a3.db.1','INBOUND','51911111111','51999111222','pn-wa7a3','text','Hola','received','2026-08-27T12:00:00-05:00','2026-08-27T12:00:01-05:00'
);

-- The parser/runtime persists only explicit provenance as a deterministic event.
insert into public.aos_wa_events_v1(event_key,event_type,provider_message_id,status,payload)
values(
  'attribution:touchpoint:wamid.wa7a3.db.1','attribution.touchpoint','wamid.wa7a3.db.1','observed',
  jsonb_build_object(
    'evidence_version','WA_7A_3_V1','channel','WHATSAPP','provider','META_CLOUD_API','business_scope','pn-wa7a3',
    'provider_message_id','wamid.wa7a3.db.1','ctwa_clid','ctwa-db-1','source_id','ad-db-1','source_type','ad',
    'source_url','https://www.facebook.com/ads/db-1','ad_id','ad-db-1','provider_lead_id','provider-lead-db-1',
    'campaign_source','META_CTWA','headline','HIFU','body','Agenda','media_type','image','observed_at','2026-08-27T12:00:00-05:00'
  )
)
on conflict(event_key) do nothing;

-- Provider replay must not duplicate the acquisition touchpoint.
insert into public.aos_wa_events_v1(event_key,event_type,provider_message_id,status,payload)
select event_key,event_type,provider_message_id,status,payload
from public.aos_wa_events_v1
where event_key='attribution:touchpoint:wamid.wa7a3.db.1'
on conflict(event_key) do nothing;

do $$
declare
  v_count bigint;
  v_conv uuid;
  v_patient text;
  v_source text;
  v_ctwa text;
  v_ad text;
  v_cols integer;
begin
  select count(*) into v_count from public.aos_wa_events_v1 where event_key='attribution:touchpoint:wamid.wa7a3.db.1';
  if v_count<>1 then raise exception 'WA7A3_REPLAY_DUPLICATED_TOUCHPOINT'; end if;

  select conversation_id,canonical_patient_id,source_id,ctwa_clid,ad_id
  into v_conv,v_patient,v_source,v_ctwa,v_ad
  from public.aos_wa_attribution_touchpoints_v1
  where touchpoint_key='attribution:touchpoint:wamid.wa7a3.db.1';

  if v_conv is null then raise exception 'WA7A3_CONVERSATION_LINK_MISSING'; end if;
  if v_patient is not null then raise exception 'WA7A3_CANONICAL_IDENTITY_FABRICATED'; end if;
  if v_source<>'ad-db-1' or v_ctwa<>'ctwa-db-1' or v_ad<>'ad-db-1' then raise exception 'WA7A3_PROVENANCE_PROJECTION_MISMATCH'; end if;

  select count(*) into v_cols
  from information_schema.columns
  where table_schema='public' and table_name='aos_wa_attribution_touchpoints_v1'
    and lower(column_name) similar to '%(phone|bsuid|username|contact_number|alias_value)%';
  if v_cols<>0 then raise exception 'WA7A3_RAW_IDENTITY_LEAK'; end if;

  if has_table_privilege('anon','public.aos_wa_attribution_touchpoints_v1','SELECT') then raise exception 'WA7A3_ANON_VIEW_EXPOSED'; end if;
  if has_table_privilege('authenticated','public.aos_wa_attribution_touchpoints_v1','SELECT') then raise exception 'WA7A3_AUTH_VIEW_EXPOSED'; end if;
  if not has_table_privilege('service_role','public.aos_wa_attribution_touchpoints_v1','SELECT') then raise exception 'WA7A3_SERVICE_VIEW_MISSING'; end if;

  if has_table_privilege('service_role','public.aos_wa_events_v1','UPDATE') then raise exception 'WA7A3_EVENT_UPDATE_PRIVILEGE_OPEN'; end if;
  if has_table_privilege('service_role','public.aos_wa_events_v1','DELETE') then raise exception 'WA7A3_EVENT_DELETE_PRIVILEGE_OPEN'; end if;
  if has_table_privilege('service_role','public.aos_wa_events_v1','TRUNCATE') then raise exception 'WA7A3_EVENT_TRUNCATE_PRIVILEGE_OPEN'; end if;
end
$$;

-- Even an owner-level accidental row mutation is rejected for accepted provenance.
do $$
begin
  begin
    update public.aos_wa_events_v1 set status='tampered'
    where event_key='attribution:touchpoint:wamid.wa7a3.db.1';
    raise exception 'WA7A3_IMMUTABILITY_UPDATE_NOT_BLOCKED';
  exception when sqlstate '55000' then null;
  end;
  begin
    delete from public.aos_wa_events_v1
    where event_key='attribution:touchpoint:wamid.wa7a3.db.1';
    raise exception 'WA7A3_IMMUTABILITY_DELETE_NOT_BLOCKED';
  exception when sqlstate '55000' then null;
  end;
end
$$;

select 'WA7A3_ATTRIBUTION_INGRESS_PASS' as result;
