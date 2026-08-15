-- ASCENDA OS — F5 Historical Patient Identity foundation recovery.
-- Fail closed: preserve staged evidence; never expose PII or mutate canonical patients.

alter table if exists public.aos_f5_source_batches_v1 enable row level security;
alter table if exists public.aos_f5_patient_source_rows_v1 enable row level security;
alter table if exists public.aos_f5_identity_clusters_v1 enable row level security;
alter table if exists public.aos_f5_identity_cluster_members_v1 enable row level security;
alter table if exists public.aos_f5_patient_link_preview_v1 enable row level security;
alter table if exists public.aos_f5_audit_v1 enable row level security;

revoke all on table public.aos_f5_source_batches_v1 from public, anon, authenticated;
revoke all on table public.aos_f5_patient_source_rows_v1 from public, anon, authenticated;
revoke all on table public.aos_f5_identity_clusters_v1 from public, anon, authenticated;
revoke all on table public.aos_f5_identity_cluster_members_v1 from public, anon, authenticated;
revoke all on table public.aos_f5_patient_link_preview_v1 from public, anon, authenticated;
revoke all on table public.aos_f5_audit_v1 from public, anon, authenticated;

revoke all on sequence public.aos_f5_patient_source_rows_v1_id_seq from public, anon, authenticated;
revoke all on sequence public.aos_f5_audit_v1_id_seq from public, anon, authenticated;

insert into public.aos_security_log(usuario,accion,detalles)
values('SYSTEM','F5_IDENTITY_FOUNDATION_RECOVERY',jsonb_build_object('mode','FAIL_CLOSED_PRESERVE_EVIDENCE','at',now()));
