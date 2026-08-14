-- REMOTE SYNC: already applied live as 20260813211408.
drop trigger if exists trg_aos_cia_activation_config_immutable_v1 on public.aos_audiencia_activacion_config;
create trigger trg_aos_cia_activation_config_immutable_v1 before update or delete on public.aos_audiencia_activacion_config for each row execute function public.aos_cia_activation_config_immutable_v1();