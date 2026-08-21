-- REV-F6.7 — final UI/performance/acceptance gateway cutover.
-- Keeps the same-origin server route unchanged while upgrading its existing RPC target
-- to a V3+legacy-compatible payload. No patient/sale/F3/F4/F5 business mutation.

begin;

do $$
begin
  if to_regprocedure('public.aos_sales_intelligence_gateway_v2_f6_7_base(text,integer,text,text)') is null then
    if to_regprocedure('public.aos_sales_intelligence_gateway(text,integer,text,text)') is null then
      raise exception 'REV_F6_7_LEGACY_GATEWAY_REQUIRED';
    end if;
    alter function public.aos_sales_intelligence_gateway(text,integer,text,text)
      rename to aos_sales_intelligence_gateway_v2_f6_7_base;
  end if;
end $$;

revoke all on function public.aos_sales_intelligence_gateway_v2_f6_7_base(text,integer,text,text)
  from public,anon,authenticated;
grant execute on function public.aos_sales_intelligence_gateway_v2_f6_7_base(text,integer,text,text)
  to service_role;

create or replace function public.aos_rev_sales_intelligence_v3_gateway(
  p_token text,
  p_anio integer,
  p_sede text default '',
  p_asesor text default ''
) returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_legacy jsonb;
  v_v3 jsonb;
begin
  -- The certified V2 gateway remains the authorization + compatibility base.
  v_legacy:=public.aos_sales_intelligence_gateway_v2_f6_7_base(
    p_token,p_anio,p_sede,p_asesor
  );

  if coalesce(v_legacy->>'error','')<>''
     or coalesce((v_legacy->>'ok')::boolean,true)=false then
    return v_legacy;
  end if;

  v_v3:=public.aos_rev_sales_intelligence_v3(p_anio,p_sede,p_asesor);
  if coalesce((v_v3->>'ok')::boolean,false)=false then
    return v_v3;
  end if;

  -- JSONB concatenation keeps the known V2 keys for backwards compatibility
  -- and overlays the governed V3 analytical/trust contract for F6.7 UI.
  return v_legacy || v_v3 || jsonb_build_object(
    'api_version','V3',
    'ui_contract','REV-F6.7_SALES_INTELLIGENCE_UI_V1',
    'legacy_compatibility',true,
    'transport','SAME_ORIGIN_F4_PROXY',
    'read_only',true
  );
end;
$$;

comment on function public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text) is
'REV-F6.7 governed Sales Intelligence V3 browser gateway. Reuses certified V2 authorization, preserves legacy response keys, adds V3 metric-trust metadata; read-only.';
revoke all on function public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text) from public;
grant execute on function public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text)
  to anon,authenticated,service_role;

-- Preserve the exact RPC name used by the same-origin F4 proxy.
create or replace function public.aos_sales_intelligence_gateway(
  p_token text,
  p_anio integer,
  p_sede text default '',
  p_asesor text default ''
) returns jsonb
language sql
volatile
security definer
set search_path=''
as $$
  select public.aos_rev_sales_intelligence_v3_gateway(
    p_token,p_anio,p_sede,p_asesor
  );
$$;

comment on function public.aos_sales_intelligence_gateway(text,integer,text,text) is
'REV-F6.7 same-origin compatibility entrypoint. Returns V3 governed payload while retaining certified V2 keys; authorization remains admin+2FA.';
revoke all on function public.aos_sales_intelligence_gateway(text,integer,text,text) from public;
grant execute on function public.aos_sales_intelligence_gateway(text,integer,text,text)
  to anon,authenticated,service_role;

-- UI catalog metadata only; no business fact mutation.
do $$
begin
  if to_regclass('public.aos_paneles_disponibles') is not null then
    update public.aos_paneles_disponibles
    set nombre='Sales Intelligence V3',
        descripcion='Inteligencia comercial de solo lectura con cobertura, confianza, frescura y tamaño de muestra. Requiere administrador + 2FA.'
    where id='admin-sales-intelligence';
  end if;
end $$;

commit;
