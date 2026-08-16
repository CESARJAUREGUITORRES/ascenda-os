\set ON_ERROR_STOP on

DO $$
DECLARE
  role_name text;
BEGIN
  FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
    IF has_table_privilege(role_name, 'public.aos_plantillas_whatsapp', 'INSERT') THEN
      RAISE EXCEPTION '% must not INSERT aos_plantillas_whatsapp', role_name;
    END IF;
    IF has_table_privilege(role_name, 'public.aos_plantillas_whatsapp', 'UPDATE') THEN
      RAISE EXCEPTION '% must not UPDATE aos_plantillas_whatsapp', role_name;
    END IF;
    IF has_table_privilege(role_name, 'public.aos_plantillas_whatsapp', 'DELETE') THEN
      RAISE EXCEPTION '% must not DELETE aos_plantillas_whatsapp', role_name;
    END IF;
    IF has_table_privilege(role_name, 'public.aos_plantillas_whatsapp', 'TRUNCATE') THEN
      RAISE EXCEPTION '% must not TRUNCATE aos_plantillas_whatsapp', role_name;
    END IF;
    IF has_table_privilege(role_name, 'public.aos_plantillas_whatsapp', 'REFERENCES') THEN
      RAISE EXCEPTION '% must not REFERENCES aos_plantillas_whatsapp', role_name;
    END IF;
    IF has_table_privilege(role_name, 'public.aos_plantillas_whatsapp', 'TRIGGER') THEN
      RAISE EXCEPTION '% must not TRIGGER aos_plantillas_whatsapp', role_name;
    END IF;
    IF NOT has_table_privilege(role_name, 'public.aos_plantillas_whatsapp', 'SELECT') THEN
      RAISE EXCEPTION '% SELECT compatibility must remain until gateway cutover', role_name;
    END IF;
  END LOOP;
END $$;

select 'F17 legacy ACL negative contract PASS' as result;
