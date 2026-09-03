\set ON_ERROR_STOP on

-- Fixed synthetic identities only.
delete from public.aos_booking_operations_v2 where idempotency_key like 'wa-l6-%';
delete from public.aos_ventas where venta_id like 'L6-SALE-%';
delete from public.aos_agenda_citas where id like 'L6-APT-%';
delete from public.aos_wa_events_v1 where provider_message_id like 'wamid.l6.db.%';
delete from public.aos_wa_messages_v1 where provider_message_id like 'wamid.l6.db.%';
delete from public.aos_wa_conversations_v1 where conversation_key like 'pn-l6:%';
delete from public.aos_wa4_campaign_context_map_v1 where ad_id like 'ad-l6-%';

-- Mapping authority: explicit ad + active service + evidence required, 2FA admin required.
do $$
declare v_tid uuid; r jsonb; n integer;
begin
  select id into v_tid from public.aos_catalogo_servicios
  where upper(coalesce(estado,'ACTIVO'))='ACTIVO' and upper(coalesce(tipo,'SERVICIO'))='SERVICIO'
  order by id limit 1;
  if v_tid is null then raise exception 'WA_L6_NO_ACTIVE_TREATMENT_FIXTURE'; end if;

  r:=public.aos_wa_l6_campaign_context_upsert_v1(
    'bad-token',
    jsonb_build_object('ad_id','ad-l6-1','campaign_id','campaign-l6-1','treatment_entity_id',v_tid,'booking_goal','BOOKING','evidence_ref','TEST:SIGNED_META_EVIDENCE')
  );
  if coalesce((r->>'ok')::boolean,false) or r->>'error'<>'WA_L6_UNAUTHORIZED' then raise exception 'WA_L6_UNAUTHORIZED_FAIL:%',r; end if;

  r:=public.aos_wa_l6_campaign_context_upsert_v1(
    'admin-token-111111111111111111111111111111111111',
    jsonb_build_object('ad_id','ad-l6-1','campaign_id','campaign-l6-1','treatment_entity_id',v_tid,'booking_goal','BOOKING','evidence_ref','TEST:SIGNED_META_EVIDENCE')
  );
  if coalesce((r->>'ok')::boolean,false) is not true then raise exception 'WA_L6_MAPPING_SAVE_FAIL:%',r; end if;
  select count(*) into n from public.aos_wa4_campaign_context_map_v1 where ad_id='ad-l6-1' and campaign_id='campaign-l6-1' and treatment_entity_id=v_tid and active;
  if n<>1 then raise exception 'WA_L6_MAPPING_NOT_PERSISTED:%',n; end if;
  select count(*) into n from public.aos_wa_l6_campaign_context_audit_v1 where ad_id='ad-l6-1' and operation='CREATE';
  if n<>1 then raise exception 'WA_L6_MAPPING_AUDIT_MISSING:%',n; end if;

  r:=public.aos_wa_l6_campaign_context_upsert_v1(
    'admin-token-111111111111111111111111111111111111',
    jsonb_build_object('ad_id','ad-l6-bad','campaign_id','campaign-x','booking_goal','BOOKING','evidence_ref','TEST:X')
  );
  if r->>'error'<>'WA_L6_TREATMENT_ID_REQUIRED' then raise exception 'WA_L6_TREATMENT_REQUIRED_FAIL:%',r; end if;
end
$$;

-- Audit must be append-only.
do $$ begin
  begin
    update public.aos_wa_l6_campaign_context_audit_v1 set evidence_ref='MUTATED' where ad_id='ad-l6-1';
    raise exception 'WA_L6_AUDIT_UPDATE_UNEXPECTEDLY_ALLOWED';
  exception when sqlstate '55000' then null; end;
end $$;

-- Explicit CTWA touchpoint and exact conversation binding.
insert into public.aos_wa_conversations_v1(
  id,conversation_key,contact_number,contact_name,phone_number_id,state,campaign_source,ad_id,lead_id,opened_at,updated_at
) values (
  '77777777-7777-4777-8777-777777777761'::uuid,'pn-l6:51977777771','51977777771','L6 TEST','pn-l6','AI_COPILOT','META_CTWA','ad-l6-1','lead-l6-1',now(),now()
) on conflict(id) do update set conversation_key=excluded.conversation_key,state='AI_COPILOT',campaign_source='META_CTWA',ad_id='ad-l6-1',lead_id='lead-l6-1';

-- The fixture binds through the certified WA7A0/WA2 authority by presenting the
-- already-existing canonical conversation_id; the trigger validates existence and
-- registers the presented phone alias instead of guessing a parallel conversation.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at,conversation_id
) values (
  'wamid.l6.db.1','INBOUND','51977777771','519999111222','pn-l6','text','Hola','received',now(),now(),
  '77777777-7777-4777-8777-777777777761'::uuid
);

insert into public.aos_wa_events_v1(event_key,event_type,provider_message_id,status,payload)
values(
  'attribution:touchpoint:wamid.l6.db.1','attribution.touchpoint','wamid.l6.db.1','observed',
  jsonb_build_object(
    'evidence_version','WA_L6_V1','channel','WHATSAPP','provider','META_CLOUD_API','business_scope','pn-l6',
    'provider_message_id','wamid.l6.db.1','ctwa_clid','clid-l6-1','source_id','ad-l6-1','source_type','ad',
    'source_url','https://www.facebook.com/ads/l6','ad_id','ad-l6-1','campaign_id','campaign-l6-1','adset_id','adset-l6-1',
    'provider_lead_id','lead-l6-1','campaign_source','META_CTWA','observed_at',now()::text
  )
);

-- A second conversation with the same phone-like name but NO provider evidence must remain un-attributed.
insert into public.aos_wa_conversations_v1(
  id,conversation_key,contact_number,contact_name,phone_number_id,state,opened_at,updated_at
) values (
  '77777777-7777-4777-8777-777777777762'::uuid,'pn-l6:51977777772','51977777772','L6 TEST','pn-l6','AI_COPILOT',now(),now()
) on conflict(id) do nothing;

-- Strong booking chain. No phone/name join participates in the view.
do $$
declare v_tid uuid; v_name text;
begin
  select treatment_entity_id into v_tid from public.aos_wa4_campaign_context_map_v1 where ad_id='ad-l6-1';
  select nombre into v_name from public.aos_catalogo_servicios where id=v_tid;

  -- Fixture-only transaction-local setup, matching existing WA CI fixtures. This does
  -- not alter or disable trg_001_aos_wa4_governed_booking_v1; production direct writes
  -- remain blocked. The behavior under test is the downstream L6 strong-key stitch.
  perform set_config('aos.wa4_governed_booking_write','1',true);
  insert into public.aos_agenda_citas(
    id,fecha_cita,tratamiento,tipo_cita,sede,numero,nombre,apellido,estado_cita,venta_id_match,
    ts_creado,ts_actualizado,hora_cita,etiqueta_campana,origen_cita,numero_limpio,origen
  ) values (
    'L6-APT-1',current_date,v_name,'CONSULTA NUEVA','SAN ISIDRO','51977777771','L6','TEST','ASISTIO','L6-SALE-1',
    now(),now(),'10:00','META_CTWA','WHATSAPP','51977777771','WHATSAPP_META'
  );

  insert into public.aos_booking_operations_v2(
    id,idempotency_key,request_hash,operation_type,channel,actor_id,conversation_id,appointment_id,treatment_id,
    professional_ref,site,appointment_date,appointment_time,identity_state,campaign_source,ad_id,lead_id,status,response,created_at
  ) values (
    '88888888-8888-4888-8888-888888888861'::uuid,'wa-l6-book-00000001','hash-l6-book','BOOK','WHATSAPP',
    '11111111-1111-4111-8111-111111111111'::uuid,'77777777-7777-4777-8777-777777777761'::uuid,'L6-APT-1',v_tid,
    'WA4C-DOC','SAN ISIDRO',current_date,'10:00'::time,'UNRESOLVED','META_CTWA','ad-l6-1','lead-l6-1','BOOKED','{}'::jsonb,now()-interval '1 minute'
  );
  insert into public.aos_booking_operations_v2(
    id,idempotency_key,request_hash,operation_type,channel,actor_id,conversation_id,appointment_id,treatment_id,
    professional_ref,site,appointment_date,appointment_time,identity_state,campaign_source,ad_id,lead_id,status,response,created_at
  ) values (
    '88888888-8888-4888-8888-888888888862'::uuid,'wa-l6-rebook-000001','hash-l6-rebook','REBOOK','WHATSAPP',
    '11111111-1111-4111-8111-111111111111'::uuid,'77777777-7777-4777-8777-777777777761'::uuid,'L6-APT-1',v_tid,
    'WA4C-DOC','SAN ISIDRO',current_date,'10:30'::time,'UNRESOLVED','META_CTWA','ad-l6-1','lead-l6-1','REBOOKED','{}'::jsonb,now()
  );
end
$$;

insert into public.aos_ventas(venta_id,fecha,monto,moneda)
values('L6-SALE-1',current_date,899.00,'PEN');

-- Exact chain assertions.
do $$ declare r record; n integer; begin
  select * into r from public.aos_wa_l6_attribution_journey_v1
  where conversation_id='77777777-7777-4777-8777-777777777761'::uuid and appointment_id='L6-APT-1';
  if r.touchpoint_ad_id<>'ad-l6-1' or r.effective_campaign_id<>'campaign-l6-1' then raise exception 'WA_L6_PROVIDER_CHAIN_FAIL'; end if;
  if r.campaign_resolution_status<>'PROVIDER_EVIDENCE' then raise exception 'WA_L6_CAMPAIGN_SOURCE_FAIL:%',r.campaign_resolution_status; end if;
  if r.book_count<>1 or r.rebook_count<>1 then raise exception 'WA_L6_BOOK_REBOOK_CHAIN_FAIL:%/%',r.book_count,r.rebook_count; end if;
  if r.attended is not true or r.sale_link_venta_id<>'L6-SALE-1' or r.revenue_amount<>899.00 then raise exception 'WA_L6_OUTCOME_CHAIN_FAIL'; end if;
  if r.attribution_chain_status<>'EXPLICIT_CHAIN_COMPLETE' then raise exception 'WA_L6_CHAIN_STATUS_FAIL:%',r.attribution_chain_status; end if;
  if r.booking_ad_matches_touchpoint is not true then raise exception 'WA_L6_AD_PARITY_FAIL'; end if;

  select count(*) into n from public.aos_wa_l6_conversation_acquisition_v1
  where conversation_id='77777777-7777-4777-8777-777777777762'::uuid and acquisition_class='NO_PROVIDER_ATTRIBUTION' and touchpoint_id is null;
  if n<>1 then raise exception 'WA_L6_UNATTRIBUTED_SEPARATION_FAIL:%',n; end if;
end $$;

-- Multiple provider touchpoints remain explicit and fail closed for single-touch revenue attribution.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,message_type,message_body,status,provider_timestamp,received_at,conversation_id
) values (
  'wamid.l6.db.2','INBOUND','51977777771','519999111222','pn-l6','text','Segundo click','received',now(),now(),
  '77777777-7777-4777-8777-777777777761'::uuid
);
insert into public.aos_wa_events_v1(event_key,event_type,provider_message_id,status,payload)
values(
  'attribution:touchpoint:wamid.l6.db.2','attribution.touchpoint','wamid.l6.db.2','observed',
  jsonb_build_object('evidence_version','WA_L6_V1','channel','WHATSAPP','provider','META_CLOUD_API','business_scope','pn-l6','provider_message_id','wamid.l6.db.2','ctwa_clid','clid-l6-2','source_id','ad-l6-2','source_type','ad','ad_id','ad-l6-2','observed_at',now()::text)
);

do $$ declare n integer; begin
  select count(*) into n from public.aos_wa_l6_attribution_journey_v1
  where conversation_id='77777777-7777-4777-8777-777777777761'::uuid and appointment_id='L6-APT-1' and attribution_chain_status='MULTIPLE_TOUCHPOINTS_REVIEW';
  if n<>2 then raise exception 'WA_L6_MULTITOUCH_FAIL:%',n; end if;
end $$;

select 'WA_L6_META_ATTRIBUTION_CONTRACT_PASS' as result;
