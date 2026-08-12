-- Do not expose the full normalized phone in the client-level Marketing audit JSON.
CREATE OR REPLACE FUNCTION public.aos_marketing_intent_detail_public_v3(
  p_mes integer,
  p_anio integer
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  d date;
  nd date;
  result jsonb;
BEGIN
  IF p_mes IS NULL OR p_mes < 1 OR p_mes > 12 THEN
    RAISE EXCEPTION 'Mes fuera de rango';
  END IF;
  IF p_anio IS NULL OR p_anio < 2020 OR p_anio > extract(year from current_date)::integer + 1 THEN
    RAISE EXCEPTION 'Año fuera de rango';
  END IF;

  d := make_date(p_anio,p_mes,1);
  nd := (d + interval '1 month')::date;

  WITH attrs AS MATERIALIZED (
    SELECT a.*
    FROM public.aos_marketing_attribution_v2_preview(d,current_date) a
    WHERE a.lead_fecha>=d AND a.lead_fecha<nd
  ), grouped AS (
    SELECT
      a.numero_limpio,
      a.lead_id,
      min(a.lead_fecha) lead_fecha,
      max(a.lead_anuncio) lead_anuncio,
      max(a.lead_tratamiento) lead_tratamiento,
      upper(coalesce(nullif(trim(a.tratamiento_compra),''),'SIN TRATAMIENTO')) tratamiento_compra,
      trim(concat_ws(' ',max(v.nombres),max(v.apellidos))) cliente,
      right(coalesce(a.numero_limpio,''),4) telefono_ult4,
      count(*)::bigint operaciones,
      coalesce(sum(a.monto),0)::numeric facturacion,
      string_agg(distinct coalesce(nullif(trim(v.descripcion),''),a.tratamiento_compra), ' · ' order by coalesce(nullif(trim(v.descripcion),''),a.tratamiento_compra)) descripciones,
      string_agg(a.venta_id, ' · ' order by a.venta_fecha,a.venta_pk) venta_ids,
      min(a.confidence)::integer confianza_min,
      bool_or(a.tipo_atribucion='REACTIVACION') tiene_reactivacion
    FROM attrs a
    JOIN public.aos_ventas v ON v.id=a.venta_pk
    GROUP BY a.numero_limpio,a.lead_id,upper(coalesce(nullif(trim(a.tratamiento_compra),''),'SIN TRATAMIENTO'))
  ), safe AS (
    SELECT jsonb_build_object(
      'cliente',cliente,
      'telefono_ult4',telefono_ult4,
      'lead_id',lead_id,
      'lead_fecha',lead_fecha,
      'lead_anuncio',lead_anuncio,
      'lead_tratamiento',lead_tratamiento,
      'tratamiento_compra',tratamiento_compra,
      'operaciones',operaciones,
      'facturacion',facturacion,
      'descripciones',descripciones,
      'venta_ids',venta_ids,
      'confianza_min',confianza_min,
      'tiene_reactivacion',tiene_reactivacion
    ) item,
    cliente,lead_id,tratamiento_compra
    FROM grouped
  )
  SELECT coalesce(jsonb_agg(item ORDER BY cliente,lead_id,tratamiento_compra),'[]'::jsonb)
  INTO result
  FROM safe;

  RETURN result;
END;
$function$;

REVOKE ALL ON FUNCTION public.aos_marketing_intent_detail_public_v3(integer,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.aos_marketing_intent_detail_public_v3(integer,integer) TO anon, authenticated;
