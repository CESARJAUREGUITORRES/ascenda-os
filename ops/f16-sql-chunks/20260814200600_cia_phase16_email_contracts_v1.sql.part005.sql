  p_actor_user_id uuid,
  p_template_key text,
  p_purpose text,
  p_subject_template text,
  p_html_template text,
  p_variable_keys text[] default '{}'::text[],
  p_legacy_template_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_key text := lower(trim(coalesce(p_template_key,'')));
  v_purpose text := upper(trim(coalesce(p_purpose,'')));
  v_version integer;
  v_digest text;
  v_id uuid;
begin
  if p_actor_user_id is null then return jsonb_build_object('ok',false,'error','ACTOR_REQUIRED'); end if;
  if v_key !~ '^[a-z0-9][a-z0-9._-]{1,79}$' then return jsonb_build_object('ok',false,'error','INVALID_TEMPLATE_KEY'); end if;
  if v_purpose not in ('AUTH','TRANSACTIONAL','MARKETING','OPERATIONAL') then return jsonb_build_object('ok',false,'error','INVALID_PURPOSE'); end if;
  if nullif(trim(coalesce(p_subject_template,'')),'') is null then return jsonb_build_object('ok',false,'error','SUBJECT_REQUIRED'); end if;
  if nullif(trim(coalesce(p_html_template,'')),'') is null then return jsonb_build_object('ok',false,'error','HTML_REQUIRED'); end if;
  if length(p_subject_template) > 500 or length(p_html_template) > 500000 then return jsonb_build_object('ok',false,'error','TEMPLATE_TOO_LARGE'); end if;

  perform pg_advisory_xact_lock(hashtext('F16_EMAIL_TEMPLATE:'||v_key));
  select coalesce(max(version),0)+1 into v_version
  from public.aos_cia_email_template_versions where template_key=v_key;

  v_digest := md5(v_key||'|'||v_purpose||'|'||p_subject_template||'|'||p_html_template||'|'||array_to_string(coalesce(p_variable_keys,'{}'::text[]),','));

  insert into public.aos_cia_email_template_versions(
    template_key,version,purpose,subject_template,html_template,variable_keys,content_digest,state,legacy_template_id,created_by_user_id
  ) values(
    v_key,v_version,v_purpose,p_subject_template,p_html_template,coalesce(p_variable_keys,'{}'::text[]),v_digest,'SHADOW',p_legacy_template_id,p_actor_user_id
  ) returning id into v_id;

  return jsonb_build_object('ok',true,'template_version_id',v_id,'template_key',v_key,'version',v_version,'digest',v_digest,'state','SHADOW');
end
$function$;

create or replace function public.aos_cia_email_template_version_activate_v1(
  p_actor_user_id uuid,
