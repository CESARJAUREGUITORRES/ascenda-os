-- REV-F6.6 recovery: remove observation-only handoff objects.
begin;

drop function if exists public.aos_rev_f6_6_contract_v1();
drop function if exists public.aos_sentinel_rev_f6_6_incident_candidates_v1();
drop function if exists public.aos_sentinel_rev_f6_6_integrity_health_v1();
drop function if exists public.aos_sentinel_rev_f6_6_snapshot_v1();
drop function if exists public.aos_sentinel_rev_f6_6_evaluate_v1(jsonb);
drop function if exists public.aos_sentinel_rev_f6_6_signal_envelope_v1(text,text,text,text,text,text,jsonb,jsonb,text,text,text,jsonb);
drop function if exists public.aos_rev_f6_6_integrity_baseline_v1();

commit;
