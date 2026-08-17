\set ON_ERROR_STOP on

delete from public.aos_app_sessions_v3 where user_id in ('00000000-0000-4000-8000-000000009001','00000000-0000-4000-8000-000000009002','00000000-0000-4000-8000-000000009003');
delete from public.aos_usuarios where id in ('00000000-0000-4000-8000-000000009001','00000000-0000-4000-8000-000000009002','00000000-0000-4000-8000-000000009003');
insert into public.aos_usuarios(id,rol,activo,nivel_jerarquia) values
('00000000-0000-4000-8000-000000009001','admin',true,1),('00000000-0000-4000-8000-000000009002','asesor',true,3),('00000000-0000-4000-8000-000000009003','admin',true,1);
insert into public.aos_app_sessions_v3(token_hash,user_id,assurance_level,expires_at,revoked) values
(encode(extensions.digest('f9-admin-token-000000000000000000000000000001','sha256'),'hex'),'00000000-0000-4000-8000-000000009001','PASSWORD_2FA',now()+interval '1 hour',false),
(encode(extensions.digest('f9-user-token-0000000000000000000000000000002','sha256'),'hex'),'00000000-0000-4000-8000-000000009002','PASSWORD_2FA',now()+interval '1 hour',false),
(encode(extensions.digest('f9-weak-token-0000000000000000000000000000003','sha256'),'hex'),'00000000-0000-4000-8000-000000009003','PASSWORD_ONLY',now()+interval '1 hour',false);
delete from public.aos_sentinel_incidents_v1 where incident_id like 'SEN-2099-9%';
delete from public.aos_sentinel_alert_dispatches_v1 where channel='ascenda-in-app';
delete from public.aos_sentinel_maintenance_windows_v1 where reason_code='f9-inapp-zero-cost';

insert into public.aos_sentinel_incidents_v1(incident_id,incident_fingerprint,environment,domain,component,capability,failure_family,severity,status,opened_at,updated_at,last_signal_at,signal_count,reopened_count,signal_classes,signal_fingerprints,evidence_refs,correlation)
values('SEN-2099-9001','f9.inapp.p1','zero-cost','SENTINEL','alert-router','owner-notification','synthetic','P1','OPEN',now(),now(),now(),1,0,array['ERROR'],array['f9.inapp.p1.signal'],'[]'::jsonb,jsonb_build_object('release','ascenda-os@24a36b64ca85a856a5640f306435405c0b5d92ac','commit_sha','24a36b64ca85a856a5640f306435405c0b5d92ac','deployment_id','f9-zero-cost'));
do $$ begin if (select count(*) from public.aos_sentinel_alert_dispatches_v1 where incident_id='SEN-2099-9001' and channel='ascenda-in-app' and action='IMMEDIATE' and delivery_state='DELIVERED')<>1 then raise exception 'P1 delivery failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_P1=PASS

update public.aos_sentinel_incidents_v1 set signal_count=2,updated_at=clock_timestamp() where incident_id='SEN-2099-9001';
do $$ begin if (select count(*) from public.aos_sentinel_alert_dispatches_v1 where incident_id='SEN-2099-9001' and channel='ascenda-in-app' and action='IMMEDIATE' and severity='P1')<>1 then raise exception 'cooldown failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_COOLDOWN=PASS

update public.aos_sentinel_incidents_v1 set severity='P0',updated_at=clock_timestamp() where incident_id='SEN-2099-9001';
do $$ begin if (select count(*) from public.aos_sentinel_alert_dispatches_v1 where incident_id='SEN-2099-9001' and action='IMMEDIATE' and severity='P0' and delivery_state='DELIVERED')<>1 then raise exception 'escalation failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_ESCALATION=PASS

update public.aos_sentinel_incidents_v1 set status='RESOLVED',resolved_at=clock_timestamp(),updated_at=clock_timestamp() where incident_id='SEN-2099-9001';
do $$ begin if (select count(*) from public.aos_sentinel_alert_dispatches_v1 where incident_id='SEN-2099-9001' and action='RECOVERY' and delivery_state='DELIVERED')<>1 then raise exception 'recovery failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_RECOVERY=PASS
update public.aos_sentinel_incidents_v1 set updated_at=clock_timestamp() where incident_id='SEN-2099-9001';
do $$ begin if (select count(*) from public.aos_sentinel_alert_dispatches_v1 where incident_id='SEN-2099-9001' and action='RECOVERY')<>1 then raise exception 'recovery duplicated'; end if; end $$;
\echo SENTINEL_F9_INAPP_RECOVERY_ONCE=PASS

insert into public.aos_sentinel_maintenance_windows_v1(environment,domain,component,capability,reason_code,starts_at,ends_at,enabled) values('zero-cost','SENTINEL','maint-component',null,'f9-inapp-zero-cost',now()-interval '5 minutes',now()+interval '5 minutes',true);
insert into public.aos_sentinel_incidents_v1(incident_id,incident_fingerprint,environment,domain,component,capability,failure_family,severity,status,opened_at,updated_at,last_signal_at,signal_count,reopened_count,signal_classes,signal_fingerprints,evidence_refs)
values('SEN-2099-9002','f9.inapp.maint.p1','zero-cost','SENTINEL','maint-component','owner-notification','synthetic','P1','OPEN',now(),now(),now(),1,0,array['ERROR'],array['f9.maint.p1'],'[]'::jsonb);
do $$ begin if exists(select 1 from public.aos_sentinel_alert_dispatches_v1 where incident_id='SEN-2099-9002') then raise exception 'maintenance failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_MAINTENANCE=PASS
insert into public.aos_sentinel_incidents_v1(incident_id,incident_fingerprint,environment,domain,component,capability,failure_family,severity,status,opened_at,updated_at,last_signal_at,signal_count,reopened_count,signal_classes,signal_fingerprints,evidence_refs)
values('SEN-2099-9003','f9.inapp.maint.p0','zero-cost','SENTINEL','maint-component','owner-notification','synthetic','P0','OPEN',now(),now(),now(),1,0,array['ERROR'],array['f9.maint.p0'],'[]'::jsonb);
do $$ begin if (select count(*) from public.aos_sentinel_alert_dispatches_v1 where incident_id='SEN-2099-9003' and delivery_state='DELIVERED')<>1 then raise exception 'P0 bypass failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_P0_BYPASS=PASS

insert into public.aos_sentinel_incidents_v1(incident_id,incident_fingerprint,environment,domain,component,capability,failure_family,severity,status,opened_at,updated_at,last_signal_at,signal_count,reopened_count,signal_classes,signal_fingerprints,evidence_refs)
values('SEN-2099-9004','f9.inapp.p2','zero-cost','EMAIL','resend-gateway','send-progression','synthetic','P2','OPEN',now(),now(),now(),1,0,array['BUSINESS_HEALTH'],array['f9.p2'],'[]'::jsonb);
update public.aos_sentinel_alert_digest_items_v1 set bucket_start=now()-interval '20 minutes',bucket_end=now()-interval '5 minutes' where incident_id='SEN-2099-9004';
select public.aos_sentinel_inapp_flush_digests_v1(now());
do $$ begin if (select count(*) from public.aos_sentinel_alert_dispatches_v1 where action='DIGEST' and channel='ascenda-in-app' and delivery_state='DELIVERED' and digest_key in (select digest_key from public.aos_sentinel_alert_digest_items_v1 where incident_id='SEN-2099-9004'))<>1 then raise exception 'digest failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_DIGEST=PASS

do $$ begin if not (public.aos_sentinel_owner_feed_v1('f9-admin-token-000000000000000000000000000001',30)->>'ok')::boolean then raise exception 'admin auth failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_OWNER_AUTH=PASS
do $$ begin if (public.aos_sentinel_owner_feed_v1('f9-user-token-0000000000000000000000000000002',30)->>'ok')::boolean then raise exception 'nonadmin allowed'; end if; end $$;
\echo SENTINEL_F9_INAPP_NONADMIN_DENY=PASS
do $$ begin if (public.aos_sentinel_owner_feed_v1('f9-weak-token-0000000000000000000000000000003',30)->>'ok')::boolean then raise exception 'weak auth allowed'; end if; end $$;
\echo SENTINEL_F9_INAPP_WEAK_2FA_DENY=PASS
do $$ begin if (public.aos_sentinel_owner_feed_v1('invalid',30)->>'ok')::boolean then raise exception 'invalid auth allowed'; end if; end $$;
\echo SENTINEL_F9_INAPP_INVALID_DENY=PASS

select public.aos_sentinel_owner_mark_read_v1('f9-admin-token-000000000000000000000000000001',(select dispatch_id from public.aos_sentinel_alert_dispatches_v1 where incident_id='SEN-2099-9003' and delivery_state='DELIVERED' order by dispatch_id desc limit 1));
do $$ begin if (select count(*) from public.aos_sentinel_owner_notification_reads_v1 where actor_id='00000000-0000-4000-8000-000000009001')<1 then raise exception 'read receipt failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_READ_RECEIPT=PASS

select public.aos_sentinel_set_inapp_enabled_v1(false);
insert into public.aos_sentinel_incidents_v1(incident_id,incident_fingerprint,environment,domain,component,capability,failure_family,severity,status,opened_at,updated_at,last_signal_at,signal_count,reopened_count,signal_classes,signal_fingerprints,evidence_refs)
values('SEN-2099-9005','f9.inapp.killswitch','zero-cost','SENTINEL','alert-router','owner-notification','synthetic','P1','OPEN',now(),now(),now(),1,0,array['ERROR'],array['f9.kill'],'[]'::jsonb);
do $$ begin if exists(select 1 from public.aos_sentinel_alert_dispatches_v1 where incident_id='SEN-2099-9005') then raise exception 'kill switch failed'; end if; if not exists(select 1 from public.aos_sentinel_incidents_v1 where incident_id='SEN-2099-9005') then raise exception 'F8 blocked'; end if; end $$;
\echo SENTINEL_F9_INAPP_KILL_SWITCH=PASS
\echo SENTINEL_F9_INAPP_F8_SURVIVES_KILL=PASS
select public.aos_sentinel_set_inapp_enabled_v1(true);

do $$ begin if (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('aos_sentinel_alert_runtime_v1','aos_sentinel_owner_notification_reads_v1','aos_sentinel_alert_runtime_errors_v1') and c.relrowsecurity and c.relforcerowsecurity)<>3 then raise exception 'RLS/FORCE RLS failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_RLS=PASS
do $$ begin if exists(select 1 from information_schema.role_table_grants where table_schema='public' and table_name in ('aos_sentinel_alert_runtime_v1','aos_sentinel_owner_notification_reads_v1','aos_sentinel_alert_runtime_errors_v1') and grantee in ('anon','authenticated')) then raise exception 'browser ACL failed'; end if; end $$;
\echo SENTINEL_F9_INAPP_DIRECT_BROWSER_ACL=PASS
