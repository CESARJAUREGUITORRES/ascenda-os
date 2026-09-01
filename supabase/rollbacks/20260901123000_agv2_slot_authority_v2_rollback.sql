begin;

-- Restore L1 selected-slot authority to the existing WA/public availability V2.
create or replace function public.aos_booking_resolve_selected_slot_v2(
  p_treatment_id uuid,
  p_date date,
  p_site text,
  p_time time,
  p_professional_id text default null,
  p_slot_role text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','extensions','pg_temp'
as $$
declare
  v_t public.aos_catalogo_servicios%rowtype;
  v_site text;
  v_role text;
  v_prof text:=nullif(btrim(coalesce(p_professional_id,'')),'');
  v_av jsonb;
  v_slot jsonb;
  v_doc boolean;
  v_nurse boolean;
begin
  select * into v_t from public.aos_catalogo_servicios
  where id=p_treatment_id and upper(coalesce(estado,'ACTIVO'))='ACTIVO' and upper(coalesce(tipo,'SERVICIO'))='SERVICIO';
  if not found then return jsonb_build_object('ok',false,'error','AGV2_TREATMENT_NOT_ACTIVE'); end if;
  v_site:=upper(replace(btrim(coalesce(p_site,'')),'_',' '));
  if p_date is null or p_time is null or v_site not in ('SAN ISIDRO','PUEBLO LIBRE') then return jsonb_build_object('ok',false,'error','AGV2_DATE_TIME_SITE_INVALID'); end if;
  if p_date<current_date then return jsonb_build_object('ok',false,'error','AGV2_DATE_IN_PAST'); end if;
  if extract(isodow from p_date)=7 then return jsonb_build_object('ok',false,'error','AGV2_SUNDAY_CLOSED'); end if;
  v_doc:=coalesce(v_t.requiere_doctora,false); v_nurse:=coalesce(v_t.requiere_enfermeria,false); v_role:=upper(btrim(coalesce(p_slot_role,'')));
  if v_role='' then if v_doc and v_nurse then v_role:=case when v_prof is null then 'ENFERMERIA' else 'DOCTORA' end; elsif v_doc then v_role:='DOCTORA'; elsif v_nurse then v_role:='ENFERMERIA'; end if; end if;
  if v_role not in ('DOCTORA','ENFERMERIA') then return jsonb_build_object('ok',false,'error','AGV2_SLOT_ROLE_REQUIRED'); end if;
  if v_role='DOCTORA' and not v_doc then return jsonb_build_object('ok',false,'error','AGV2_ROLE_NOT_ALLOWED'); end if;
  if v_role='ENFERMERIA' and not v_nurse then return jsonb_build_object('ok',false,'error','AGV2_ROLE_NOT_ALLOWED'); end if;
  if v_role='DOCTORA' and v_prof is null then return jsonb_build_object('ok',false,'error','AGV2_EXACT_PROVIDER_REQUIRED'); end if;
  if v_role='ENFERMERIA' then v_prof:=null; end if;
  v_av:=coalesce(public.aos_booking_availability_v2(v_t.id,p_date,v_site,v_prof),'{}'::jsonb);
  if coalesce((v_av->>'ok')::boolean,false) is not true then return jsonb_build_object('ok',false,'error','AGV2_AUTHORITY_BLOCKED','authority_status',coalesce(v_av->>'status','UNKNOWN'),'requires_human',true); end if;
  select s into v_slot from jsonb_array_elements(coalesce(v_av->'slots','[]'::jsonb)) s
  where s->>'hora'=to_char(p_time,'HH24:MI') and upper(coalesce(s->>'role',''))=v_role and coalesce((s->>'disponible')::boolean,false)=true and (v_role='ENFERMERIA' or s->>'professional_id'=v_prof) limit 1;
  if v_slot is null then return jsonb_build_object('ok',false,'error','AGV2_SLOT_NO_LONGER_AVAILABLE','requires_reselection',true); end if;
  return jsonb_build_object('ok',true,'role',v_role,'booking_mode',case when v_role='DOCTORA' then 'EXACT_PROVIDER' else 'SITE_POOL' end,'professional_id',case when v_role='DOCTORA' then v_prof else null end,'professional_ref',case when v_role='DOCTORA' then v_prof else 'POOL:'||replace(v_site,' ','_') end,'professional_name',case when v_role='DOCTORA' then v_slot->>'professional_name' else 'Enfermería' end,'site',v_site,'date',p_date,'time',to_char(p_time,'HH24:MI'),'authority_status',v_av->>'status');
end
$$;

revoke all on function public.aos_booking_resolve_selected_slot_v2(uuid,date,text,time,text,text) from public,anon,authenticated;
grant execute on function public.aos_booking_resolve_selected_slot_v2(uuid,date,text,time,text,text) to service_role;

drop function if exists public.aos_booking_slot_authority_v2(uuid,date,text,text);
drop function if exists public.aos_booking_timing_for_service_v2(uuid);
drop table if exists public.aos_booking_timing_authority_v2;

commit;