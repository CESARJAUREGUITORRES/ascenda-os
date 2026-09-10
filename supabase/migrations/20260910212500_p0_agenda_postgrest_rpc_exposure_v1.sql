-- P0 #492 · Agenda governed RPC PostgREST exposure recovery.
-- No business data mutation. Reassert API privileges and force PostgREST to
-- rebuild its schema cache so the already-certified strong-session RPC is routable.
do $$
begin
  if to_regprocedure('public.aos_agenda_set_status_v1(text,text,text,text,text)') is null then
    raise exception 'AGENDA_STATUS_RPC_MISSING';
  end if;
end
$$;

grant usage on schema public to anon, authenticated, service_role;
grant execute on function public.aos_agenda_set_status_v1(text,text,text,text,text)
  to anon, authenticated, service_role;

comment on function public.aos_agenda_set_status_v1(text,text,text,text,text)
is 'Agenda governed status V1. P0 #492 reasserted PostgREST exposure; strong-session/2FA authority and atomic attention sync remain unchanged.';

select pg_notify('pgrst','reload schema');
