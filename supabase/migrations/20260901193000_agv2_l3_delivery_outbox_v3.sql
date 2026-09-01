-- ASCENDA OS · WA-AUTO L3 — Post-commit confirmation + reminder outbox V3
-- Durable/idempotent delivery intents only. No provider dispatch is enabled in this phase.
-- L4 owns autonomous dispatch authority / kill switch. Provider failure must never roll back booking.

begin;

create table if not exists public.aos_agenda_delivery_template_registry_v3 (
  delivery_kind text not null check (delivery_kind in ('CONFIRMATION','REPROGRAMMATION','REMINDER_TOMORROW','REMINDER_TODAY')),
  channel text not null check (channel in ('EMAIL','WHATSAPP')),
  site_scope text not null default '*' check (site_scope in ('*','SAN ISIDRO','PUEBLO LIBRE')),
  template_key text not null,
  provider text not null check (provider in ('RESEND','META_CLOUD_API')),
  provider_template_name text null,
  provider_verified boolean not null default false,
  active boolean not null default true,
  evidence_ref text not null,
  updated_at timestamptz not null default now(),
  primary key(delivery_kind,channel,site_scope)
);

insert into public.aos_agenda_delivery_template_registry_v3(
  delivery_kind,channel,site_scope,template_key,provider,provider_template_name,provider_verified,evidence_ref
)
values
  ('CONFIRMATION','EMAIL','*','confirmacion_cita','RESEND','confirmacion_cita',true,'APP_SERVER_TRANSACTIONAL_TYPE_CURRENT'),
  ('REPROGRAMMATION','EMAIL','*','reprogramacion','RESEND','reprogramacion',true,'APP_SERVER_TRANSACTIONAL_TYPE_CURRENT'),
  ('REMINDER_TOMORROW','EMAIL','*','recordatorio_manana','RESEND','recordatorio_manana',true,'APP_SERVER_TRANSACTIONAL_TYPE_CURRENT'),
  ('REMINDER_TODAY','EMAIL','*','recordatorio_hoy','RESEND','recordatorio_hoy',true,'APP_SERVER_TRANSACTIONAL_TYPE_CURRENT'),
  ('CONFIRMATION','WHATSAPP','*','cita_confirmada','META_CLOUD_API',null,false,'AOS_PLANTILLAS_WHATSAPP:cita_confirmada;META_APPROVAL_UNVERIFIED'),
  ('REPROGRAMMATION','WHATSAPP','*','reprogramacion','META_CLOUD_API',null,false,'LOGICAL_REPROGRAM_TEMPLATE;META_APPROVAL_UNVERIFIED'),
  ('REMINDER_TOMORROW','WHATSAPP','SAN ISIDRO','recordatorio_manana_si','META_CLOUD_API',null,false,'AOS_PLANTILLAS_WHATSAPP:recordatorio_manana_si;META_APPROVAL_UNVERIFIED'),
  ('REMINDER_TOMORROW','WHATSAPP','PUEBLO LIBRE','recordatorio_manana_pl','META_CLOUD_API',null,false,'AOS_PLANTILLAS_WHATSAPP:recordatorio_manana_pl;META_APPROVAL_UNVERIFIED'),
  ('REMINDER_TODAY','WHATSAPP','SAN ISIDRO','recordatorio_hoy_si','META_CLOUD_API',null,false,'AOS_PLANTILLAS_WHATSAPP:recordatorio_hoy_si;META_APPROVAL_UNVERIFIED'),
  ('REMINDER_TODAY','WHATSAPP','PUEBLO LIBRE','recordatorio_hoy_pl','META_CLOUD_API',null,false,'AOS_PLANTILLAS_WHATSAPP:recordatorio_hoy_pl;META_APPROVAL_UNVERIFIED')
on conflict(delivery_kind,channel,site_scope) do update
set template_key=excluded.template_key,
    provider=excluded.provider,
    provider_template_name=excluded.provider_template_name,
    provider_verified=excluded.provider_verified,
    active=true,
    evidence_ref=excluded.evidence_ref,
    updated_at=now();

create table if not exists public.aos_agenda_delivery_outbox_v3 (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  agenda_event_id uuid not null references public.aos_agenda_events_v2(id),
  operation_id uuid not null references public.aos_booking_operations_v2(id),
  appointment_id text not null,
  schedule_revision text not null,
  delivery_kind text not null check (delivery_kind in ('CONFIRMATION','REPROGRAMMATION','REMINDER_TOMORROW','REMINDER_TODAY')),
  channel text not null check (channel in ('EMAIL','WHATSAPP')),
  provider text not null check (provider in ('RESEND','META_CLOUD_API')),
  template_key text not null,
  provider_template_name text null,
  provider_template_verified boolean not null default false,
  recipient_email text null,
  recipient_phone text null,
  payload jsonb not null default '{}'::jsonb,
  state text not null default 'DORMANT' check (state in ('DORMANT','READY','CLAIMED','ACCEPTED','FAILED','SUPERSEDED','SKIPPED')),
  blocking_reason text null,
  available_at timestamptz not null default now(),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  provider_message_id text null,
  last_error text null,
  last_attempt_at timestamptz null,
  accepted_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((channel='EMAIL' and recipient_email is not null) or (channel='WHATSAPP' and recipient_phone is not null))
);

create index if not exists idx_aos_agenda_delivery_outbox_v3_appointment
  on public.aos_agenda_delivery_outbox_v3(appointment_id,created_at desc);
create index if not exists idx_aos_agenda_delivery_outbox_v3_state
  on public.aos_agenda_delivery_outbox_v3(state,available_at,created_at)
  where state in ('DORMANT','READY','FAILED');
create index if not exists idx_aos_agenda_delivery_outbox_v3_revision
  on public.aos_agenda_delivery_outbox_v3(appointment_id,schedule_revision,delivery_kind,channel);

create table if not exists public.aos_agenda_delivery_errors_v3 (
  id uuid primary key default gen_random_uuid(),
  agenda_event_id uuid null,
  appointment_id text null,
  error_code text not null,
  error_detail text null,
  created_at timestamptz not null default now()
);

revoke all on table public.aos_agenda_delivery_template_registry_v3 from public,anon,authenticated;
revoke all on table public.aos_agenda_delivery_outbox_v3 from public,anon,authenticated;
revoke all on table public.aos_agenda_delivery_errors_v3 from public,anon,authenticated;
grant select,insert,update,delete on table public.aos_agenda_delivery_template_registry_v3 to service_role;
grant select,insert,update,delete on table public.aos_agenda_delivery_outbox_v3 to service_role;
grant select,insert on table public.aos_agenda_delivery_errors_v3 to service_role;

create or replace function public.aos_agenda_delivery_insert_intent_v3(
  p_agenda_event_id uuid,
  p_operation_id uuid,
  p_appointment_id text,
  p_schedule_revision text,
  p_delivery_kind text,
  p_channel text,
  p_site text,
  p_recipient_email text,
  p_recipient_phone text,
  p_payload jsonb
)
returns boolean
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_kind text:=upper(btrim(coalesce(p_delivery_kind,'')));
  v_channel text:=upper(btrim(coalesce(p_channel,'')));
  v_site text:=upper(replace(btrim(coalesce(p_site,'')),'_',' '));
  v_tpl public.aos_agenda_delivery_template_registry_v3%rowtype;
  v_email text:=nullif(lower(btrim(coalesce(p_recipient_email,''))),'');
  v_phone text:=regexp_replace(coalesce(p_recipient_phone,''),'[^0-9]','','g');
  v_key text;
  v_inserted uuid;
  v_block text;
begin
  if p_agenda_event_id is null or p_operation_id is null or coalesce(btrim(p_appointment_id),'')='' or coalesce(btrim(p_schedule_revision),'')='' then
    return false;
  end if;

  select * into v_tpl
  from public.aos_agenda_delivery_template_registry_v3 t
  where t.active=true
    and t.delivery_kind=v_kind
    and t.channel=v_channel
    and t.site_scope in (v_site,'*')
  order by case when t.site_scope=v_site then 0 else 1 end
  limit 1;
  if not found then return false; end if;

  if v_channel='EMAIL' then
    if v_email is null or v_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then return false; end if;
  elsif v_channel='WHATSAPP' then
    if length(v_phone)<7 then return false; end if;
  else
    return false;
  end if;

  v_key:='agv2-l3:'||p_schedule_revision||':'||v_kind||':'||v_channel;
  v_block:='L4_DISPATCH_AUTHORITY_REQUIRED';
  if v_tpl.provider_verified is not true then
    v_block:=v_block||'|PROVIDER_TEMPLATE_APPROVAL_UNVERIFIED';
  end if;

  insert into public.aos_agenda_delivery_outbox_v3(
    idempotency_key,agenda_event_id,operation_id,appointment_id,schedule_revision,
    delivery_kind,channel,provider,template_key,provider_template_name,provider_template_verified,
    recipient_email,recipient_phone,payload,state,blocking_reason
  ) values (
    v_key,p_agenda_event_id,p_operation_id,p_appointment_id,p_schedule_revision,
    v_kind,v_channel,v_tpl.provider,v_tpl.template_key,v_tpl.provider_template_name,v_tpl.provider_verified,
    case when v_channel='EMAIL' then v_email else null end,
    case when v_channel='WHATSAPP' then v_phone else null end,
    coalesce(p_payload,'{}'::jsonb),'DORMANT',v_block
  )
  on conflict(idempotency_key) do nothing
  returning id into v_inserted;

  return v_inserted is not null;
end
$$;

create or replace function public.aos_agenda_delivery_enqueue_event_v3(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_e public.aos_agenda_events_v2%rowtype;
  v_c public.aos_agenda_citas%rowtype;
  v_kind text;
  v_email text;
  v_phone text;
  v_payload jsonb;
  v_email_added boolean:=false;
  v_wa_added boolean:=false;
begin
  select * into v_e from public.aos_agenda_events_v2 where id=p_event_id;
  if not found then return jsonb_build_object('ok',false,'error','L3_EVENT_NOT_FOUND'); end if;
  if v_e.event_type not in ('BOOKED','RESCHEDULED') then return jsonb_build_object('ok',false,'error','L3_EVENT_NOT_DELIVERABLE'); end if;

  select * into v_c from public.aos_agenda_citas where id=v_e.appointment_id;
  if not found then return jsonb_build_object('ok',false,'error','L3_APPOINTMENT_NOT_FOUND'); end if;

  v_kind:=case when v_e.event_type='BOOKED' then 'CONFIRMATION' else 'REPROGRAMMATION' end;
  v_email:=nullif(lower(btrim(coalesce(v_c.correo,''))),'');
  v_phone:=regexp_replace(coalesce(v_c.numero_limpio,v_c.numero,''),'[^0-9]','','g');

  -- A rebook invalidates any unsent intent generated from an older schedule revision.
  if v_e.event_type='RESCHEDULED' then
    update public.aos_agenda_delivery_outbox_v3
       set state='SUPERSEDED',blocking_reason='SUPERSEDED_BY_RESCHEDULE',updated_at=now()
     where appointment_id=v_e.appointment_id
       and schedule_revision<>v_e.id::text
       and state in ('DORMANT','READY','FAILED')
       and provider_message_id is null;
  end if;

  v_payload:=jsonb_build_object(
    'appointment_id',v_c.id,
    'event_id',v_e.id,
    'event_type',v_e.event_type,
    'name',btrim(concat_ws(' ',v_c.nombre,v_c.apellido)),
    'treatment',v_c.tratamiento,
    'site',v_c.sede,
    'date',v_c.fecha_cita,
    'time',substring(coalesce(v_c.hora_cita,'') from 1 for 5),
    'status',v_c.estado_cita,
    'professional_name',v_c.doctora,
    'professional_role',v_c.tipo_atencion,
    'reason',v_e.reason,
    'source_channel',v_e.channel
  );

  v_email_added:=public.aos_agenda_delivery_insert_intent_v3(
    v_e.id,v_e.operation_id,v_e.appointment_id,v_e.id::text,v_kind,'EMAIL',v_c.sede,v_email,v_phone,v_payload
  );
  v_wa_added:=public.aos_agenda_delivery_insert_intent_v3(
    v_e.id,v_e.operation_id,v_e.appointment_id,v_e.id::text,v_kind,'WHATSAPP',v_c.sede,v_email,v_phone,v_payload
  );

  return jsonb_build_object(
    'ok',true,'event_id',v_e.id,'appointment_id',v_e.appointment_id,'delivery_kind',v_kind,
    'email_added',v_email_added,'whatsapp_added',v_wa_added,'dispatch_state','DORMANT_L4_REQUIRED'
  );
end
$$;

create or replace function public.aos_agenda_delivery_event_trigger_v3()
returns trigger
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
begin
  begin
    perform public.aos_agenda_delivery_enqueue_event_v3(new.id);
  exception when others then
    -- Delivery projection is repairable from the append-only event ledger. Never roll back a booking.
    begin
      insert into public.aos_agenda_delivery_errors_v3(agenda_event_id,appointment_id,error_code,error_detail)
      values(new.id,new.appointment_id,'L3_ENQUEUE_FAILED',left(sqlerrm,1000));
    exception when others then
      null;
    end;
  end;
  return new;
end
$$;

drop trigger if exists trg_aos_agenda_delivery_event_v3 on public.aos_agenda_events_v2;
create trigger trg_aos_agenda_delivery_event_v3
after insert on public.aos_agenda_events_v2
for each row execute function public.aos_agenda_delivery_event_trigger_v3();

create or replace function public.aos_agenda_delivery_reconcile_v3(p_limit integer default 500)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_e record;
  v_limit integer:=greatest(1,least(coalesce(p_limit,500),2000));
  v_scanned integer:=0;
  v_ok integer:=0;
  v_r jsonb;
begin
  for v_e in
    select e.id
    from public.aos_agenda_events_v2 e
    where e.event_type in ('BOOKED','RESCHEDULED')
    order by e.created_at,e.id
    limit v_limit
  loop
    v_scanned:=v_scanned+1;
    begin
      v_r:=public.aos_agenda_delivery_enqueue_event_v3(v_e.id);
      if coalesce((v_r->>'ok')::boolean,false) then v_ok:=v_ok+1; end if;
    exception when others then
      begin
        insert into public.aos_agenda_delivery_errors_v3(agenda_event_id,error_code,error_detail)
        values(v_e.id,'L3_RECONCILE_FAILED',left(sqlerrm,1000));
      exception when others then null; end;
    end;
  end loop;
  return jsonb_build_object('ok',true,'scanned',v_scanned,'reconciled',v_ok);
end
$$;

create or replace function public.aos_agenda_delivery_materialize_reminders_v3(
  p_now timestamptz default now(),
  p_limit integer default 500
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
declare
  v_local_date date:=(coalesce(p_now,now()) at time zone 'America/Lima')::date;
  v_limit integer:=greatest(1,least(coalesce(p_limit,500),2000));
  v_c public.aos_agenda_citas%rowtype;
  v_e public.aos_agenda_events_v2%rowtype;
  v_kind text;
  v_email text;
  v_phone text;
  v_payload jsonb;
  v_email_added boolean;
  v_wa_added boolean;
  v_scanned integer:=0;
  v_inserted integer:=0;
begin
  for v_c in
    select c.*
    from public.aos_agenda_citas c
    where c.fecha_cita in (v_local_date,v_local_date+1)
      and upper(coalesce(c.estado_cita,'PENDIENTE')) in ('PENDIENTE','CITA CONFIRMADA')
      and exists(select 1 from public.aos_agenda_events_v2 e where e.appointment_id=c.id)
    order by c.fecha_cita,substring(coalesce(c.hora_cita,'') from 1 for 5),c.id
    limit v_limit
  loop
    v_scanned:=v_scanned+1;
    select * into v_e
    from public.aos_agenda_events_v2 e
    where e.appointment_id=v_c.id
    order by e.created_at desc,e.id desc
    limit 1;
    if not found then continue; end if;

    v_kind:=case when v_c.fecha_cita=v_local_date then 'REMINDER_TODAY' else 'REMINDER_TOMORROW' end;
    v_email:=nullif(lower(btrim(coalesce(v_c.correo,''))),'');
    v_phone:=regexp_replace(coalesce(v_c.numero_limpio,v_c.numero,''),'[^0-9]','','g');
    v_payload:=jsonb_build_object(
      'appointment_id',v_c.id,
      'event_id',v_e.id,
      'event_type',v_e.event_type,
      'name',btrim(concat_ws(' ',v_c.nombre,v_c.apellido)),
      'treatment',v_c.tratamiento,
      'site',v_c.sede,
      'date',v_c.fecha_cita,
      'time',substring(coalesce(v_c.hora_cita,'') from 1 for 5),
      'status',v_c.estado_cita,
      'professional_name',v_c.doctora,
      'professional_role',v_c.tipo_atencion,
      'reminder_local_date',v_local_date
    );

    v_email_added:=public.aos_agenda_delivery_insert_intent_v3(
      v_e.id,v_e.operation_id,v_c.id,v_e.id::text,v_kind,'EMAIL',v_c.sede,v_email,v_phone,v_payload
    );
    v_wa_added:=public.aos_agenda_delivery_insert_intent_v3(
      v_e.id,v_e.operation_id,v_c.id,v_e.id::text,v_kind,'WHATSAPP',v_c.sede,v_email,v_phone,v_payload
    );
    v_inserted:=v_inserted + case when v_email_added then 1 else 0 end + case when v_wa_added then 1 else 0 end;
  end loop;

  return jsonb_build_object(
    'ok',true,'local_date',v_local_date,'appointments_scanned',v_scanned,
    'intents_inserted',v_inserted,'dispatch_state','DORMANT_L4_REQUIRED'
  );
end
$$;

create or replace function public.aos_agenda_delivery_audit_v3()
returns jsonb
language sql
stable
security definer
set search_path='pg_catalog','public','pg_temp'
as $$
  select jsonb_build_object(
    'template_registry_total',(select count(*) from public.aos_agenda_delivery_template_registry_v3 where active=true),
    'template_provider_verified',(select count(*) from public.aos_agenda_delivery_template_registry_v3 where active=true and provider_verified=true),
    'template_provider_unverified',(select count(*) from public.aos_agenda_delivery_template_registry_v3 where active=true and provider_verified=false),
    'outbox_total',(select count(*) from public.aos_agenda_delivery_outbox_v3),
    'dormant',(select count(*) from public.aos_agenda_delivery_outbox_v3 where state='DORMANT'),
    'accepted',(select count(*) from public.aos_agenda_delivery_outbox_v3 where state='ACCEPTED'),
    'superseded',(select count(*) from public.aos_agenda_delivery_outbox_v3 where state='SUPERSEDED'),
    'projection_errors',(select count(*) from public.aos_agenda_delivery_errors_v3),
    'dispatch_boundary','L4_AUTHORITY_REQUIRED'
  );
$$;

revoke all on function public.aos_agenda_delivery_insert_intent_v3(uuid,uuid,text,text,text,text,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_agenda_delivery_enqueue_event_v3(uuid) from public,anon,authenticated;
revoke all on function public.aos_agenda_delivery_event_trigger_v3() from public,anon,authenticated;
revoke all on function public.aos_agenda_delivery_reconcile_v3(integer) from public,anon,authenticated;
revoke all on function public.aos_agenda_delivery_materialize_reminders_v3(timestamptz,integer) from public,anon,authenticated;
revoke all on function public.aos_agenda_delivery_audit_v3() from public,anon,authenticated;
grant execute on function public.aos_agenda_delivery_insert_intent_v3(uuid,uuid,text,text,text,text,text,text,text,jsonb) to service_role;
grant execute on function public.aos_agenda_delivery_enqueue_event_v3(uuid) to service_role;
grant execute on function public.aos_agenda_delivery_reconcile_v3(integer) to service_role;
grant execute on function public.aos_agenda_delivery_materialize_reminders_v3(timestamptz,integer) to service_role;
grant execute on function public.aos_agenda_delivery_audit_v3() to service_role;

comment on table public.aos_agenda_delivery_outbox_v3 is 'WA-AUTO L3 durable/idempotent post-booking delivery intents. Provider dispatch remains dormant until L4 authority.';
comment on function public.aos_agenda_delivery_materialize_reminders_v3(timestamptz,integer) is 'Materializes TODAY/TOMORROW reminder intents for V2-booked appointments; does not send them.';
comment on function public.aos_agenda_delivery_event_trigger_v3() is 'Fail-soft projection from append-only Agenda V2 events. Delivery projection failure must never roll back booking.';

commit;
