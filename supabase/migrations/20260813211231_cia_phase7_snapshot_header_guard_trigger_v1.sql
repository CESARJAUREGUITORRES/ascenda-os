-- REMOTE SYNC: already applied live as 20260813211231.
drop trigger if exists trg_aos_cia_snapshot_header_guard_v1 on public.aos_audiencia_snapshots;
create trigger trg_aos_cia_snapshot_header_guard_v1 before insert or update or delete on public.aos_audiencia_snapshots for each row execute function public.aos_cia_snapshot_header_guard_v1();