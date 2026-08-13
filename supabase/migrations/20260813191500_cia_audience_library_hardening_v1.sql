-- ASCENDA CIA Phase 6 hardening — referential integrity + append-only audit + least privilege.

alter table public.aos_audiencias
  drop constraint if exists aos_audiencias_current_version_fk;

alter table public.aos_audiencias
  add constraint aos_audiencias_current_version_fk
  foreign key (id,current_version)
  references public.aos_audiencia_versiones(audiencia_id,version)
  deferrable initially deferred;

create or replace function public.aos_cia_audience_audit_guard_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  raise exception using errcode='55000',message='AUDIENCE_AUDIT_IMMUTABLE';
end;
$$;

revoke all on function public.aos_cia_audience_audit_guard_v1() from public, anon, authenticated;

drop trigger if exists trg_aos_cia_audience_audit_guard_v1 on public.aos_audiencia_audit;
create trigger trg_aos_cia_audience_audit_guard_v1
before update or delete on public.aos_audiencia_audit
for each row execute function public.aos_cia_audience_audit_guard_v1();

-- The service role consumes the library through SECURITY DEFINER RPCs.
-- Direct table mutation is intentionally not part of the Phase 6 contract.
revoke all on table public.aos_audiencias from service_role;
revoke all on table public.aos_audiencia_versiones from service_role;
revoke all on table public.aos_audiencia_audit from service_role;
revoke all on sequence public.aos_audiencia_audit_id_seq from service_role;

grant select on table public.aos_audiencias to service_role;
grant select on table public.aos_audiencia_versiones to service_role;
grant select on table public.aos_audiencia_audit to service_role;
