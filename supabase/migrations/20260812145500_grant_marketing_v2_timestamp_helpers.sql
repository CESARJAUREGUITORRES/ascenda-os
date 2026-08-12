-- ASCENDA OS — Marketing V2 runtime permissions
-- These helpers only normalize event timestamps from arguments.
-- They are SECURITY INVOKER, STABLE and do not read/write tables.

grant execute on function public.aos_lead_event_ts(date, timestamptz, timestamptz)
  to anon, authenticated;

grant execute on function public.aos_llamada_event_ts(date, text, timestamptz, timestamptz, timestamptz)
  to anon, authenticated;
