-- ASCENDA OS — P0 auth outage hotfix
-- Root cause: fn_audit_trigger used an unqualified aos_log_auditoria reference.
-- Auth V3 runs with search_path='', and opportunistic password migration updates aos_rrhh,
-- firing trg_brain_audit. The trigger then failed to resolve the existing audit table,
-- aborting login for every active legacy-password user.

create or replace function public.fn_audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_new jsonb := null;
  v_old jsonb := null;
  v_id text := null;
  v_user text;
begin
  begin
    v_user := pg_catalog.current_setting('request.jwt.claims', true)::jsonb->>'email';
  exception when others then
    v_user := current_user;
  end;

  if TG_OP in ('INSERT','UPDATE') then
    v_new := pg_catalog.jsonb_strip_nulls(to_jsonb(NEW)) - array['observacion','obs','foto_url','notas'];
    if pg_catalog.length(v_new::text) > 400 then
      v_new := pg_catalog.jsonb_build_object('truncado', pg_catalog.left(v_new::text,200));
    end if;
    v_id := coalesce(
      (to_jsonb(NEW)->>'id')::text,
      (to_jsonb(NEW)->>'venta_id')::text,
      (to_jsonb(NEW)->>'numero_limpio')::text
    );
  end if;

  if TG_OP in ('UPDATE','DELETE') then
    v_old := pg_catalog.jsonb_build_object('id',(to_jsonb(OLD)->>'id')::text);
    if v_id is null then v_id := (to_jsonb(OLD)->>'id')::text; end if;
  end if;

  insert into public.aos_log_auditoria(ts,tabla,accion,asesor,registro_id,datos_new,datos_old,metadata)
  values(
    pg_catalog.now(),TG_TABLE_NAME,TG_OP,coalesce(nullif(v_user,''),'sistema'),
    v_id,v_new,v_old,pg_catalog.jsonb_build_object('op_at',pg_catalog.now()::text)
  );

  if TG_OP='DELETE' then return OLD; end if;
  return NEW;
end;
$function$;
