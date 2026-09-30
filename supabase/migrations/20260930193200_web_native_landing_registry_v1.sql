begin;

-- Canonical registry row for the native Zi Vital public booking surface.
-- Paid landing pages may supply their own landing_token; the connector uses this
-- row only when no explicit campaign landing token is provided.

insert into public.aos_landing_registry(
  landing_code,nombre,landing_url,plataforma,campaign_code,campaign_name,activo,metadata
)
select
  'ZIVITAL-WEB-NATIVE',
  'Booking web Zi Vital',
  'https://zivital.pe/agendar/',
  'ORGANIC',
  'WEB-ORGANICO',
  'Web orgánico',
  true,
  jsonb_build_object('source','ASCENDA_CONNECT_BOOKING_V1','kind','PUBLIC_BOOKING')
where not exists (
  select 1 from public.aos_landing_registry
  where upper(trim(landing_code))='ZIVITAL-WEB-NATIVE'
);

update public.aos_landing_registry
set nombre='Booking web Zi Vital',
    landing_url='https://zivital.pe/agendar/',
    plataforma='ORGANIC',
    campaign_code='WEB-ORGANICO',
    campaign_name='Web orgánico',
    activo=true,
    metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object('source','ASCENDA_CONNECT_BOOKING_V1','kind','PUBLIC_BOOKING'),
    updated_at=now()
where upper(trim(landing_code))='ZIVITAL-WEB-NATIVE';

commit;
