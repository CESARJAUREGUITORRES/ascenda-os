begin;

-- CIA A4.2 · Human canary critical-lane timeout budget.
-- Scope is intentionally narrow: only RPCs required to open/work the one-contact canary.
-- No routing, audience, assignment, patient, appointment or sales data is changed.

alter function public.aos_callcenter_prepare_action_v1(text,text)
  set statement_timeout = '10s';

alter function public.aos_get_historial_paciente(text)
  set statement_timeout = '10s';

alter function public.aos_panel_asesor(text,text,text,text)
  set statement_timeout = '10s';

comment on function public.aos_callcenter_prepare_action_v1(text,text)
is 'CIA A4.2 critical lane: bounded 10s statement budget for one-contact Call Center preparation. Business logic unchanged.';

comment on function public.aos_get_historial_paciente(text)
is 'CIA A4.2 critical lane: bounded 10s statement budget for patient history hydration during human canary. Business logic unchanged.';

comment on function public.aos_panel_asesor(text,text,text,text)
is 'CIA A4.2 critical lane: bounded 10s statement budget for advisor panel hydration during human canary. Business logic unchanged.';

commit;
