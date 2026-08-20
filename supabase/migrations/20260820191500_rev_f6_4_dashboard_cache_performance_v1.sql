-- REV-F6.4 LIVE performance read-model hotfix.
-- Keep the deep calculation service-only and expose bounded cached payloads for current filter space.

begin;

alter function public.aos_rev_sales_intelligence_v3(integer,text,text) rename to aos_rev_sales_intelligence_v3_uncached_f6_4_base;
revoke all on function public.aos_rev_sales_intelligence_v3_uncached_f6_4_base(integer,text,text) from public,anon,authenticated;
grant execute on function public.aos_rev_sales_intelligence_v3_uncached_f6_4_base(integer,text,text) to service_role;

create table if not exists public.aos_rev_si_dashboard_cache_v1 (
  anio integer not null,
  sede text not null default '',
  advisor text not null default '',
  payload jsonb not null,
  generated_at timestamptz not null default clock_timestamp(),
  primary key(anio,sede,advisor)
);
comment on table public.aos_rev_si_dashboard_cache_v1 is
'REV-F6.4 zero-PII bounded dashboard payload cache. Refreshed from governed read models; no business-source mutation.';
revoke all on public.aos_rev_si_dashboard_cache_v1 from public,anon,authenticated;
grant select,insert,update,delete on public.aos_rev_si_dashboard_cache_v1 to service_role;

create or replace function public.aos_rev_si_cache_filter_v1(p_anio integer,p_sede text default '',p_asesor text default '')
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_sede text:=upper(trim(coalesce(p_sede,'')));
  v_asesor text:=trim(coalesce(p_asesor,''));
  v_payload jsonb;
begin
  v_payload:=public.aos_rev_sales_intelligence_v3_uncached_f6_4_base(p_anio,v_sede,v_asesor);
  insert into public.aos_rev_si_dashboard_cache_v1(anio,sede,advisor,payload,generated_at)
  values(p_anio,v_sede,v_asesor,v_payload,clock_timestamp())
  on conflict(anio,sede,advisor) do update set payload=excluded.payload,generated_at=excluded.generated_at;
  return v_payload;
end;
$$;
revoke all on function public.aos_rev_si_cache_filter_v1(integer,text,text) from public,anon,authenticated;
grant execute on function public.aos_rev_si_cache_filter_v1(integer,text,text) to service_role;

create or replace function public.aos_rev_si_rebuild_dashboard_cache_v1()
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  r record;
  v_count integer:=0;
begin
  delete from public.aos_rev_si_dashboard_cache_v1 where anio=2026;
  for r in
    with filters as (
      select ''::text sede,''::text advisor
      union select distinct s.sede,''::text from public.aos_rev_si_sales_fact_v1 s where s.sale_year=2026
      union select distinct ''::text,s.advisor from public.aos_rev_si_sales_fact_v1 s where s.sale_year=2026
      union select distinct s.sede,s.advisor from public.aos_rev_si_sales_fact_v1 s where s.sale_year=2026
    ) select sede,advisor from filters order by sede,advisor
  loop
    perform public.aos_rev_si_cache_filter_v1(2026,r.sede,r.advisor);
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('ok',true,'cache_rows',v_count,'generated_at',clock_timestamp());
end;
$$;
revoke all on function public.aos_rev_si_rebuild_dashboard_cache_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_si_rebuild_dashboard_cache_v1() to service_role;

select public.aos_rev_si_rebuild_dashboard_cache_v1();

create or replace function public.aos_rev_sales_intelligence_v3(p_anio integer,p_sede text default '',p_asesor text default '')
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_sede text:=upper(trim(coalesce(p_sede,'')));
  v_asesor text:=trim(coalesce(p_asesor,''));
  v_payload jsonb;
begin
  if p_anio not between 2020 and 2100 then return jsonb_build_object('ok',false,'error','INVALID_YEAR'); end if;
  if v_sede not in ('','SAN ISIDRO','PUEBLO LIBRE') then return jsonb_build_object('ok',false,'error','INVALID_FILTER'); end if;
  if p_anio=2026 then
    select c.payload into v_payload from public.aos_rev_si_dashboard_cache_v1 c
    where c.anio=p_anio and c.sede=v_sede and c.advisor=v_asesor;
    if v_payload is not null then
      return jsonb_set(v_payload,'{business_date_lima}',to_jsonb(public.aos_rev_business_date_lima_v1()),true);
    end if;
  end if;
  return public.aos_rev_sales_intelligence_v3_uncached_f6_4_base(p_anio,v_sede,v_asesor);
end;
$$;
revoke all on function public.aos_rev_sales_intelligence_v3(integer,text,text) from public,anon,authenticated;
grant execute on function public.aos_rev_sales_intelligence_v3(integer,text,text) to service_role;

create or replace function public.aos_rev_si_refresh_v1()
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
begin
  refresh materialized view public.aos_rev_si_sales_fact_v1;
  refresh materialized view public.aos_rev_si_monthly_v1;
  refresh materialized view public.aos_rev_si_patient_value_v1;
  refresh materialized view public.aos_rev_si_cohort_month_v1;
  refresh materialized view public.aos_rev_si_product_transition_v1;
  refresh materialized view public.aos_rev_si_acquisition_fact_v1;
  perform public.aos_rev_si_rebuild_dashboard_cache_v1();
  return public.aos_rev_f6_4_contract_v1();
end;
$$;
revoke all on function public.aos_rev_si_refresh_v1() from public,anon,authenticated;
grant execute on function public.aos_rev_si_refresh_v1() to service_role;

commit;
