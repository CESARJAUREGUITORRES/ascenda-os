-- REMOTE SYNC: already applied live as 20260813211302.
drop trigger if exists trg_aos_cia_snapshot_member_guard_v1 on public.aos_audiencia_snapshot_miembros;
create trigger trg_aos_cia_snapshot_member_guard_v1 before insert or update or delete on public.aos_audiencia_snapshot_miembros for each row execute function public.aos_cia_snapshot_member_guard_v1();