-- WA-4C: align append-only AI audit task enum with deterministic playbook paths.
-- No runtime activation. No existing rows mutated.
begin;

alter table public.aos_wa_ai_runs_v1
  drop constraint if exists aos_wa_ai_runs_v1_task_check;

alter table public.aos_wa_ai_runs_v1
  add constraint aos_wa_ai_runs_v1_task_check
  check (task in ('SALES_COPILOT','SALES_PLAYBOOK','MODEL_EVAL'));

comment on constraint aos_wa_ai_runs_v1_task_check on public.aos_wa_ai_runs_v1 is
  'WA-4C audit task contract: model suggestions, deterministic playbook/fail-closed paths, and model evaluation.';

commit;
