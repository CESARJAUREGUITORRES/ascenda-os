)
returns jsonb
language plpgsql
stable
set search_path = ''
as $function$
declare
  v_limit integer := greatest(1,least(coalesce(p_limit,50),100));
  v_offset integer := greatest(0,coalesce(p_offset,0));
  v_total integer;
  v_items jsonb;
begin
  select count(*)::integer into v_total
  from public.aos_cia_activation_member_keys_v1(p_activation_id);

  select coalesce(jsonb_agg(x.item order by x.contact_key),'[]'::jsonb)
    into v_items
  from (
    select m.contact_key,
           public.aos_cia_email_eligibility_v1(p_activation_id,m.contact_key,p_purpose) as item
    from public.aos_cia_activation_member_keys_v1(p_activation_id) m
    order by m.contact_key
    limit v_limit offset v_offset
  ) x;

  return jsonb_build_object(
    'ok',true,
    'activation_id',p_activation_id,
    'purpose',upper(trim(coalesce(p_purpose,'MARKETING'))),
    'total_members',v_total,
    'limit',v_limit,
    'offset',v_offset,
    'items',v_items,
    'send_allowed',false,
    'preview_only',true
  );
exception when others then
  if sqlerrm like '%ACTIVATION_NOT_FOUND%' then
    return jsonb_build_object('ok',false,'error','ACTIVATION_NOT_FOUND','send_allowed',false);
  end if;
  raise;
end
$function$;

create or replace function public.aos_cia_email_template_version_create_v1(
