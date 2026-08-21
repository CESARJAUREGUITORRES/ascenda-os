-- REV-F6.7 recovery — restore certified F6.4 browser gateway topology.

begin;

drop function if exists public.aos_sales_intelligence_gateway(text,integer,text,text);

alter function public.aos_sales_intelligence_gateway_v2_f6_7_base(text,integer,text,text)
  rename to aos_sales_intelligence_gateway;

revoke all on function public.aos_sales_intelligence_gateway(text,integer,text,text) from public;
grant execute on function public.aos_sales_intelligence_gateway(text,integer,text,text)
  to anon,authenticated,service_role;

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
declare v_auth_probe jsonb;
begin
  v_auth_probe:=public.aos_sales_intelligence_gateway(p_token,p_anio,p_sede,p_asesor);
  if coalesce(v_auth_probe->>'error','')='UNAUTHORIZED'
     or coalesce((v_auth_probe->>'ok')::boolean,true)=false then
    return jsonb_build_object('ok',false,'error','UNAUTHORIZED');
  end if;
  return public.aos_rev_sales_intelligence_v3(p_anio,p_sede,p_asesor);
end;
$$;

revoke all on function public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text) from public;
grant execute on function public.aos_rev_sales_intelligence_v3_gateway(text,integer,text,text)
  to anon,authenticated,service_role;

do $$
begin
  if to_regclass('public.aos_paneles_disponibles') is not null then
    update public.aos_paneles_disponibles
    set nombre='Sales Intelligence V2',
        descripcion='Métricas financieras de solo lectura. Requiere rol administrador, 2FA y autorización explícita.'
    where id='admin-sales-intelligence';
  end if;
end $$;

commit;
