  p_template_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_tpl record;
begin
  if p_actor_user_id is null then return jsonb_build_object('ok',false,'error','ACTOR_REQUIRED'); end if;
  select * into v_tpl from public.aos_cia_email_template_versions where id=p_template_version_id for update;
  if v_tpl.id is null then return jsonb_build_object('ok',false,'error','TEMPLATE_VERSION_NOT_FOUND'); end if;
  if v_tpl.state='RETIRED' then return jsonb_build_object('ok',false,'error','TEMPLATE_VERSION_RETIRED'); end if;

  update public.aos_cia_email_template_versions
     set state='RETIRED', retired_at=now()
   where template_key=v_tpl.template_key and id<>v_tpl.id and state='ACTIVE';

  update public.aos_cia_email_template_versions
     set state='ACTIVE', activated_at=coalesce(activated_at,now()), retired_at=null
   where id=v_tpl.id;

  return jsonb_build_object('ok',true,'template_version_id',v_tpl.id,'template_key',v_tpl.template_key,'version',v_tpl.version,'state','ACTIVE','actor_user_id',p_actor_user_id);
end
$function$;

create or replace function public.aos_cia_email_prepare_request_v1(
  p_actor_user_id uuid,
  p_activation_id uuid,
  p_contact_key text,
  p_template_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_tpl record;
  v_elig jsonb;
  v_activation_state text;
  v_key text;
  v_existing uuid;
  v_id uuid;
