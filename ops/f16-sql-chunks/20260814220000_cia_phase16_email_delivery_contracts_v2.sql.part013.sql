revoke all on function public.aos_cia_email_admin_gateway_v2(text,text,jsonb) from public;
revoke all on function public.aos_cia_email_f17_readiness_v1() from public,anon,authenticated;

grant execute on function public.aos_cia_email_claim_dispatch_v2(uuid) to service_role;
grant execute on function public.aos_cia_email_record_dispatch_result_v2(uuid,boolean,text,text,text,jsonb) to service_role;
grant execute on function public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb) to service_role;
grant execute on function public.aos_cia_email_release_mark_v1(text,boolean,text) to service_role;
grant execute on function public.aos_cia_email_admin_gateway_v2(text,text,jsonb) to anon,authenticated,service_role;
grant execute on function public.aos_cia_email_f17_readiness_v1() to service_role;

comment on function public.aos_cia_email_claim_dispatch_v2(uuid) is 'F16 service-role dispatch claim. Revalidates eligibility before provider delivery and returns one idempotent provider intent.';
comment on function public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb) is 'F16 service-role provider outcome ingestion after server cryptographic webhook verification.';
comment on table public.aos_cia_email_release_state is 'F16 production release evidence gates. Defaults false; F17 readiness cannot pass before real canary/rollback/ACL evidence.';

commit;
