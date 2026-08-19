-- REV-F5.6 event-ledger compatibility.
-- Legacy v1 events are cluster-scoped (field_name IS NULL): keep one active event per cluster.
-- F5.6 v2 events are field-scoped: uniqueness is already enforced by
-- aos_f5_one_active_field_apply_v2(cluster_id,field_name).

drop index if exists public.aos_f5_apply_event_active_uq;

create unique index aos_f5_apply_event_active_uq
  on public.aos_f5_canonical_apply_events_v1(cluster_id)
  where rolled_back_at is null and field_name is null;

insert into public.aos_f5_audit_v1(action,entity_type,entity_key,details)
values('APPLY_EVENT_SCOPE_UNIQUENESS_SPLIT','F5','REV-F5.6',jsonb_build_object(
  'legacy_scope','ONE_ACTIVE_EVENT_PER_CLUSTER_WHEN_FIELD_NULL',
  'v2_scope','ONE_ACTIVE_EVENT_PER_CLUSTER_FIELD',
  'idempotency_weakened',false,
  'installed_at',now()
));
