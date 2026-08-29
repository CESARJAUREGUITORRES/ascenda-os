begin;

alter table public.aos_wa_ai_runs_v1
  drop constraint if exists aos_wa_ai_runs_v1_task_check;

alter table public.aos_wa_ai_runs_v1
  add constraint aos_wa_ai_runs_v1_task_check
  check (task in ('SALES_COPILOT','SALES_PLAYBOOK','MODEL_EVAL'));

commit;
