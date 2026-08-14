-- Preserve table defaults/generated values when secured INSERT payload omits columns.
begin;

create or replace function public.aos_secure_write_v2(
  p_token text,
  p_table text,
  p_action text,
  p_match jsonb default '{}'::jsonb,
  p_data jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid; v_user record; v_family text;
  v_action text:=upper(trim(coalesce(p_action,'')));
  v_allowed_match text[]; v_key text;
  v_where text:=''; v_set text:=''; v_cols text:=''; v_vals text:='';
  v_rows jsonb:='[]'::jsonb; v_sql text;
  v_all_keys integer; v_real_keys integer;
begin
  v_uid:=public.aos_app_actor_v3(p_token,null,false);
  if v_uid is null then return jsonb_build_object('ok',false,'error','UNAUTHORIZED'); end if;
  select id,rol,nivel_jerarquia,paneles_acceso into v_user from public.aos_usuarios where id=v_uid and activo=true;

  if p_table in ('aos_catalogo_categorias','aos_catalogo_servicios','aos_catalogo_toppings','aos_catalogo_productos_detalle') then
    v_family:='CATALOG';
    if lower(coalesce(v_user.rol,''))<>'admin' or not (coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['admin-config']::text[]) then
      return jsonb_build_object('ok',false,'error','CATALOG_ADMIN_REQUIRED');
    end if;
    v_allowed_match:=case when p_table='aos_catalogo_servicios' then array['id','categoria','tipo']::text[] else array['id']::text[] end;
  elsif p_table in ('aos_planes_trabajo','aos_plan_trabajo_items') then
    v_family:='PLAN';
    if not (coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['advisor-attendance']::text[] or coalesce(v_user.paneles_acceso,'{}'::text[]) @> array['admin-agenda']::text[]) then
      return jsonb_build_object('ok',false,'error','PLAN_ACCESS_REQUIRED');
    end if;
    v_allowed_match:=case when p_table='aos_planes_trabajo' then array['id','numero_limpio','fecha']::text[] else array['id','plan_id','numero_limpio','fecha']::text[] end;
  else
    return jsonb_build_object('ok',false,'error','TABLE_NOT_ALLOWED');
  end if;

  if v_action not in ('INSERT','PATCH','DELETE') then return jsonb_build_object('ok',false,'error','ACTION_NOT_ALLOWED'); end if;
  if v_action in ('PATCH','DELETE') and coalesce(jsonb_object_length(p_match),0)=0 then return jsonb_build_object('ok',false,'error','MATCH_REQUIRED'); end if;

  for v_key in select jsonb_object_keys(coalesce(p_match,'{}'::jsonb)) loop
    if not (v_key=any(v_allowed_match)) then return jsonb_build_object('ok',false,'error','MATCH_NOT_ALLOWED','field',v_key); end if;
    if v_where<>'' then v_where:=v_where||' and '; end if;
    v_where:=v_where||format('%I::text=%L',v_key,p_match->>v_key);
  end loop;

  if v_action in ('INSERT','PATCH') then
    select count(*) into v_all_keys from jsonb_object_keys(coalesce(p_data,'{}'::jsonb));
    select count(*) into v_real_keys from jsonb_object_keys(coalesce(p_data,'{}'::jsonb)) k
      join information_schema.columns c on c.table_schema='public' and c.table_name=p_table and c.column_name=k;
    if v_all_keys=0 or v_all_keys<>v_real_keys then return jsonb_build_object('ok',false,'error','FIELD_NOT_ALLOWED'); end if;
  end if;

  if v_action='INSERT' then
    for v_key in select jsonb_object_keys(p_data) loop
      if v_cols<>'' then v_cols:=v_cols||',';v_vals:=v_vals||','; end if;
      v_cols:=v_cols||format('%I',v_key);
      v_vals:=v_vals||format('(jsonb_populate_record(null::public.%I,$1)).%I',p_table,v_key);
    end loop;
    v_sql:=format('with ins as (insert into public.%I as t (%s) select %s returning t.*) select coalesce(jsonb_agg(to_jsonb(ins)),''[]''::jsonb) from ins',p_table,v_cols,v_vals);
    execute v_sql using p_data into v_rows;
  elsif v_action='PATCH' then
    for v_key in select jsonb_object_keys(p_data) loop
      if v_set<>'' then v_set:=v_set||','; end if;
      v_set:=v_set||format('%I=(jsonb_populate_record(t,$1)).%I',v_key,v_key);
    end loop;
    v_sql:=format('with upd as (update public.%I as t set %s where %s returning t.*) select coalesce(jsonb_agg(to_jsonb(upd)),''[]''::jsonb) from upd',p_table,v_set,v_where);
    execute v_sql using p_data into v_rows;
  else
    v_sql:=format('with del as (delete from public.%I as t where %s returning t.*) select coalesce(jsonb_agg(to_jsonb(del)),''[]''::jsonb) from del',p_table,v_where);
    execute v_sql into v_rows;
  end if;

  insert into public.aos_security_log(usuario,accion,detalles)
  select au.nombre,'SECURED_WRITE_V2',jsonb_build_object('family',v_family,'table',p_table,'action',v_action,'rows',jsonb_array_length(v_rows)) from public.aos_usuarios au where au.id=v_uid;
  return jsonb_build_object('ok',true,'rows',v_rows);
exception when others then
  return jsonb_build_object('ok',false,'error','WRITE_REJECTED','detail',sqlstate);
end
$function$;

revoke all on function public.aos_secure_write_v2(text,text,text,jsonb,jsonb) from public;
grant execute on function public.aos_secure_write_v2(text,text,text,jsonb,jsonb) to anon,authenticated,service_role;

commit;
