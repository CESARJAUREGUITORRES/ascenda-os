-- ASCENDA OS CIA V3 — F16 Email preview/request contracts v1
-- No provider dispatch. No legacy ACL changes. No Email send is performed by this migration.

create or replace function public.aos_cia_email_eligibility_v1(
  p_activation_id uuid,
  p_contact_key text,
  p_purpose text default 'MARKETING'
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $function$
declare
  v_purpose text := upper(trim(coalesce(p_purpose,'')));
  v_contact text := trim(coalesce(p_contact_key,''));
  v_channel text;
  v_activation_state text;
  v_source record;
  v_control record;
  v_consent text := 'UNKNOWN';
  v_status text := 'UNKNOWN';
  v_reason text := 'UNKNOWN';
  v_freshness text := 'UNKNOWN';
  v_member boolean := false;
begin
  if p_activation_id is null then
    return jsonb_build_object('ok',false,'eligibility_status','BLOCKED','reason_code','ACTIVATION_REQUIRED','send_allowed',false);
  end if;
  if v_contact = '' then
    return jsonb_build_object('ok',false,'eligibility_status','BLOCKED','reason_code','CONTACT_REQUIRED','send_allowed',false);
  end if;
  if v_purpose not in ('AUTH','TRANSACTIONAL','MARKETING','OPERATIONAL') then
    return jsonb_build_object('ok',false,'eligibility_status','BLOCKED','reason_code','INVALID_PURPOSE','send_allowed',false);
  end if;

  select upper(trim(c.channel)), st.estado
    into v_channel, v_activation_state
  from public.aos_audiencia_activacion_config c
  join public.aos_audiencia_activacion_estado st on st.activacion_id=c.activacion_id
  where c.activacion_id=p_activation_id;

  if v_channel is null then
    return jsonb_build_object('ok',false,'eligibility_status','BLOCKED','reason_code','ACTIVATION_NOT_FOUND','send_allowed',false);
  end if;
