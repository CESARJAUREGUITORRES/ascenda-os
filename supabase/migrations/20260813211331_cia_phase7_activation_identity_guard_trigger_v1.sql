-- REMOTE SYNC: already applied live as 20260813211331.
drop trigger if exists trg_aos_cia_activation_identity_guard_v1 on public.aos_audiencia_activaciones;
create trigger trg_aos_cia_activation_identity_guard_v1 before insert or update or delete on public.aos_audiencia_activaciones for each row execute function public.aos_cia_activation_identity_guard_v1();