-- LOOP 6 trigger compatibility hardening.
-- Some certified legacy trigger functions on aos_agenda_citas resolve public tables
-- through the caller search_path. Keep the browser/token wrappers closed, but let the
-- private core provide pg_catalog + public for those triggers.

alter function public.aos_callcenter_commit_action_core_v1(uuid,text,text,jsonb,text)
  set search_path = 'pg_catalog','public','pg_temp';
