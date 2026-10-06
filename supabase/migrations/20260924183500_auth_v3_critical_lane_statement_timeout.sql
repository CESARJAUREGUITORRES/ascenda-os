-- ASCENDA CLINIC P0 — Auth V3 critical lane timeout hardening.
-- Incident: production login requests through the anon PostgREST role were
-- cancelled by the role-level statement_timeout=3s during transient DB/PostgREST
-- degradation, while the same operational database continued serving other
-- critical RPCs. The same-origin Railway proxy has a 12s upstream deadline.
--
-- Keep the auth contract, grants, RLS posture, password/2FA logic and session
-- semantics unchanged. Only give the two Auth V3 RPCs a bounded function-local
-- 10s statement window so they are not killed by anon's generic 3s ceiling.

alter function public.aos_login_v3(text,text)
  set statement_timeout = '10s';

alter function public.aos_verificar_2fa_v3(uuid,text)
  set statement_timeout = '10s';
