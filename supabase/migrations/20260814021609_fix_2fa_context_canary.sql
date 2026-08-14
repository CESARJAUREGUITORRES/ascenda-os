-- ASCENDA OS — controlled canary hotfix
-- Restores the authorization context lost after a successful 2FA verification.
-- Preserves the existing login side effects: one-time code consumption and security audit.

CREATE OR REPLACE FUNCTION public.aos_verificar_2fa(
  p_usuario text,
  p_codigo text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_auth record;
  v_user record;
  v_udata record;
  v_paneles text[];
BEGIN
  SELECT *
  INTO v_auth
  FROM public.aos_auth_codes
  WHERE upper(usuario) = upper(p_usuario)
    AND codigo = p_codigo
    AND usado = false
    AND expira_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_auth IS NULL THEN
    INSERT INTO public.aos_security_log (usuario, accion, detalles)
    VALUES (p_usuario, '2fa_failed', '{"codigo":"incorrecto o expirado"}'::jsonb);

    RETURN json_build_object(
      'ok', false,
      'error', 'Código incorrecto o expirado'
    );
  END IF;

  UPDATE public.aos_auth_codes
  SET usado = true
  WHERE id = v_auth.id;

  SELECT *
  INTO v_user
  FROM public.aos_rrhh
  WHERE upper(nombre) = upper(p_usuario)
    AND estado = 'ACTIVO'
  LIMIT 1;

  IF v_user IS NULL THEN
    INSERT INTO public.aos_security_log (usuario, accion, detalles)
    VALUES (p_usuario, '2fa_failed', '{"razon":"usuario activo no encontrado"}'::jsonb);

    RETURN json_build_object(
      'ok', false,
      'error', 'Usuario activo no encontrado'
    );
  END IF;

  SELECT *
  INTO v_udata
  FROM public.aos_usuarios
  WHERE upper(nombre) = upper(v_user.nombre)
  LIMIT 1;

  v_paneles := coalesce(v_udata.paneles_acceso, ARRAY[]::text[]);

  INSERT INTO public.aos_security_log (usuario, accion, detalles)
  VALUES (
    p_usuario,
    'login',
    json_build_object('method', '2fa_email')::jsonb
  );

  RETURN json_build_object(
    'ok', true,
    'codigo_asesor', v_user.codigo_asesor,
    'nombre', v_user.nombre,
    'apellido', coalesce(v_user.apellido, v_udata.cargo),
    'puesto', coalesce(v_udata.cargo, v_user.puesto),
    'sede', v_user.sede,
    'usuario', v_user.usuario,
    'permisos', coalesce(v_user.permisos, '{}'::jsonb),
    'paneles_acceso', to_json(v_paneles),
    'avatar_url', v_udata.avatar_url,
    'nivel', v_udata.nivel_jerarquia,
    'area', v_udata.area,
    'acceso_geo', v_udata.acceso_geo,
    'sedes_permitidas', to_json(coalesce(v_udata.sedes_permitidas, ARRAY[]::text[]))
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.aos_verificar_2fa(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.aos_verificar_2fa(text, text)
TO anon, authenticated, service_role;

COMMENT ON FUNCTION public.aos_verificar_2fa(text, text) IS
'ASCENDA login 2FA verifier. Returns the same session authorization context as aos_login_v2 after successful verification.';
