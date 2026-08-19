-- REV-F5.6 transition: F5.5 permanently-false apply eligibility becomes
-- conditionally true only after a complete approved LOW-risk field review.

alter table public.aos_f5_enrichment_preview_v1
  drop constraint if exists aos_f5_enrichment_preview_v1_apply_eligible_check;

alter table public.aos_f5_enrichment_preview_v1
  add constraint aos_f5_enrichment_preview_v1_apply_eligible_check
  check (
    apply_eligible is false
    or (
      apply_eligible is true
      and review_decision='APPROVE_FIELD'
      and reviewed_by is not null
      and reviewed_at is not null
      and reviewed_snapshot_hash is not null
      and policy_apply_allowed is true
      and policy_risk_class='LOW'
      and field_name in ('Sexo','distrito','departamento','ciudad')
    )
  );

alter table public.aos_f5_enrichment_preview_v1
  drop constraint if exists aos_f5_enrichment_preview_v1_apply_state_check;

alter table public.aos_f5_enrichment_preview_v1
  add constraint aos_f5_enrichment_preview_v1_apply_state_check
  check (
    (applied_at is null and apply_event_id is null)
    or (
      applied_at is not null
      and apply_event_id is not null
      and apply_eligible is true
      and review_decision='APPROVE_FIELD'
    )
  );

insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
values('APPLY_ELIGIBILITY_TRANSITION_INSTALLED','F5','REV-F5.6',jsonb_build_object(
  'default_apply_eligible',false,
  'requires_approved_review',true,
  'requires_low_risk_policy',true,
  'allowed_fields',jsonb_build_array('Sexo','distrito','departamento','ciudad'),
  'installed_at',now()
));
