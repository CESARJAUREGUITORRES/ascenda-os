-- BOOKING-V3.1 — attribution helpers and source-aware existing notification formatter.
begin;
create or replace function public.aos_booking_apply_attribution_v1(p_agenda_id text,p_token text)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare a jsonb; ch text; camp text; begin a:=public.aos_booking_attribution_v1(p_token); ch:=coalesce(a->>'source_channel','WEB'); camp:=nullif(a->>'source_campaign',''); update public.aos_agenda_citas set source_channel=ch,source_campaign=camp,source_link_token=case when coalesce(trim(p_token),'') in ('','__permanent__') then null else p_token end where id=p_agenda_id; return a; end $$;
revoke all on function public.aos_booking_apply_attribution_v1(text,text) from public; grant execute on function public.aos_booking_apply_attribution_v1(text,text) to anon,authenticated,service_role;
create or replace function public.aos_booking_source_label_v1(p_channel text,p_campaign text,p_advisor text) returns text language sql immutable as $$ select case upper(coalesce($1,'')) when 'WEB' then 'Web' when 'EMAIL_MARKETING' then 'Email marketing'||case when coalesce($2,'')<>'' then ' · '||$2 else '' end when 'ADVISOR_LINK' then 'Enlace de asesor'||case when coalesce($3,'') not in ('','ORGANICO') then ' · '||$3 else '' end when 'WHATSAPP' then 'WhatsApp'||case when coalesce($2,'')<>'' then ' · '||$2 else '' end when 'CALL_CENTER' then 'Call Center' when 'MANUAL' then 'Manual' else initcap(replace(coalesce(nullif($1,''),'Otro'),'_',' ')) end $$;

-- Wrap the existing formatter so appointment notifications expose attribution in title/body while all other events preserve their prior output.
create or replace function public.aos_notification_format_booking_v31(p_event_type text,p_metadata jsonb)
returns jsonb language plpgsql stable security definer set search_path='public','pg_temp' as $$
declare e text:=upper(trim(coalesce(p_event_type,''))); m jsonb:=coalesce(p_metadata,'{}'::jsonb); src text:=coalesce(m->>'source_label',''); patient text:=trim(coalesce(m->>'last_patient',m->>'patient','')); treatment text:=trim(coalesce(m->>'last_treatment',m->>'treatment','')); sede text:=trim(coalesce(m->>'last_sede',m->>'sede','')); dt text:=trim(concat_ws(' ',nullif(m->>'date',''),nullif(m->>'time',''))); title text; body text; begin
 if e='ADMIN_APPOINTMENT_DIGEST' and src<>'' then title:='Nueva cita · '||src; body:=trim(concat_ws(' · ',nullif(patient,''),nullif(treatment,''),nullif(dt,''),nullif(sede,''))); return jsonb_build_object('title',title,'body',body); end if;
 if e='APPOINTMENT_CREATED' and src<>'' then title:='Nueva cita agendada'; body:=trim(concat_ws(' · ',nullif(src,''),nullif(patient,''),nullif(dt,''),nullif(sede,''))); return jsonb_build_object('title',title,'body',body); end if;
 return public.aos_notification_format_v1(p_event_type,p_metadata);
end $$;

update public.aos_agenda_citas set source_channel=case when origen_cita='WEB-PUBLICA' then 'WEB' when origen_cita='AUTO-AGENDA' then 'ADVISOR_LINK' else source_channel end where source_channel is null and origen_cita in ('WEB-PUBLICA','AUTO-AGENDA');
commit;
