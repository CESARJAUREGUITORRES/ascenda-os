-- INT-GOOGLE-001 emergency rollback.
-- Production use is destructive for Google connection metadata and requires owner approval + export/backup first.
drop trigger if exists trg_aos_google_enqueue_agenda_v1 on public.aos_agenda_citas;
drop trigger if exists trg_aos_google_enqueue_patient_v1 on public.aos_pacientes;
drop function if exists public.aos_google_enqueue_agenda_v1();
drop function if exists public.aos_google_enqueue_patient_v1();
drop function if exists public.aos_google_claim_sync_v1(text,integer);

drop table if exists public.aos_google_sync_outbox_v1;
drop table if exists public.aos_google_contact_links_v1;
drop table if exists public.aos_google_calendar_links_v1;
drop table if exists public.aos_google_oauth_states_v1;
drop table if exists public.aos_google_connections_v1;

update public.aos_integraciones
set estado='pendiente',
    cuenta='',
    descripcion='Calendario, contactos y Drive integrados con el sistema',
    config=(coalesce(config,'{}'::jsonb)
      - 'calendar_timezone'
      - 'contact_name_template'
      - 'contact_tag_source'
      - 'contact_month_source'
      - 'send_calendar_invites'
      - 'oauth_mode'
      - 'connection_id'),
    updated_at=now()
where tipo='google' and nombre='Google Calendar + Contacts';
