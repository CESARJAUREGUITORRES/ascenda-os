-- Phase 8: Phase 7 resolver consumes filter_dsl.root, not the wrapper document.
create or replace function public.aos_cia_activation_member_keys_v1(p_activation_id uuid)
returns table(contact_key text)
language plpgsql
stable
set search_path=public
as $$
declare
  cfg record;
  v_filter jsonb;
  keys text[];
begin
  select c.mode,c.snapshot_id,a.audiencia_version_id
  into cfg
  from public.aos_audiencia_activaciones a
  join public.aos_audiencia_activacion_config c on c.activacion_id=a.id
  where a.id=p_activation_id;
  if cfg.mode is null then raise exception 'ACTIVATION_NOT_FOUND'; end if;
  if cfg.mode='BATCH' then
    return query select m.contact_key from public.aos_audiencia_snapshot_miembros m where m.snapshot_id=cfg.snapshot_id order by m.contact_key;
    return;
  end if;
  select v.filter_dsl into v_filter from public.aos_audiencia_versiones v where v.id=cfg.audiencia_version_id;
  if v_filter is null then raise exception 'ACTIVATION_VERSION_NOT_FOUND'; end if;
  keys:=public.aos_cia_audience_resolve_node_v2(v_filter->'root',1);
  return query select x from unnest(coalesce(keys,array[]::text[])) x order by x;
end;
$$;
