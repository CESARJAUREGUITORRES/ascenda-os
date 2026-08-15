-- Message that exists before WA-2 cutover; WA-2 migration must backfill it.
insert into public.aos_wa_messages_v1(
  provider_message_id,direction,from_number,to_number,phone_number_id,contact_name,
  message_type,message_body,status,campaign_source,ad_id,lead_id,provider_timestamp,received_at
) values (
  'wamid.synthetic.preexisting','INBOUND','+51 999-111-222',null,'phone-A','Paciente Sintético',
  'text','Hola, quiero información','received','META_SYNTHETIC','ad-synth-1','lead-synth-1',
  '2026-08-15T12:00:00-05:00','2026-08-15T12:00:00-05:00'
);
