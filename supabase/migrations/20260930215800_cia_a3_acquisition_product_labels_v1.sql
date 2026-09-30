begin;

-- CIA A3.1 · product-facing Acquisition terminology.
-- Labels only; field keys, operators, resolver semantics and data remain unchanged.

update public.aos_audience_filter_registry
set label=case field_key
  when 'acquisition.channel' then 'Canal de adquisición'
  when 'acquisition.landing_code' then 'Código de landing'
  when 'acquisition.campaign_code' then 'Código de campaña'
  when 'acquisition.ad_code' then 'Código de anuncio'
  when 'acquisition.web_booking_count' then 'Número de reservas web'
  else label
end
where field_key in (
  'acquisition.channel',
  'acquisition.landing_code',
  'acquisition.campaign_code',
  'acquisition.ad_code',
  'acquisition.web_booking_count'
);

select pg_notify('pgrst','reload schema');

commit;
