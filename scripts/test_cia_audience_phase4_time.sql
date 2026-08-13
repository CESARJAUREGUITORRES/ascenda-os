-- ASCENDA OS — CIA Phase 4 future-window fact tests
begin;

do $$ declare c bigint;d bigint;f jsonb; begin
 f:='{"version":1,"root":{"op":"AND","rules":[{"field":"appointments.days_until_next","operator":"between","value":[0,7]}]}}';
 c:=(public.aos_cia_audience_count_v1(f)->>'count')::bigint;
 select count(*) into d from public.aos_cia_audience_source_v1_1 where days_until_next_appointment between 0 and 7;
 if c<>d then raise exception 'P4 next appointment window mismatch %/%',c,d; end if;
end $$;

do $$ declare n int; begin
 select count(*) into n from public.aos_cia_audience_source_v1_1 where days_until_next_appointment is not null and days_until_next_appointment<0;
 if n<>0 then raise exception 'P4 next appointment fact contains negative days=%',n; end if;
end $$;

rollback;
