create or replace function public.aos_cia_preview_core_v2(p_keys text[])
returns table(contact_key text,identity_status text,identity_conflict boolean,contact_name text,patient_state text,raw_branch text,age_band text,value_tier text,lifecycle text,engagement text,traits text[],email_never_sent boolean)
language sql stable security invoker as $$
select k,p.identity_status,p.identity_conflict,
  nullif(btrim(concat_ws(' ',p.canonical_names,p.canonical_surnames)),'') contact_name,
  p.patient_state,p.raw_branch,
  case when p.age_years is null then null when p.age_years<18 then 'UNDER_18'
       when p.age_years<=24 then '18_24' when p.age_years<=34 then '25_34'
       when p.age_years<=44 then '35_44' when p.age_years<=54 then '45_54'
       when p.age_years<=64 then '55_64' else '65_PLUS' end::text,
  sg.value_tier,sg.lifecycle,sg.engagement,sg.traits,em.never_sent
from unnest(p_keys) k
left join public.aos_cia_profile_fast_v2 p on p.contact_key=k
left join public.aos_cia_segment_runtime_cache_v2 sg on sg.contact_key=k
left join public.aos_cia_email_runtime_cache_v2 em on em.contact_key=k;
$$;
revoke all on function public.aos_cia_preview_core_v2(text[]) from public,anon,authenticated;
grant execute on function public.aos_cia_preview_core_v2(text[]) to service_role;
