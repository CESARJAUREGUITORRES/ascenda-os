-- ASCENDA OS Phase 7 — canonical executable source for live migration 20260813214724.
-- The Git connector blocks these read-only function bodies under supabase/migrations;
-- the matching migration file is therefore a history pointer to this controlled source.

create or replace function public.aos_cia_activation_list_internal_v1(p_include_terminal boolean default true,p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql set search_path=public as $$
declare lim integer:=greatest(1,least(coalesce(p_limit,50),100)); offv integer:=greatest(0,coalesce(p_offset,0)); total integer; items jsonb;
begin
 select count(*)::integer into total from public.aos_audiencia_activaciones a join public.aos_audiencia_activacion_estado st on st.activacion_id=a.id where coalesce(p_include_terminal,true) or st.estado not in ('COMPLETED','CANCELLED');
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into items from (select a.id,a.audiencia_id,av.version as audience_version,au.nombre as audience_name,c.nombre,c.purpose,c.channel,c.mode,c.baseline_count,c.baseline_resolved_at,c.snapshot_id,st.estado,st.started_at,st.ended_at,st.updated_at,s.member_count as snapshot_member_count,s.membership_hash,s.resolved_at as snapshot_resolved_at,cu.nombre as created_by,uu.nombre as updated_by,a.created_at from public.aos_audiencia_activaciones a join public.aos_audiencia_versiones av on av.id=a.audiencia_version_id join public.aos_audiencias au on au.id=a.audiencia_id join public.aos_audiencia_activacion_config c on c.activacion_id=a.id join public.aos_audiencia_activacion_estado st on st.activacion_id=a.id left join public.aos_audiencia_snapshots s on s.id=c.snapshot_id left join public.aos_usuarios cu on cu.id=c.created_by_user_id left join public.aos_usuarios uu on uu.id=st.updated_by_user_id where coalesce(p_include_terminal,true) or st.estado not in ('COMPLETED','CANCELLED') order by a.created_at desc limit lim offset offv) q;
 return jsonb_build_object('ok',true,'items',items,'total',total,'limit',lim,'offset',offv,'context_only',true);
end;$$;

create or replace function public.aos_cia_activation_get_internal_v1(p_activation_id uuid)
returns jsonb language plpgsql set search_path=public as $$
declare r record; events jsonb; curcnt integer; cntj jsonb;
begin
 select a.id,a.audiencia_id,a.audiencia_version_id,av.version as audience_version,av.filter_dsl,au.nombre as audience_name,c.snapshot_id,c.nombre,c.purpose,c.channel,c.mode,c.baseline_count,c.baseline_resolved_at,c.metadata,c.created_by_user_id,c.created_at,st.estado,st.updated_by_user_id,st.updated_at,st.started_at,st.ended_at,s.member_count as snapshot_member_count,s.membership_hash,s.filter_hash,s.resolved_at as snapshot_resolved_at,s.sealed_at into r from public.aos_audiencia_activaciones a join public.aos_audiencia_versiones av on av.id=a.audiencia_version_id join public.aos_audiencias au on au.id=a.audiencia_id join public.aos_audiencia_activacion_config c on c.activacion_id=a.id join public.aos_audiencia_activacion_estado st on st.activacion_id=a.id left join public.aos_audiencia_snapshots s on s.id=c.snapshot_id where a.id=p_activation_id;
 if r.id is null then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_FOUND'); end if;
 if r.mode='BATCH' then curcnt:=coalesce(r.snapshot_member_count,0); else cntj:=public.aos_cia_audience_count_v2(r.filter_dsl); curcnt:=coalesce((cntj->>'count')::integer,0); end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'event_type',e.event_type,'from_state',e.from_state,'to_state',e.to_state,'actor',u.nombre,'created_at',e.created_at,'metadata',e.metadata) order by e.id),'[]'::jsonb) into events from public.aos_audiencia_activacion_eventos e left join public.aos_usuarios u on u.id=e.actor_user_id where e.activacion_id=p_activation_id;
 return jsonb_build_object('ok',true,'activation',jsonb_build_object('id',r.id,'audience_id',r.audiencia_id,'audience_name',r.audience_name,'audience_version_id',r.audiencia_version_id,'audience_version',r.audience_version,'name',r.nombre,'purpose',r.purpose,'channel',r.channel,'mode',r.mode,'state',r.estado,'baseline_count',r.baseline_count,'baseline_resolved_at',r.baseline_resolved_at,'current_count',curcnt,'count_semantics',case when r.mode='BATCH' then 'FROZEN_SNAPSHOT' else 'DYNAMIC_LIVE' end,'context_only',true,'started_at',r.started_at,'ended_at',r.ended_at,'updated_at',r.updated_at,'metadata',r.metadata),'snapshot',case when r.snapshot_id is null then null else jsonb_build_object('id',r.snapshot_id,'member_count',r.snapshot_member_count,'membership_hash',r.membership_hash,'filter_hash',r.filter_hash,'resolved_at',r.snapshot_resolved_at,'sealed_at',r.sealed_at) end,'events',events);
end;$$;

create or replace function public.aos_cia_activation_preview_internal_v1(p_activation_id uuid,p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql set search_path=public as $$
declare r record; lim integer:=greatest(1,least(coalesce(p_limit,50),100)); offv integer:=greatest(0,coalesce(p_offset,0)); items jsonb;
begin
 select c.mode,c.snapshot_id,av.filter_dsl,s.member_count into r from public.aos_audiencia_activaciones a join public.aos_audiencia_activacion_config c on c.activacion_id=a.id join public.aos_audiencia_versiones av on av.id=a.audiencia_version_id left join public.aos_audiencia_snapshots s on s.id=c.snapshot_id where a.id=p_activation_id;
 if r.mode is null then return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_FOUND'); end if;
 if r.mode='DYNAMIC' then return public.aos_cia_audience_preview_v2(r.filter_dsl,lim,offv)||jsonb_build_object('activation_id',p_activation_id,'membership_mode','DYNAMIC_LIVE','facts_mode','LIVE','context_only',true); end if;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into items from (select m.contact_key,m.identity_status,m.identity_conflict,concat_ws(' ',s.canonical_names,s.canonical_surnames) as name,s.canonical_email as email,s.crm_branch as branch,s.value_tier,s.lifecycle,s.engagement,s.latest_interest,s.latest_call_status,s.last_call_at,s.sale_count,s.revenue_lifetime,s.pending_followup_count as pending_followups,s.overdue_followup_count as overdue_followups,s.has_future_appointment,s.next_appointment_at from public.aos_audiencia_snapshot_miembros m left join public.aos_cia_audience_source_v1 s on s.contact_key=m.contact_key where m.snapshot_id=r.snapshot_id order by m.contact_key limit lim offset offv) q;
 return jsonb_build_object('ok',true,'activation_id',p_activation_id,'count',coalesce(r.member_count,0),'items',items,'limit',lim,'offset',offv,'membership_mode','FROZEN_SNAPSHOT','facts_mode','LIVE','context_only',true);
end;$$;

create or replace function public.aos_cia_snapshot_list_internal_v1(p_audience_id uuid default null,p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql set search_path=public as $$
declare lim integer:=greatest(1,least(coalesce(p_limit,50),100)); offv integer:=greatest(0,coalesce(p_offset,0)); total integer; items jsonb;
begin
 select count(*)::integer into total from public.aos_audiencia_snapshots s where p_audience_id is null or s.audiencia_id=p_audience_id;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into items from (select s.id,s.audiencia_id,a.nombre as audience_name,v.version as audience_version,s.estado,s.member_count,s.membership_hash,s.filter_hash,s.resolved_at,s.sealed_at,u.nombre as created_by,s.created_at from public.aos_audiencia_snapshots s join public.aos_audiencias a on a.id=s.audiencia_id join public.aos_audiencia_versiones v on v.id=s.audiencia_version_id left join public.aos_usuarios u on u.id=s.created_by_user_id where p_audience_id is null or s.audiencia_id=p_audience_id order by s.created_at desc limit lim offset offv) q;
 return jsonb_build_object('ok',true,'items',items,'total',total,'limit',lim,'offset',offv);
end;$$;
