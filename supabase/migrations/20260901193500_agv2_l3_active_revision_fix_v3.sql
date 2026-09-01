-- ASCENDA OS · WA-AUTO L3 — deterministic active schedule revision
-- PostgreSQL now() is transaction-stable, so BOOKED and RESCHEDULED events created
-- in one transaction may share created_at. Reminder materialization must therefore
-- resolve the active non-superseded delivery revision, not guess from timestamps.

begin;

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

    -- The active schedule revision is the BOOK/REBOOK revision whose post-commit
    -- confirmation/reprogramming intent has not been superseded. This is deterministic
    -- even when multiple event rows share the same transaction-stable created_at.
    select e.* into v_e
    from public.aos_agenda_events_v2 e
    where e.appointment_id=v_c.id
      and e.event_type in ('BOOKED','RESCHEDULED')
      and exists (
        select 1
        from public.aos_agenda_delivery_outbox_v3 o
        where o.agenda_event_id=e.id
          and o.schedule_revision=e.id::text
          and o.delivery_kind in ('CONFIRMATION','REPROGRAMMATION')
          and o.state<>'SUPERSEDED'
      )
    order by
      case when e.event_type='RESCHEDULED' then 0 else 1 end,
      e.created_at desc,
      e.id desc
    limit 1;

    if not found then
      -- Projection may have failed transiently. Reconcile once from the append-only
      -- event ledger and retry active-revision resolution without touching the booking.
      perform public.aos_agenda_delivery_reconcile_v3(2000);
      select e.* into v_e
      from public.aos_agenda_events_v2 e
      where e.appointment_id=v_c.id
        and e.event_type in ('BOOKED','RESCHEDULED')
        and exists (
          select 1
          from public.aos_agenda_delivery_outbox_v3 o
          where o.agenda_event_id=e.id
            and o.schedule_revision=e.id::text
            and o.delivery_kind in ('CONFIRMATION','REPROGRAMMATION')
            and o.state<>'SUPERSEDED'
        )
      order by
        case when e.event_type='RESCHEDULED' then 0 else 1 end,
        e.created_at desc,
        e.id desc
      limit 1;
    end if;
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
      'reminder_local_date',v_local_date,
      'schedule_revision',v_e.id
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

revoke all on function public.aos_agenda_delivery_materialize_reminders_v3(timestamptz,integer) from public,anon,authenticated;
grant execute on function public.aos_agenda_delivery_materialize_reminders_v3(timestamptz,integer) to service_role;

comment on function public.aos_agenda_delivery_materialize_reminders_v3(timestamptz,integer) is
'Materializes TODAY/TOMORROW reminder intents for the active non-superseded V2 schedule revision; never dispatches providers.';

commit;
