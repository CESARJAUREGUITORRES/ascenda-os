-- Marketing V4.3 recovery: remove only the new read-only public wrapper.
drop function if exists public.aos_marketing_value_map_public_v43(integer,integer);
select pg_notify('pgrst','reload schema');
