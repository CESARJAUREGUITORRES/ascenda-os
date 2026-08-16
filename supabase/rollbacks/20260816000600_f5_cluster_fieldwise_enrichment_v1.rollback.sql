-- ASCENDA OS — F5 field-wise enrichment recovery.
-- Remove only the derived preview trigger/function. Preserve source evidence and previews.

drop trigger if exists trg_aos_f5_refresh_cluster_profile_v1 on public.aos_f5_identity_cluster_members_v1;
revoke all on function public.aos_f5_refresh_cluster_profile_v1() from public,anon,authenticated,service_role;
drop function if exists public.aos_f5_refresh_cluster_profile_v1();

insert into public.aos_security_log(usuario,accion,detalles)
values('SYSTEM','F5_FIELDWISE_ENRICHMENT_RECOVERY',jsonb_build_object(
  'source_evidence_preserved',true,
  'preview_evidence_preserved',true,
  'canonical_patient_mutation',false,
  'at',now()
));
