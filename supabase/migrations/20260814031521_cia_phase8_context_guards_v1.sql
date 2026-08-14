-- Phase 8 immutable policy/binding guards.

create or replace function public.aos_cia_phase8_immutable_guard_v1()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  raise exception 'CIA_PHASE8_IMMUTABLE';
end;
$$;

create or replace function public.aos_cia_phase8_context_binding_validate_v1()
returns trigger
language plpgsql
set search_path=public
as $$
declare
  p record;
  a_channel text;
begin
  select * into p
  from public.aos_cia_context_policies
  where policy_key=new.policy_key and version=new.policy_version;
  if p.policy_key is null then raise exception 'CONTEXT_POLICY_NOT_FOUND'; end if;
  if p.status<>'ACTIVE' then raise exception 'CONTEXT_POLICY_NOT_ACTIVE'; end if;
  if p.effective_from>now() or (p.effective_to is not null and p.effective_to<=now()) then raise exception 'CONTEXT_POLICY_NOT_EFFECTIVE'; end if;

  select c.channel into a_channel
  from public.aos_audiencia_activacion_config c
  where c.activacion_id=new.activation_id;
  if a_channel is null then raise exception 'ACTIVATION_CONFIG_NOT_FOUND'; end if;
  if upper(a_channel)<>p.channel then raise exception 'CONTEXT_POLICY_CHANNEL_MISMATCH'; end if;
  return new;
end;
$$;

drop trigger if exists trg_aos_cia_phase8_policy_immutable_v1 on public.aos_cia_context_policies;
create trigger trg_aos_cia_phase8_policy_immutable_v1
before update or delete on public.aos_cia_context_policies
for each row execute function public.aos_cia_phase8_immutable_guard_v1();

drop trigger if exists trg_aos_cia_phase8_binding_validate_v1 on public.aos_audiencia_activacion_context;
create trigger trg_aos_cia_phase8_binding_validate_v1
before insert on public.aos_audiencia_activacion_context
for each row execute function public.aos_cia_phase8_context_binding_validate_v1();

drop trigger if exists trg_aos_cia_phase8_binding_immutable_v1 on public.aos_audiencia_activacion_context;
create trigger trg_aos_cia_phase8_binding_immutable_v1
before update or delete on public.aos_audiencia_activacion_context
for each row execute function public.aos_cia_phase8_immutable_guard_v1();
