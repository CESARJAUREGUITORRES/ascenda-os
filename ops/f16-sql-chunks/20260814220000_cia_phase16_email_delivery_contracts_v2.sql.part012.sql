  ) into v_auth_direct;

  select count(*)::integer into v_illegal
  from public.aos_cia_email_send_requests
  where eligibility_status <> 'ELIGIBLE' and state in ('QUEUED','DISPATCHING','ACCEPTED','DELIVERED');

  select * into v_release from public.aos_cia_email_release_state where singleton=true;
  v_ready := coalesce((v_f15->>'ready_for_f16')::boolean,false)
             and v_tables=6 and v_rls=6 and not v_anon_direct and not v_auth_direct and v_illegal=0
             and coalesce(v_release.gateway_active,false)
             and coalesce(v_release.provider_configured,false)
             and coalesce(v_release.webhook_verified,false)
             and coalesce(v_release.admin_ui_gateway_only,false)
             and coalesce(v_release.legacy_acl_hardened,false)
             and coalesce(v_release.canary_passed,false)
             and coalesce(v_release.rollback_verified,false);

  return jsonb_build_object(
    'ok',true,
    'status',case when v_ready then 'READY_F17_EMAIL_CERTIFIED' else 'IN_PROGRESS_DELIVERY_GOVERNANCE' end,
    'ready_for_f17',v_ready,
    'delivery_enabled',coalesce(v_release.gateway_active,false) and coalesce(v_release.provider_configured,false),
    'f15_ready',coalesce((v_f15->>'ready_for_f16')::boolean,false),
    'governed_tables',v_tables,'rls_tables',v_rls,
    'browser_direct_table_access',jsonb_build_object('anon',v_anon_direct,'authenticated',v_auth_direct),
    'illegal_send_states',v_illegal,
    'release_gates',jsonb_build_object(
      'gateway_active',coalesce(v_release.gateway_active,false),
      'provider_configured',coalesce(v_release.provider_configured,false),
      'webhook_verified',coalesce(v_release.webhook_verified,false),
      'admin_ui_gateway_only',coalesce(v_release.admin_ui_gateway_only,false),
      'legacy_acl_hardened',coalesce(v_release.legacy_acl_hardened,false),
      'canary_passed',coalesce(v_release.canary_passed,false),
      'rollback_verified',coalesce(v_release.rollback_verified,false)
    )
  );
end
$function$;

revoke all on function public.aos_cia_email_prepare_request_v2(uuid,uuid,text,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.aos_cia_email_queue_request_v2(uuid,uuid) from public,anon,authenticated;
revoke all on function public.aos_cia_email_claim_dispatch_v2(uuid) from public,anon,authenticated;
revoke all on function public.aos_cia_email_record_dispatch_result_v2(uuid,boolean,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.aos_cia_email_ingest_provider_event_v2(text,text,text,timestamptz,jsonb) from public,anon,authenticated;
revoke all on function public.aos_cia_email_release_mark_v1(text,boolean,text) from public,anon,authenticated;
