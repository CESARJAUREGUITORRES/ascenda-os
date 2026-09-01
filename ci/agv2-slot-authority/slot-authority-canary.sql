\set ON_ERROR_STOP on

-- Critical families must resolve governed timing from active catalog rows.
do $$
declare
  v_id uuid;
  v jsonb;
  v_cap text;
begin
  foreach v_cap in array array['TOXINA','HIFU','HIDROFACIAL','CRIOLIPOLISIS'] loop
    select s.id into v_id
    from public.aos_catalogo_servicios s
    where upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
      and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
      and public.aos_booking_capability_for_service_v1(s.id)=v_cap
    order by s.nombre limit 1;
    if v_id is null then raise exception 'L2_CANARY_CAPABILITY_NOT_FOUND:%',v_cap; end if;
    v:=public.aos_booking_timing_for_service_v2(v_id);
    if coalesce((v->>'ok')::boolean,false) is not true then raise exception 'L2_TIMING_NOT_READY:%:%',v_cap,v; end if;
    if (v->>'reservation_grid_min')::int<>30 or (v->>'soft_capacity')::int<>5 or (v->>'overflow_capacity')::int<>6 then
      raise exception 'L2_CAPACITY_CONTRACT_BAD:%:%',v_cap,v;
    end if;
    if coalesce((v->>'duration_blocks_future_booking')::boolean,true) is true then raise exception 'L2_DURATION_BLOCKING_BAD:%',v_cap; end if;
  end loop;

  select s.id into v_id
  from public.aos_catalogo_servicios s
  where upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
    and public.aos_booking_procedure_for_service_v1(s.id)->>'procedure_key'='CELLBOOSTER GLOW'
  order by s.nombre limit 1;
  if v_id is null then raise exception 'L2_CELLBOOSTER_NOT_FOUND'; end if;
  v:=public.aos_booking_timing_for_service_v2(v_id);
  if (v->>'execution_default_min')::int<>30 then raise exception 'L2_CELLBOOSTER_DURATION_BAD:%',v; end if;

  select s.id into v_id
  from public.aos_catalogo_servicios s
  where upper(coalesce(s.estado,'ACTIVO'))='ACTIVO'
    and upper(coalesce(s.tipo,'SERVICIO'))='SERVICIO'
    and public.aos_booking_procedure_for_service_v1(s.id)->>'procedure_key'='FACIAL COREANO'
  order by s.nombre limit 1;
  if v_id is not null then
    v:=public.aos_booking_timing_for_service_v2(v_id);
    if (v->>'execution_min_min')::int<>90 or (v->>'execution_max_min')::int<>120 then raise exception 'L2_COREANO_DURATION_BAD:%',v; end if;
  end if;
end
$$;

-- No test may create a real appointment. L2 is timing/availability authority only.
select 'AGV2_L2_SLOT_AUTHORITY_CANARY_PASS' as result;
