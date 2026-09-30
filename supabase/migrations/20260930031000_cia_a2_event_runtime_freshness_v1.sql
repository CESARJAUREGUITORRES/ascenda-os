-- ASCENDA CIA · A2 Event-driven Runtime Freshness V1
-- Incremental per-contact refresh + one lightweight recount per source statement.
-- No polling, no bulk distribution, no outbound send.

begin;

create table if not exists public.aos_cia_runtime_freshness_v1 (
  singleton_id smallint primary key check(singleton_id=1),
  catalog_dirty boolean not null default true,
  dirty_since timestamptz,
  last_mark_at timestamptz,
  last_catalog_recount_at timestamptz,
  pending_marks bigint not null default 0,
  last_reason text,
  last_contact_key text,
  updated_at timestamptz not null default now()
);
insert into public.aos_cia_runtime_freshness_v1(singleton_id,catalog_dirty,dirty_since,updated_at)
values(1,true,now(),now()) on conflict(singleton_id) do nothing;
revoke all on table public.aos_cia_runtime_freshness_v1 from public,anon,authenticated;

create or replace function public.aos_cia_runtime_mark_dirty_v1(p_contact_key text,p_reason text)
returns void language plpgsql security definer set search_path to '' as $function$
begin
 insert into public.aos_cia_runtime_freshness_v1(singleton_id,catalog_dirty,dirty_since,last_mark_at,pending_marks,last_reason,last_contact_key,updated_at)
 values(1,true,statement_timestamp(),statement_timestamp(),1,left(coalesce(p_reason,'UNKNOWN'),120),left(coalesce(p_contact_key,''),40),statement_timestamp())
 on conflict(singleton_id) do update set
  catalog_dirty=true,
  dirty_since=coalesce(public.aos_cia_runtime_freshness_v1.dirty_since,excluded.dirty_since),
  last_mark_at=excluded.last_mark_at,
  pending_marks=public.aos_cia_runtime_freshness_v1.pending_marks+1,
  last_reason=excluded.last_reason,last_contact_key=excluded.last_contact_key,updated_at=excluded.updated_at;
end $function$;
revoke all on function public.aos_cia_runtime_mark_dirty_v1(text,text) from public,anon,authenticated;

create or replace function public.aos_cia_runtime_ensure_contact_v1(p_contact_key text)
returns text language plpgsql security definer set search_path to '' as $function$
declare k text:=public.aos_cia_normalize_contact_key_v1(p_contact_key);
begin
 if k is null then return null; end if;
 insert into public.aos_cia_contact_runtime_cache_v1(contact_key,cache_refreshed_at)
 values(k,statement_timestamp()) on conflict(contact_key) do update set cache_refreshed_at=excluded.cache_refreshed_at;
 return k;
end $function$;
revoke all on function public.aos_cia_runtime_ensure_contact_v1(text) from public,anon,authenticated;

create or replace function public.aos_cia_runtime_refresh_acquisition_one_v1(p_contact_key text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare k text:=public.aos_cia_normalize_contact_key_v1(p_contact_key); a record;
begin
 if k is null then return jsonb_build_object('ok',false,'error','INVALID_CONTACT_KEY'); end if;
 perform public.aos_cia_runtime_ensure_contact_v1(k);
 select * into a from public.aos_cia_acquisition_facts_v1 where contact_key=k;
 update public.aos_cia_contact_runtime_cache_v1 c set
  web_booking_count=coalesce(a.web_booking_count,0),first_web_booking_at=a.first_web_booking_at,last_web_booking_at=a.last_web_booking_at,
  latest_acquisition_channel=a.latest_acquisition_channel,latest_platform=a.latest_platform,latest_landing_code=a.latest_landing_code,
  latest_landing_name=a.latest_landing_name,latest_landing_url=a.latest_landing_url,latest_campaign_code=a.latest_campaign_code,
  latest_campaign_name=a.latest_campaign_name,latest_ad_code=a.latest_ad_code,latest_ad_name=a.latest_ad_name,
  latest_treatment_id=a.latest_treatment_id,latest_treatment=a.latest_treatment,latest_advisor_code=a.latest_advisor_code,
  latest_utm_source=a.latest_utm_source,latest_utm_medium=a.latest_utm_medium,latest_utm_campaign=a.latest_utm_campaign,
  latest_utm_content=a.latest_utm_content,latest_utm_term=a.latest_utm_term,latest_referrer_url=a.latest_referrer_url,
  latest_client_event_id=a.latest_client_event_id,acquisition_source_last_at=a.source_last_at,cache_refreshed_at=statement_timestamp()
 where c.contact_key=k;
 perform public.aos_cia_runtime_mark_dirty_v1(k,'ACQUISITION');
 return jsonb_build_object('ok',true,'contact_key',k,'web_booking_count',coalesce(a.web_booking_count,0));
end $function$;
revoke all on function public.aos_cia_runtime_refresh_acquisition_one_v1(text) from public,anon,authenticated;

create or replace function public.aos_cia_runtime_refresh_profile_one_v1(p_contact_key text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare k text:=public.aos_cia_normalize_contact_key_v1(p_contact_key); p record; v_found boolean:=false; valid_email boolean;
begin
 if k is null then return jsonb_build_object('ok',false,'error','INVALID_CONTACT_KEY'); end if;
 perform public.aos_cia_runtime_ensure_contact_v1(k);
 select nullif(btrim(x."Nombres"),'') names,nullif(btrim(x."Apellidos"),'') surnames,nullif(lower(btrim(x."Email")),'') email,
        nullif(btrim(x."ESTADO_PACIENTE"),'') patient_state,nullif(btrim(x."SEDE_PRINCIPAL"),'') branch,
        nullif(btrim(x.distrito),'') district,nullif(upper(btrim(x."Sexo")),'') sex
 into p from public.aos_pacientes x
 where public.aos_cia_normalize_contact_key_v1(x.numero_limpio)=k
 order by case when upper(coalesce(x."ESTADO_PACIENTE",''))='FUSIONADO' then 1 else 0 end,
          x.updated_at desc nulls last,x.created_at desc nulls last,x."ID_PACIENTE" desc limit 1;
 v_found:=found;
 if v_found then
  valid_email:=case when p.email is null then null when p.email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then true else false end;
  update public.aos_cia_contact_runtime_cache_v1 c set
   canonical_names=coalesce(p.names,c.canonical_names),canonical_surnames=coalesce(p.surnames,c.canonical_surnames),
   canonical_email=coalesce(p.email,c.canonical_email),email_valid=coalesce(valid_email,c.email_valid),
   patient_state=coalesce(p.patient_state,c.patient_state),crm_branch=coalesce(p.branch,c.crm_branch),
   district=coalesce(p.district,c.district),sex=coalesce(p.sex,c.sex),exists_as_patient=true,cache_refreshed_at=statement_timestamp()
  where c.contact_key=k;
 end if;
 perform public.aos_cia_runtime_mark_dirty_v1(k,'PROFILE');
 return jsonb_build_object('ok',true,'contact_key',k,'patient_found',v_found);
end $function$;
revoke all on function public.aos_cia_runtime_refresh_profile_one_v1(text) from public,anon,authenticated;

create or replace function public.aos_cia_runtime_refresh_appointment_one_v1(p_contact_key text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare k text:=public.aos_cia_normalize_contact_key_v1(p_contact_key); total integer:=0; no_show integer:=0; attended integer:=0; nxt date;
begin
 if k is null then return jsonb_build_object('ok',false,'error','INVALID_CONTACT_KEY'); end if;
 perform public.aos_cia_runtime_ensure_contact_v1(k);
 select count(*)::integer,count(*) filter(where upper(coalesce(estado_cita,''))='NO ASISTIO')::integer,
        count(*) filter(where upper(coalesce(estado_cita,'')) in ('ASISTIO','EFECTIVA'))::integer,
        min(fecha_cita) filter(where fecha_cita >= (now() at time zone 'America/Lima')::date and upper(coalesce(estado_cita,'')) in ('PENDIENTE','CITA CONFIRMADA'))
 into total,no_show,attended,nxt from public.aos_agenda_citas where public.aos_cia_normalize_contact_key_v1(numero_limpio)=k;
 update public.aos_cia_contact_runtime_cache_v1 c set appointments_never_had=(total=0),has_future_appointment=(nxt is not null),
  next_appointment_at=nxt,ever_no_show=(no_show>0),attended_count=attended,cache_refreshed_at=statement_timestamp() where c.contact_key=k;
 perform public.aos_cia_runtime_mark_dirty_v1(k,'APPOINTMENT');
 return jsonb_build_object('ok',true,'contact_key',k,'appointment_count',total,'has_future',nxt is not null);
end $function$;
revoke all on function public.aos_cia_runtime_refresh_appointment_one_v1(text) from public,anon,authenticated;

create or replace function public.aos_cia_runtime_refresh_call_one_v1(p_contact_key text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare k text:=public.aos_cia_normalize_contact_key_v1(p_contact_key); total integer:=0; effective integer:=0; last_at timestamptz; last_status text;
begin
 if k is null then return jsonb_build_object('ok',false,'error','INVALID_CONTACT_KEY'); end if;
 perform public.aos_cia_runtime_ensure_contact_v1(k);
 select count(*)::integer,count(*) filter(where nullif(upper(btrim(estado)),'') is not null and upper(btrim(estado)) not in ('SIN CONTACTO','NO CONTESTA'))::integer,max(created_at)
 into total,effective,last_at from public.aos_llamadas where public.aos_cia_normalize_contact_key_v1(numero_limpio)=k;
 select case when upper(btrim(estado))='PROVINCIAS' then 'PROVINCIA' else nullif(upper(btrim(estado)),'') end into last_status
 from public.aos_llamadas where public.aos_cia_normalize_contact_key_v1(numero_limpio)=k order by created_at desc nulls last,fecha desc nulls last,id desc limit 1;
 update public.aos_cia_contact_runtime_cache_v1 c set calls_never_called=(total=0),call_count=total,effective_contact_count=effective,
  last_call_at=last_at,latest_call_status=last_status,called_today=(last_at is not null and (last_at at time zone 'America/Lima')::date=(now() at time zone 'America/Lima')::date),
  days_since_last_call=case when last_at is null then null else (now() at time zone 'America/Lima')::date-last_at::date end,cache_refreshed_at=statement_timestamp()
 where c.contact_key=k;
 perform public.aos_cia_runtime_mark_dirty_v1(k,'CALL');
 return jsonb_build_object('ok',true,'contact_key',k,'call_count',total);
end $function$;
revoke all on function public.aos_cia_runtime_refresh_call_one_v1(text) from public,anon,authenticated;

create or replace function public.aos_cia_runtime_refresh_sale_one_v1(p_contact_key text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare k text:=public.aos_cia_normalize_contact_key_v1(p_contact_key); total integer:=0; revenue numeric:=0; last_sale date; product_n integer:=0; service_n integer:=0; new_traits text[];
begin
 if k is null then return jsonb_build_object('ok',false,'error','INVALID_CONTACT_KEY'); end if;
 perform public.aos_cia_runtime_ensure_contact_v1(k);
 select count(*)::integer,coalesce(sum(coalesce(monto,0)),0),max(fecha),count(*) filter(where upper(btrim(tipo))='PRODUCTO')::integer,count(*) filter(where upper(btrim(tipo))='SERVICIO')::integer
 into total,revenue,last_sale,product_n,service_n from public.aos_ventas where public.aos_cia_normalize_contact_key_v1(numero_limpio)=k;
 select coalesce(array_agg(distinct x order by x),array[]::text[]) into new_traits
 from unnest(coalesce((select traits from public.aos_cia_contact_runtime_cache_v1 where contact_key=k),array[]::text[])
   || case when product_n>0 then array['PRODUCT_BUYER']::text[] else array[]::text[] end
   || case when service_n>0 then array['SERVICE_BUYER']::text[] else array[]::text[] end) x
 where x not in ('PRODUCT_BUYER','SERVICE_BUYER') or (x='PRODUCT_BUYER' and product_n>0) or (x='SERVICE_BUYER' and service_n>0);
 update public.aos_cia_contact_runtime_cache_v1 c set sale_count=total,revenue_lifetime=revenue,sales_never_bought=(total=0),
  days_since_last_sale=case when last_sale is null then null else (now() at time zone 'America/Lima')::date-last_sale end,traits=new_traits,cache_refreshed_at=statement_timestamp()
 where c.contact_key=k;
 perform public.aos_cia_runtime_mark_dirty_v1(k,'SALE');
 return jsonb_build_object('ok',true,'contact_key',k,'sale_count',total,'revenue_lifetime',revenue);
end $function$;
revoke all on function public.aos_cia_runtime_refresh_sale_one_v1(text) from public,anon,authenticated;

create or replace function public.aos_cia_runtime_refresh_lead_one_v1(p_contact_key text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare k text:=public.aos_cia_normalize_contact_key_v1(p_contact_key); total integer:=0; last_lead timestamptz; interest text; interest_type text; last_call timestamptz;
begin
 if k is null then return jsonb_build_object('ok',false,'error','INVALID_CONTACT_KEY'); end if;
 perform public.aos_cia_runtime_ensure_contact_v1(k);
 select count(*)::integer,max(coalesce(hora_ingreso,created_at,(fecha::timestamp at time zone 'America/Lima'))) into total,last_lead
 from public.aos_leads where public.aos_cia_normalize_contact_key_v1(numero_limpio)=k;
 select nullif(upper(btrim(l.tratamiento)),''),coalesce(t.interest_type,'UNKNOWN') into interest,interest_type
 from public.aos_leads l left join public.aos_cia_interest_taxonomy_v1 t on t.interest_key=nullif(upper(btrim(l.tratamiento)),'')
 where public.aos_cia_normalize_contact_key_v1(l.numero_limpio)=k
 order by coalesce(l.hora_ingreso,l.created_at,(l.fecha::timestamp at time zone 'America/Lima')) desc nulls last,l.id desc limit 1;
 select max(created_at) into last_call from public.aos_llamadas where public.aos_cia_normalize_contact_key_v1(numero_limpio)=k;
 update public.aos_cia_contact_runtime_cache_v1 c set exists_as_lead=(total>0),latest_interest=interest,latest_interest_type=interest_type,
  days_since_last_lead=case when last_lead is null then null else (now() at time zone 'America/Lima')::date-last_lead::date end,
  lead_unworked_since_latest_entry=(last_lead is not null and (last_call is null or last_call<last_lead)),cache_refreshed_at=statement_timestamp()
 where c.contact_key=k;
 perform public.aos_cia_runtime_mark_dirty_v1(k,'LEAD');
 return jsonb_build_object('ok',true,'contact_key',k,'lead_count',total);
end $function$;
revoke all on function public.aos_cia_runtime_refresh_lead_one_v1(text) from public,anon,authenticated;

create or replace function public.aos_cia_runtime_landing_touch_trigger_v1() returns trigger language plpgsql security definer set search_path to '' as $function$
declare oldk text; newk text;
begin
 oldk:=case when tg_op in ('UPDATE','DELETE') then public.aos_cia_normalize_contact_key_v1(old.numero_limpio) else null end;
 newk:=case when tg_op in ('INSERT','UPDATE') then public.aos_cia_normalize_contact_key_v1(new.numero_limpio) else null end;
 if oldk is not null and oldk is distinct from newk then perform public.aos_cia_runtime_refresh_acquisition_one_v1(oldk); end if;
 if newk is not null then perform public.aos_cia_runtime_refresh_acquisition_one_v1(newk); perform public.aos_cia_runtime_refresh_profile_one_v1(newk); perform public.aos_cia_runtime_refresh_appointment_one_v1(newk); perform public.aos_cia_runtime_refresh_call_one_v1(newk); perform public.aos_cia_runtime_refresh_sale_one_v1(newk); end if;
 if tg_op='DELETE' then return old; else return new; end if;
end $function$;

create or replace function public.aos_cia_runtime_agenda_touch_trigger_v1() returns trigger language plpgsql security definer set search_path to '' as $function$
declare oldk text; newk text;
begin oldk:=case when tg_op in ('UPDATE','DELETE') then public.aos_cia_normalize_contact_key_v1(old.numero_limpio) else null end; newk:=case when tg_op in ('INSERT','UPDATE') then public.aos_cia_normalize_contact_key_v1(new.numero_limpio) else null end; if oldk is not null and oldk is distinct from newk then perform public.aos_cia_runtime_refresh_appointment_one_v1(oldk); end if; if newk is not null then perform public.aos_cia_runtime_refresh_appointment_one_v1(newk); end if; if tg_op='DELETE' then return old; else return new; end if; end $function$;
create or replace function public.aos_cia_runtime_call_touch_trigger_v1() returns trigger language plpgsql security definer set search_path to '' as $function$
declare oldk text; newk text;
begin oldk:=case when tg_op in ('UPDATE','DELETE') then public.aos_cia_normalize_contact_key_v1(old.numero_limpio) else null end; newk:=case when tg_op in ('INSERT','UPDATE') then public.aos_cia_normalize_contact_key_v1(new.numero_limpio) else null end; if oldk is not null and oldk is distinct from newk then perform public.aos_cia_runtime_refresh_call_one_v1(oldk); end if; if newk is not null then perform public.aos_cia_runtime_refresh_call_one_v1(newk); end if; if tg_op='DELETE' then return old; else return new; end if; end $function$;
create or replace function public.aos_cia_runtime_sale_touch_trigger_v1() returns trigger language plpgsql security definer set search_path to '' as $function$
declare oldk text; newk text;
begin oldk:=case when tg_op in ('UPDATE','DELETE') then public.aos_cia_normalize_contact_key_v1(old.numero_limpio) else null end; newk:=case when tg_op in ('INSERT','UPDATE') then public.aos_cia_normalize_contact_key_v1(new.numero_limpio) else null end; if oldk is not null and oldk is distinct from newk then perform public.aos_cia_runtime_refresh_sale_one_v1(oldk); end if; if newk is not null then perform public.aos_cia_runtime_refresh_sale_one_v1(newk); end if; if tg_op='DELETE' then return old; else return new; end if; end $function$;
create or replace function public.aos_cia_runtime_lead_touch_trigger_v1() returns trigger language plpgsql security definer set search_path to '' as $function$
declare oldk text; newk text;
begin oldk:=case when tg_op in ('UPDATE','DELETE') then public.aos_cia_normalize_contact_key_v1(old.numero_limpio) else null end; newk:=case when tg_op in ('INSERT','UPDATE') then public.aos_cia_normalize_contact_key_v1(new.numero_limpio) else null end; if oldk is not null and oldk is distinct from newk then perform public.aos_cia_runtime_refresh_lead_one_v1(oldk); end if; if newk is not null then perform public.aos_cia_runtime_refresh_lead_one_v1(newk); end if; if tg_op='DELETE' then return old; else return new; end if; end $function$;
create or replace function public.aos_cia_runtime_patient_touch_trigger_v1() returns trigger language plpgsql security definer set search_path to '' as $function$
declare oldk text; newk text;
begin oldk:=case when tg_op in ('UPDATE','DELETE') then public.aos_cia_normalize_contact_key_v1(old.numero_limpio) else null end; newk:=case when tg_op in ('INSERT','UPDATE') then public.aos_cia_normalize_contact_key_v1(new.numero_limpio) else null end; if oldk is not null and oldk is distinct from newk then perform public.aos_cia_runtime_refresh_profile_one_v1(oldk); end if; if newk is not null then perform public.aos_cia_runtime_refresh_profile_one_v1(newk); end if; if tg_op='DELETE' then return old; else return new; end if; end $function$;

create or replace function public.aos_cia_catalog_recount_runtime_v1()
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare started timestamptz:=clock_timestamp(); finished timestamptz; duration integer; counts jsonb; k text; v text;
begin
 select jsonb_build_object(
 '__ALL__',count(*),'ALL_LEADS',count(*) filter(where exists_as_lead),'LEAD_SERVICE_INTEREST',count(*) filter(where latest_interest_type='SERVICIO'),'LEAD_PRODUCT_INTEREST',count(*) filter(where latest_interest_type='PRODUCTO'),'LEADS_UNWORKED',count(*) filter(where lead_unworked_since_latest_entry),'LEADS_UNWORKED_7D',count(*) filter(where lead_unworked_since_latest_entry and days_since_last_lead<=7),
 'NEVER_CALLED_CONTACTS',count(*) filter(where calls_never_called),'CALLED_NO_EFFECTIVE_CONTACT',count(*) filter(where call_count>0 and effective_contact_count=0),'EFFECTIVE_CONTACTS',count(*) filter(where effective_contact_count>0),'CALLED_TODAY',count(*) filter(where called_today),'CALL_STALE_7D',count(*) filter(where days_since_last_call>7),'CALL_STALE_30D',count(*) filter(where days_since_last_call>30),
 'NEVER_APPOINTED',count(*) filter(where appointments_never_had),'HAS_FUTURE_APPOINTMENT',count(*) filter(where has_future_appointment),'EVER_NO_SHOW',count(*) filter(where ever_no_show),'ATTENDED_APPOINTMENT',count(*) filter(where attended_count>0),'NO_SHOW_NO_FUTURE',count(*) filter(where ever_no_show and not has_future_appointment),
 'NEVER_BOUGHT',count(*) filter(where sales_never_bought),'RECENT_BUYERS_30D',count(*) filter(where days_since_last_sale<=30),'DORMANT_BUYERS_90D',count(*) filter(where days_since_last_sale>90),'PRODUCT_BUYERS',count(*) filter(where traits @> array['PRODUCT_BUYER']::text[]),'SERVICE_BUYERS',count(*) filter(where traits @> array['SERVICE_BUYER']::text[]),
 'PENDING_FOLLOWUPS',count(*) filter(where pending_followup_count>0),'FOLLOWUP_OVERDUE',count(*) filter(where overdue_followup_count>0),'EMAIL_VALID',count(*) filter(where email_valid),'EMAIL_OPENED',count(*) filter(where email_opened_count>0),'EMAIL_CLICKED',count(*) filter(where email_clicked_count>0),'EMAIL_BOUNCED',count(*) filter(where email_bounced_count>0),'NEVER_EMAILED_KNOWN',count(*) filter(where email_never_sent),
 'PATIENTS',count(*) filter(where exists_as_patient),'IDENTITY_CONFLICT',count(*) filter(where identity_conflict),'ACTIVE_CUSTOMERS',count(*) filter(where lifecycle='ACTIVE_CUSTOMER'),'NEW_CUSTOMERS',count(*) filter(where lifecycle='NEW_CUSTOMER'),'WARM_PROSPECTS',count(*) filter(where lifecycle='WARM_PROSPECT'),'COLD_PROSPECTS',count(*) filter(where lifecycle='COLD_PROSPECT'),'GOLD_CUSTOMERS',count(*) filter(where value_tier='GOLD'),'DIAMOND_CUSTOMERS',count(*) filter(where value_tier='DIAMANTE'),'INACTIVE_CUSTOMERS',count(*) filter(where lifecycle='INACTIVE_CUSTOMER'),'HIGH_VALUE_COOLING',count(*) filter(where value_tier in ('GOLD','DIAMANTE') and lifecycle in ('COOLING_CUSTOMER','INACTIVE_CUSTOMER')),'ACTIVE_PROSPECTS',count(*) filter(where lifecycle in ('ACTIVE_PROSPECT','APPOINTMENT_READY_PROSPECT')),
 'AGE_18_24',count(*) filter(where age_band='18_24'),'AGE_25_34',count(*) filter(where age_band='25_34'),'AGE_35_44',count(*) filter(where age_band='35_44'),'AGE_45_54',count(*) filter(where age_band='45_54'),'AGE_55_64',count(*) filter(where age_band='55_64'),'AGE_65_PLUS',count(*) filter(where age_band='65_PLUS'),'SEX_FEMALE',count(*) filter(where sex='F'),'SEX_MALE',count(*) filter(where sex='M')
 ) || jsonb_build_object('WEB_BOOKINGS',count(*) filter(where web_booking_count>0),'WEB_BOOKINGS_FUTURE',count(*) filter(where web_booking_count>0 and has_future_appointment),'WEB_BOOKINGS_NO_PURCHASE',count(*) filter(where web_booking_count>0 and sales_never_bought))
 into counts from public.aos_cia_contact_runtime_cache_v1;
 finished:=clock_timestamp(); duration:=greatest(0,round(extract(epoch from(finished-started))*1000)::integer);
 for k,v in select key,value from jsonb_each_text(counts) loop
  insert into public.aos_audience_preset_runtime_cache_v1(preset_key,count_cache,refreshed_at,duration_ms,status,error_code,updated_at)
  values(k,v::bigint,finished,duration,'READY',null,finished)
  on conflict(preset_key) do update set count_cache=excluded.count_cache,refreshed_at=excluded.refreshed_at,duration_ms=excluded.duration_ms,status='READY',error_code=null,updated_at=excluded.updated_at;
 end loop;
 update public.aos_cia_runtime_freshness_v1 set catalog_dirty=false,dirty_since=null,last_catalog_recount_at=finished,pending_marks=0,updated_at=finished where singleton_id=1;
 return jsonb_build_object('ok',true,'refreshed',true,'counts',counts,'refreshed_at',finished,'duration_ms',duration);
exception when others then return jsonb_build_object('ok',false,'error','CATALOG_RECOUNT_FAILED','code',sqlstate);
end $function$;
revoke all on function public.aos_cia_catalog_recount_runtime_v1() from public,anon,authenticated;

create or replace function public.aos_cia_catalog_recount_if_dirty_v1(p_min_interval_seconds integer default 15)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare s public.aos_cia_runtime_freshness_v1%rowtype; locked boolean; outj jsonb;
begin
 select * into s from public.aos_cia_runtime_freshness_v1 where singleton_id=1;
 if not coalesce(s.catalog_dirty,true) then return jsonb_build_object('ok',true,'refreshed',false,'reason','CLEAN','last_catalog_recount_at',s.last_catalog_recount_at); end if;
 if s.last_catalog_recount_at is not null and statement_timestamp()<s.last_catalog_recount_at+make_interval(secs=>greatest(0,coalesce(p_min_interval_seconds,15))) then return jsonb_build_object('ok',true,'refreshed',false,'reason','COALESCED','dirty_since',s.dirty_since,'pending_marks',s.pending_marks); end if;
 locked:=pg_try_advisory_xact_lock(7242102); if not locked then return jsonb_build_object('ok',true,'refreshed',false,'reason','LOCKED_BY_PEER','pending_marks',s.pending_marks); end if;
 outj:=public.aos_cia_catalog_recount_runtime_v1(); return outj;
end $function$;
revoke all on function public.aos_cia_catalog_recount_if_dirty_v1(integer) from public,anon,authenticated;

create or replace function public.aos_cia_runtime_recount_statement_v1()
returns trigger language plpgsql security definer set search_path to '' as $function$
begin perform public.aos_cia_catalog_recount_if_dirty_v1(0); return null; end $function$;
revoke all on function public.aos_cia_runtime_recount_statement_v1() from public,anon,authenticated;

-- Row refresh + one recount per SQL source statement.
drop trigger if exists trg_cia_runtime_landing_touch_v1 on public.aos_landing_booking_attribution;
create trigger trg_cia_runtime_landing_touch_v1 after insert or update or delete on public.aos_landing_booking_attribution for each row execute function public.aos_cia_runtime_landing_touch_trigger_v1();
drop trigger if exists trg_cia_runtime_agenda_touch_v1 on public.aos_agenda_citas;
create trigger trg_cia_runtime_agenda_touch_v1 after insert or update or delete on public.aos_agenda_citas for each row execute function public.aos_cia_runtime_agenda_touch_trigger_v1();
drop trigger if exists trg_cia_runtime_call_touch_v1 on public.aos_llamadas;
create trigger trg_cia_runtime_call_touch_v1 after insert or update or delete on public.aos_llamadas for each row execute function public.aos_cia_runtime_call_touch_trigger_v1();
drop trigger if exists trg_cia_runtime_sale_touch_v1 on public.aos_ventas;
create trigger trg_cia_runtime_sale_touch_v1 after insert or update or delete on public.aos_ventas for each row execute function public.aos_cia_runtime_sale_touch_trigger_v1();
drop trigger if exists trg_cia_runtime_lead_touch_v1 on public.aos_leads;
create trigger trg_cia_runtime_lead_touch_v1 after insert or update or delete on public.aos_leads for each row execute function public.aos_cia_runtime_lead_touch_trigger_v1();
drop trigger if exists trg_cia_runtime_patient_touch_v1 on public.aos_pacientes;
create trigger trg_cia_runtime_patient_touch_v1 after insert or update or delete on public.aos_pacientes for each row execute function public.aos_cia_runtime_patient_touch_trigger_v1();

do $do$
declare t text;
begin
 foreach t in array array['aos_landing_booking_attribution','aos_agenda_citas','aos_llamadas','aos_ventas','aos_leads','aos_pacientes'] loop
  execute format('drop trigger if exists %I on public.%I','trg_cia_runtime_recount_stmt_v1_'||t,t);
  execute format('create trigger %I after insert or update or delete on public.%I for each statement execute function public.aos_cia_runtime_recount_statement_v1()','trg_cia_runtime_recount_stmt_v1_'||t,t);
 end loop;
end $do$;

-- Optional authenticated metadata wrapper for a future UI cutover; current correctness does not depend on it
-- because statement triggers keep preset counts current.
create or replace function public.aos_cia_control_center_app_v7(p_app_token text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare a text:=upper(btrim(coalesce(p_action,''))); base jsonb; freshness jsonb;
begin
 if a<>'CATALOG_META' then return public.aos_cia_control_center_app_v5(p_app_token,p_action,p_payload); end if;
 base:=public.aos_cia_control_center_app_v5(p_app_token,p_action,p_payload); if not coalesce((base->>'ok')::boolean,false) then return base; end if;
 freshness:=public.aos_cia_catalog_recount_if_dirty_v1(15);
 if coalesce((freshness->>'refreshed')::boolean,false) then base:=public.aos_cia_control_center_app_v5(p_app_token,p_action,p_payload); end if;
 return base||jsonb_build_object('freshness',freshness);
end $function$;
revoke all on function public.aos_cia_control_center_app_v7(text,text,jsonb) from public;
grant execute on function public.aos_cia_control_center_app_v7(text,text,jsonb) to anon,authenticated;

commit;
