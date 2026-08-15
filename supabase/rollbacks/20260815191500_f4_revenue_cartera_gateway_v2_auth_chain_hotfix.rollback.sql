-- ASCENDA OS — fail-closed recovery for F4 Cartera Auth V3 chain hotfix.
-- If the compatibility read alias must be withdrawn, disable only the old public
-- read name. Keep the self-contained V2 Auth V3 gateway available; never restore
-- the broken V2 -> legacy -> finance-session authentication loop.

begin;

revoke all on function public.aos_cartera_gateway(text,text,text,integer,integer)
  from public,anon,authenticated;

revoke all on function public.aos_cartera_gateway_v2(text,text,text,integer,integer)
  from public;
grant execute on function public.aos_cartera_gateway_v2(text,text,text,integer,integer)
  to anon,authenticated;

notify pgrst, 'reload schema';

commit;
