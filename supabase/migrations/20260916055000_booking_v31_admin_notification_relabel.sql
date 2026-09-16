-- BOOKING-V3.1 — relabel only the just-emitted appointment notifications using source metadata.
-- Push worker reads aos_notificaciones, so title/body are source-aware before delivery.
begin;
create or replace function public.aos_booking_notification_relabel_v1(p_agenda_id text)
returns void language plpgsql security definer set search_path='public','pg_temp' as $$
declare n record; f jsonb; begin
 for n in select id,event_type,metadata from public.aos_notificaciones where entity_id=p_agenda_id and event_type in ('APPOINTMENT_CREATED','ADMIN_APPOINTMENT_DIGEST') loop
  f:=public.aos_notification_format_booking_v31(n.event_type,n.metadata);
  update public.aos_notificaciones set titulo=f->>'title',contenido=f->>'body',updated_at=now() where id=n.id;
 end loop;
end $$;

create or replace function public.aos_booking_notification_relabel_trigger_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$ begin perform public.aos_booking_notification_relabel_v1(new.id); return new; end $$;

drop trigger if exists trg_aos_booking_notification_relabel_v1 on public.aos_agenda_citas;
create constraint trigger trg_aos_booking_notification_relabel_v1 after insert on public.aos_agenda_citas deferrable initially deferred for each row execute function public.aos_booking_notification_relabel_trigger_v1();
commit;
