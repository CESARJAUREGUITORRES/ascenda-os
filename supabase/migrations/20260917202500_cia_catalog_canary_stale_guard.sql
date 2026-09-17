-- CIA Audience Catalog V2 · stale-definition assignment guard
-- Prevents a persisted Audience whose display name matches an active governed preset
-- from being activated with a different filter definition. This specifically protects
-- human-canary and future assignment paths from legacy/mis-saved audience definitions.

begin;

create or replace function public.aos_cia_catalog_assignment_stale_guard_v1()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_name text;
  v_saved_filter jsonb;
  v_preset_filter jsonb;
  v_preset_key text;
begin
  -- Apply only to PACK-B human-canary plans for now. Future mass distribution will
  -- get its own activation policy gate rather than broadening this trigger silently.
  if not coalesce(new.metadata,'{}'::jsonb) @> jsonb_build_object('pack','B','canary',1) then
    return new;
  end if;

  select a.nombre,v.filter_dsl
    into v_name,v_saved_filter
  from public.aos_audiencia_activaciones x
  join public.aos_audiencias a on a.id=x.audiencia_id
  join public.aos_audiencia_versiones v on v.id=x.audiencia_version_id
  where x.id=new.activation_id;

  if v_name is null then
    return new;
  end if;

  select p.preset_key,p.dsl
    into v_preset_key,v_preset_filter
  from public.aos_audience_presets p
  where p.active=true and p.name=v_name
  order by p.registry_version desc,p.updated_at desc
  limit 1;

  if v_preset_key is not null and v_saved_filter is distinct from v_preset_filter then
    raise exception 'CATALOG_AUDIENCE_STALE: %',v_preset_key using errcode='P0001';
  end if;

  return new;
end
$function$;

revoke all on function public.aos_cia_catalog_assignment_stale_guard_v1() from public,anon,authenticated;

drop trigger if exists trg_aos_cia_catalog_assignment_stale_guard_v1 on public.aos_cia_assignment_plans;
create trigger trg_aos_cia_catalog_assignment_stale_guard_v1
before insert on public.aos_cia_assignment_plans
for each row execute function public.aos_cia_catalog_assignment_stale_guard_v1();

comment on function public.aos_cia_catalog_assignment_stale_guard_v1()
is 'Fail-closed guard: PACK-B canary cannot activate a persisted Audience whose name matches an active governed preset but whose saved filter differs from that preset.';

commit;
