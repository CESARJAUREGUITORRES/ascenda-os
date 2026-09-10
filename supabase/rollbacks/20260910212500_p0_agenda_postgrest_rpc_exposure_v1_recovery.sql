-- P0 #492 recovery is intentionally non-destructive.
-- The underlying Agenda RPC predates this exposure repair and must remain present.
grant usage on schema public to anon, authenticated, service_role;
grant execute on function public.aos_agenda_set_status_v1(text,text,text,text,text)
  to anon, authenticated, service_role;
select pg_notify('pgrst','reload schema');
