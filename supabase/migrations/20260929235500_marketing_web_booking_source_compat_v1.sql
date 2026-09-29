-- Web Booking Lineage V1 source-channel compatibility.
-- Preserve the certified booking channel used by existing WEB / ADVISOR_LINK counters.
-- LANDING is recorded in the dedicated acquisition ledger and source_landing_* fields.

begin;

create or replace function public.aos_agendar_publica_landing_v1(
  p_landing_token text,
  p_idempotency_key text,
  p_nombre text,
  p_apellido text,
  p_telefono text,
  p_treatment_id uuid,
  p_fecha date,
  p_hora text,
  p_sede text,
  p_profesional_id text default null,
  p_dni text default '',
  p_email text default '',
  p_nota text default '',
  p_tipo_cita text default 'CONSULTA NUEVA',
  p_utm_source text default null,
  p_utm_medium text default null,
  p_utm_campaign text default null,
  p_utm_content text default null,
  p_utm_term text default null,
  p_referrer_url text default null,
  p_client_event_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare r public.aos_landing_registry%rowtype; prior record; booked jsonb; aid text; num text; btoken text; canonical_treatment text;
begin
  if coalesce(length(trim(p_landing_token)),0)<20 then return jsonb_build_object('ok',false,'error','LANDING_INVALID'); end if;
  if coalesce(length(trim(p_idempotency_key)),0)>128 then return jsonb_build_object('ok',false,'error','IDEMPOTENCY_KEY_TOO_LONG'); end if;
  perform pg_advisory_xact_lock(hashtextextended('landing-booking:'||trim(p_landing_token)||':'||coalesce(nullif(trim(p_idempotency_key),''),regexp_replace(coalesce(p_telefono,''),'[^0-9]','','g')||':'||p_fecha::text||':'||p_hora),0));
  select * into r from public.aos_landing_registry where token=trim(p_landing_token) and activo=true limit 1;
  if not found then return jsonb_build_object('ok',false,'error','LANDING_INVALID'); end if;
  if r.treatment_id is not null and r.treatment_id<>p_treatment_id then return jsonb_build_object('ok',false,'error','LANDING_TREATMENT_MISMATCH'); end if;

  if coalesce(trim(p_idempotency_key),'')<>'' then
    select l.agenda_id,a.fecha_cita,a.hora_cita,a.sede,a.tratamiento,a.source_channel into prior
    from public.aos_landing_booking_attribution l
    left join public.aos_agenda_citas a on a.id=l.agenda_id
    where l.landing_id=r.id and l.idempotency_key=trim(p_idempotency_key)
    limit 1;
    if found then
      return jsonb_build_object(
        'ok',true,'status','BOOKED','idempotent_replay',true,'agenda_id',prior.agenda_id,'fecha',prior.fecha_cita,'hora',prior.hora_cita,'sede',prior.sede,
        'treatment',prior.tratamiento,'source_channel',prior.source_channel,'acquisition_channel','LANDING','landing_code',r.landing_code,'landing_name',r.nombre,
        'platform',r.plataforma,'campaign_code',r.campaign_code,'campaign_name',r.campaign_name,'ad_code',r.ad_code,'ad_name',r.ad_name
      );
    end if;
  end if;

  btoken:=coalesce(nullif(trim(r.booking_token),''),'__permanent__');
  booked:=public.aos_agendar_publica_v2(btoken,p_nombre,p_apellido,p_telefono,p_treatment_id,p_fecha,p_hora,p_sede,p_profesional_id,p_dni,p_email,p_nota,p_tipo_cita);
  if coalesce((booked->>'ok')::boolean,false) is not true then return booked; end if;

  aid:=booked->>'agenda_id';
  num:=regexp_replace(coalesce(p_telefono,''),'[^0-9]','','g');
  canonical_treatment:=coalesce(nullif(booked->>'treatment',''),r.tratamiento);

  update public.aos_agenda_citas set
    source_campaign=coalesce(nullif(r.campaign_code,''),nullif(r.campaign_name,''),source_campaign),
    source_landing_id=r.id,
    source_landing_code=r.landing_code,
    source_platform=r.plataforma,
    source_ad=coalesce(nullif(r.ad_code,''),nullif(r.ad_name,''))
  where id=aid;

  insert into public.aos_landing_booking_attribution(
    agenda_id,landing_id,idempotency_key,numero_limpio,landing_code,landing_name,landing_url,plataforma,campaign_code,campaign_name,ad_code,ad_name,treatment_id,tratamiento,advisor_code,
    utm_source,utm_medium,utm_campaign,utm_content,utm_term,referrer_url,client_event_id,metadata
  ) values(
    aid,r.id,nullif(trim(p_idempotency_key),''),num,r.landing_code,r.nombre,r.landing_url,r.plataforma,r.campaign_code,r.campaign_name,r.ad_code,r.ad_name,p_treatment_id,canonical_treatment,booked->>'advisor_code',
    nullif(trim(p_utm_source),''),nullif(trim(p_utm_medium),''),nullif(trim(p_utm_campaign),''),nullif(trim(p_utm_content),''),nullif(trim(p_utm_term),''),nullif(trim(p_referrer_url),''),nullif(trim(p_client_event_id),''),
    jsonb_build_object('booking_source','LANDING_V1','certified_source_channel',booked->>'source_channel')
  ) on conflict (agenda_id) do nothing;

  return booked || jsonb_build_object(
    'acquisition_channel','LANDING','landing_code',r.landing_code,'landing_name',r.nombre,'platform',r.plataforma,
    'campaign_code',r.campaign_code,'campaign_name',r.campaign_name,'ad_code',r.ad_code,'ad_name',r.ad_name
  );
end;
$$;

select pg_notify('pgrst','reload schema');
commit;
