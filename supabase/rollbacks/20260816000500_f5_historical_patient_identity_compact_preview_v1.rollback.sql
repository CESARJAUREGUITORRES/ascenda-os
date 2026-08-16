-- ASCENDA OS — F5 compact/preview pipeline recovery.
-- Fail closed: preserve staged source evidence and preview artifacts; revoke execution.

revoke all on function public.aos_f5_ingest_compact_rows_v1(text,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.aos_f5_rebuild_identity_preview_v1() from public,anon,authenticated,service_role;
revoke all on function public.aos_f5_ingest_source_rows_v1(text,jsonb) from public,anon,authenticated;

-- Existing expanded ingest stays private for controlled recovery/intake.
grant execute on function public.aos_f5_ingest_source_rows_v1(text,jsonb) to service_role;

insert into public.aos_security_log(usuario,accion,detalles)
values('SYSTEM','F5_COMPACT_PREVIEW_RECOVERY',jsonb_build_object(
  'mode','FAIL_CLOSED',
  'source_evidence_preserved',true,
  'preview_evidence_preserved',true,
  'canonical_patient_mutation',false,
  'at',now()
));
