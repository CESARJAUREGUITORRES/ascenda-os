-- REMOTE SYNC: already applied live as 20260813211428.
drop trigger if exists trg_aos_cia_activation_state_guard_v1 on public.aos_audiencia_activacion_estado;
create trigger trg_aos_cia_activation_state_guard_v1 before insert or update or delete on public.aos_audiencia_activacion_estado for each row execute function public.aos_cia_activation_state_guard_v1();