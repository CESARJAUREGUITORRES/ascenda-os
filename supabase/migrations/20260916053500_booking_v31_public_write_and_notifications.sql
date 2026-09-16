-- BOOKING-V3.1 — wrap current public booking V2 to stamp attribution after the authoritative write.
-- Existing signature is preserved; implementation below mirrors V2 authority plus additive source fields.
begin;

create or replace function public.aos_booking_apply_attribution_v1(p_agenda_id text,p_token text)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare a jsonb; ch text; camp text;
begin
  a:=public.aos_booking_attribution_v1(p_token);
  ch:=coalesce(a->>'source_channel','WEB'); camp:=nullif(a->>'source_campaign','');
  update public.aos_agenda_citas
     set source_channel=ch, source_campaign=camp,
         source_link_token=case when coalesce(trim(p_token),'') in ('','__permanent__') then null else p_token end
   where id=p_agenda_id;
  return a;
end;
$$;
revoke all on function public.aos_booking_apply_attribution_v1(text,text) from public;
grant execute on function public.aos_booking_apply_attribution_v1(text,text) to anon,authenticated,service_role;

-- Extend notification formatter without introducing a second notification stream.
create or replace function public.aos_booking_source_label_v1(p_channel text,p_campaign text,p_advisor text)
returns text language sql immutable as $$
 select case upper(coalesce($1,''))
  when 'WEB' then 'Web'
  when 'EMAIL_MARKETING' then 'Email marketing'||case when coalesce($2,'')<>'' then ' · '||$2 else '' end
  when 'ADVISOR_LINK' then 'Enlace de asesor'||case when coalesce($3,'') not in ('','ORGANICO') then ' · '||$3 else '' end
  when 'WHATSAPP' then 'WhatsApp'||case when coalesce($2,'')<>'' then ' · '||$2 else '' end
  when 'CALL_CENTER' then 'Call Center'
  when 'MANUAL' then 'Manual'
  else initcap(replace(coalesce(nullif($1,''),'Otro'),'_',' ')) end;
$$;

-- Backfill historical public origin so counters are immediately useful; no appointment semantics change.
update public.aos_agenda_citas
set source_channel=case when origen_cita='WEB-PUBLICA' then 'WEB' when origen_cita='AUTO-AGENDA' then 'ADVISOR_LINK' else source_channel end
where source_channel is null and origen_cita in ('WEB-PUBLICA','AUTO-AGENDA');

commit;
