-- ASCENDA OS — F5 field-wise enrichment evidence v1
-- Preserve the latest non-null source evidence per profile field inside each cluster.
-- Operates only on private F5 cluster preview state; never mutates canonical patients.

create or replace function public.aos_f5_refresh_cluster_profile_v1()
returns trigger
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_profile jsonb;
begin
  select jsonb_strip_nulls(jsonb_build_object(
    'nombres',(
      select r.names_raw
      from public.aos_f5_identity_cluster_members_v1 m
      join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
      join public.aos_f5_source_batches_v1 b on b.id=r.batch_id
      where m.cluster_id=new.cluster_id and nullif(btrim(r.names_raw),'') is not null
      order by coalesce(r.source_created_date,make_date(b.source_year,1,1)) desc,b.source_year desc,r.source_row_num desc
      limit 1
    ),
    'apellidos',(
      select r.surnames_raw
      from public.aos_f5_identity_cluster_members_v1 m
      join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
      join public.aos_f5_source_batches_v1 b on b.id=r.batch_id
      where m.cluster_id=new.cluster_id and nullif(btrim(r.surnames_raw),'') is not null
      order by coalesce(r.source_created_date,make_date(b.source_year,1,1)) desc,b.source_year desc,r.source_row_num desc
      limit 1
    ),
    'address',(
      select r.address_raw
      from public.aos_f5_identity_cluster_members_v1 m
      join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
      join public.aos_f5_source_batches_v1 b on b.id=r.batch_id
      where m.cluster_id=new.cluster_id and nullif(btrim(r.address_raw),'') is not null
      order by coalesce(r.source_created_date,make_date(b.source_year,1,1)) desc,b.source_year desc,r.source_row_num desc
      limit 1
    ),
    'address_street',(
      select r.address_street
      from public.aos_f5_identity_cluster_members_v1 m
      join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
      join public.aos_f5_source_batches_v1 b on b.id=r.batch_id
      where m.cluster_id=new.cluster_id and nullif(btrim(r.address_street),'') is not null
      order by coalesce(r.source_created_date,make_date(b.source_year,1,1)) desc,b.source_year desc,r.source_row_num desc
      limit 1
    ),
    'district',(
      select r.district
      from public.aos_f5_identity_cluster_members_v1 m
      join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
      join public.aos_f5_source_batches_v1 b on b.id=r.batch_id
      where m.cluster_id=new.cluster_id and nullif(btrim(r.district),'') is not null
      order by coalesce(r.source_created_date,make_date(b.source_year,1,1)) desc,b.source_year desc,r.source_row_num desc
      limit 1
    ),
    'province',(
      select r.province
      from public.aos_f5_identity_cluster_members_v1 m
      join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
      join public.aos_f5_source_batches_v1 b on b.id=r.batch_id
      where m.cluster_id=new.cluster_id and nullif(btrim(r.province),'') is not null
      order by coalesce(r.source_created_date,make_date(b.source_year,1,1)) desc,b.source_year desc,r.source_row_num desc
      limit 1
    ),
    'department',(
      select r.department
      from public.aos_f5_identity_cluster_members_v1 m
      join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
      join public.aos_f5_source_batches_v1 b on b.id=r.batch_id
      where m.cluster_id=new.cluster_id and nullif(btrim(r.department),'') is not null
      order by coalesce(r.source_created_date,make_date(b.source_year,1,1)) desc,b.source_year desc,r.source_row_num desc
      limit 1
    ),
    'occupation',(
      select r.occupation
      from public.aos_f5_identity_cluster_members_v1 m
      join public.aos_f5_patient_source_rows_v1 r on r.id=m.source_row_id
      join public.aos_f5_source_batches_v1 b on b.id=r.batch_id
      where m.cluster_id=new.cluster_id and nullif(btrim(r.occupation),'') is not null
      order by coalesce(r.source_created_date,make_date(b.source_year,1,1)) desc,b.source_year desc,r.source_row_num desc
      limit 1
    )
  )) into v_profile;

  update public.aos_f5_identity_clusters_v1
  set canonical_preview=canonical_preview||coalesce(v_profile,'{}'::jsonb),updated_at=now()
  where id=new.cluster_id;

  return new;
end
$$;

revoke all on function public.aos_f5_refresh_cluster_profile_v1() from public,anon,authenticated;

drop trigger if exists trg_aos_f5_refresh_cluster_profile_v1 on public.aos_f5_identity_cluster_members_v1;
create trigger trg_aos_f5_refresh_cluster_profile_v1
after insert on public.aos_f5_identity_cluster_members_v1
for each row execute function public.aos_f5_refresh_cluster_profile_v1();

insert into public.aos_security_log(usuario,accion,detalles)
values('SYSTEM','F5_FIELDWISE_ENRICHMENT_RULE',jsonb_build_object(
  'version','v1','policy','LATEST_NON_NULL_PER_FIELD','canonical_patient_mutation',false,'at',now()
));
