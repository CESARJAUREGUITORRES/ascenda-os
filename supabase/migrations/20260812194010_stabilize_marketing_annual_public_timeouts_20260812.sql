-- ASCENDA OS — Marketing annual public gateway timeout stabilization
-- Narrow function-local timeout only. Does not change the global anon role timeout.

alter function public.aos_marketing_historico_public_v2(integer)
  set statement_timeout = '8s';

alter function public.aos_marketing_ltv_public_v2(integer)
  set statement_timeout = '8s';
