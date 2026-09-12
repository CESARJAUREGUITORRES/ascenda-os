\set ON_ERROR_STOP on
do $$
declare
  integ uuid := '8587b7fa-96cd-409c-b814-e7d2261cd0c8';
  conn uuid;
  c bigint;
begin
  if to_regclass('public.aos_google_connections_v1') is null then raise exception 'GOOGLE_CONNECTION_TABLE_MISSING'; end if;
  if to_regclass('public.aos_google_sync_outbox_v1') is null then raise exception 'GOOGLE_OUTBOX_TABLE_MISSING'; end if;

  if not (select relrowsecurity and relforcerowsecurity from pg_class where oid='public.aos_google_connections_v1'::regclass) then
    raise exception 'GOOGLE_CONNECTION_RLS_NOT_FORCED';
  end if;
  if has_table_privilege('anon','public.aos_google_connections_v1','select')
     or has_table_privilege('authenticated','public.aos_google_connections_v1','select') then
    raise exception 'GOOGLE_CONNECTION_BROWSER_READ_EXPOSED';
  end if;
  if has_table_privilege('anon','public.aos_google_sync_outbox_v1','insert')
     or has_table_privilege('authenticated','public.aos_google_sync_outbox_v1','insert') then
    raise exception 'GOOGLE_OUTBOX_BROWSER_WRITE_EXPOSED';
  end if;

  insert into public.aos_google_connections_v1(
    integration_id,account_email,refresh_token_enc,is_primary,status,calendar_enabled,contacts_enabled
  ) values (
    integ,'canary@example.com','v1.synthetic.synthetic.synthetic',true,'CONNECTED',false,false
  ) returning id into conn;

  insert into public.aos_agenda_citas(
    id,fecha_cita,hora_cita,nombre,apellido,tratamiento,sede,correo,numero_limpio,estado_cita
  ) values (
    'appt-1','2026-09-20','10:00','Canary','Paciente','TOXINA','SAN ISIDRO','patient@example.com','999111222','PENDIENTE'
  );
  select count(*) into c from public.aos_google_sync_outbox_v1;
  if c <> 0 then raise exception 'SAFE_OFF_ENQUEUED:%',c; end if;

  update public.aos_google_connections_v1 set calendar_enabled=true where id=conn;
  update public.aos_agenda_citas set hora_cita='10:30' where id='appt-1';
  select count(*) into c from public.aos_google_sync_outbox_v1 where action='CALENDAR_UPSERT' and entity_id='appt-1';
  if c <> 1 then raise exception 'CALENDAR_UPSERT_NOT_QUEUED:%',c; end if;

  insert into public.aos_pacientes("ID_PACIENTE","Nombres","Apellidos","Teléfono","Email",numero_limpio,tratamiento_principal)
  values('P-1','Canary','Paciente','999111222','patient@example.com','999111222','TOXINA');
  select count(*) into c from public.aos_google_sync_outbox_v1 where action='CONTACT_UPSERT';
  if c <> 0 then raise exception 'CONTACT_QUEUED_WHILE_DISABLED:%',c; end if;

  update public.aos_google_connections_v1 set contacts_enabled=true where id=conn;
  update public.aos_pacientes set "Email"='patient2@example.com' where "ID_PACIENTE"='P-1';
  select count(*) into c from public.aos_google_sync_outbox_v1 where action='CONTACT_UPSERT' and entity_id='P-1';
  if c <> 1 then raise exception 'CONTACT_UPSERT_NOT_QUEUED:%',c; end if;

  update public.aos_agenda_citas set estado_cita='REAGENDADA' where id='appt-1';
  select count(*) into c from public.aos_google_sync_outbox_v1 where action='CALENDAR_DELETE' and entity_id='appt-1';
  if c <> 1 then raise exception 'LEGACY_REBOOK_NOT_SUPERSEDED:%',c; end if;

  if not has_function_privilege('service_role','public.aos_google_claim_sync_v1(text,integer)','execute') then
    raise exception 'SERVICE_ROLE_CLAIM_DENIED';
  end if;
  if has_function_privilege('anon','public.aos_google_claim_sync_v1(text,integer)','execute')
     or has_function_privilege('authenticated','public.aos_google_claim_sync_v1(text,integer)','execute') then
    raise exception 'CLAIM_RPC_BROWSER_EXPOSED';
  end if;
end $$;

set role service_role;
select count(*) > 0 as claim_ok from public.aos_google_claim_sync_v1('ci-worker',10);
reset role;

select 'GOOGLE_DB_CONTRACT=PASS' as result;
