-- BOOKING-V3.1 — channel/campaign/advisor attribution for public bookings.
-- Additive only: preserves existing booking, calendar, notification and call-center authority.
begin;

alter table public.aos_links_agenda add column if not exists source_channel text;
alter table public.aos_links_agenda add column if not exists campaign_code text;
alter table public.aos_links_agenda add column if not exists campaign_name text;

alter table public.aos_agenda_citas add column if not exists source_channel text;
alter table public.aos_agenda_citas add column if not exists source_campaign text;
alter table public.aos_agenda_citas add column if not exists source_link_token text;

create index if not exists aos_agenda_source_channel_idx on public.aos_agenda_citas(source_channel,ts_creado desc);
create index if not exists aos_agenda_source_campaign_idx on public.aos_agenda_citas(source_campaign,ts_creado desc) where source_campaign is not null;

create or replace function public.aos_booking_attribution_v1(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare l record; ch text; camp text;
begin
  if coalesce(trim(p_token),'') in ('','__permanent__') then
    return jsonb_build_object('source_channel','WEB','source_campaign',null,'advisor_code','ORGANICO','link_type','permanent');
  end if;
  select * into l from public.aos_links_agenda where token=p_token and expira_at>now();
  if not found then return jsonb_build_object('source_channel','UNKNOWN','advisor_code','ORGANICO'); end if;
  ch:=upper(coalesce(nullif(trim(l.source_channel),''),case when lower(coalesce(l.tipo,'')) in ('asesor','paciente_especifico') then 'ADVISOR_LINK' else 'LINK' end));
  camp:=nullif(trim(coalesce(l.campaign_code,l.campaign_name)), '');
  return jsonb_build_object('source_channel',ch,'source_campaign',camp,'advisor_code',coalesce(nullif(trim(l.asesor_codigo),''),'ORGANICO'),'link_type',l.tipo);
end;
$$;
revoke all on function public.aos_booking_attribution_v1(text) from public;
grant execute on function public.aos_booking_attribution_v1(text) to anon,authenticated,service_role;

create or replace view public.aos_booking_attribution_daily_v1 as
select (coalesce(ts_creado,ts_actualizado) at time zone 'America/Lima')::date as fecha,
       coalesce(nullif(source_channel,''),case when origen_cita='WEB-PUBLICA' then 'WEB' when origen_cita='AUTO-AGENDA' then 'ADVISOR_LINK' else coalesce(origen_cita,'OTHER') end) as source_channel,
       nullif(source_campaign,'') as source_campaign,
       coalesce(nullif(asesor,''),'ORGANICO') as asesor,
       count(*)::bigint as citas
from public.aos_agenda_citas
group by 1,2,3,4;

commit;
