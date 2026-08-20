-- REV-F6.1 hotfix — normalize F5 reviewed aliases with the same resolver contract.
-- Prevents raw historical country-code/format variants from becoming unreachable lookup keys.

begin;

create or replace view public.aos_rev_patient_identity_alias_v2 as
with raw_alias as (
  select
    'CANONICAL_ID'::text identifier_type,
    p."ID_PACIENTE"::text identifier_key,
    p."ID_PACIENTE"::text canonical_patient_id,
    'CANONICAL_CURRENT'::text source_scope
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'

  union all

  select
    'PHONE',
    public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")),
    p."ID_PACIENTE"::text,
    'CANONICAL_CURRENT'
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
    and public.aos_rev_normalize_patient_identifier_v2('PHONE',coalesce(nullif(p.numero_limpio,''),p."Teléfono")) is not null

  union all

  select
    'DOCUMENT',
    public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',p."N° documento"),
    p."ID_PACIENTE"::text,
    'CANONICAL_CURRENT'
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
    and public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',p."N° documento") is not null

  union all

  select
    'EMAIL',
    public.aos_rev_normalize_patient_identifier_v2('EMAIL',p."Email"),
    p."ID_PACIENTE"::text,
    'CANONICAL_CURRENT'
  from public.aos_pacientes p
  where coalesce(p."ESTADO_PACIENTE",'') <> 'FUSIONADO'
    and public.aos_rev_normalize_patient_identifier_v2('EMAIL',p."Email") is not null

  union all

  select
    'PHONE',
    public.aos_rev_normalize_patient_identifier_v2('PHONE',s.phone_key),
    c.target_patient_id,
    'F5_REVIEWED_MATCH'
  from public.aos_f5_canonical_classification_v1 c
  join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
  join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  where c.classification='MATCH'
    and c.target_patient_id is not null
    and public.aos_rev_normalize_patient_identifier_v2('PHONE',s.phone_key) is not null

  union all

  select
    'DOCUMENT',
    public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',s.document_key),
    c.target_patient_id,
    'F5_REVIEWED_MATCH'
  from public.aos_f5_canonical_classification_v1 c
  join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
  join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  where c.classification='MATCH'
    and c.target_patient_id is not null
    and public.aos_rev_normalize_patient_identifier_v2('DOCUMENT',s.document_key) is not null

  union all

  select
    'EMAIL',
    public.aos_rev_normalize_patient_identifier_v2('EMAIL',s.email_key),
    c.target_patient_id,
    'F5_REVIEWED_MATCH'
  from public.aos_f5_canonical_classification_v1 c
  join public.aos_f5_identity_cluster_members_v1 m on m.cluster_id=c.cluster_id
  join public.aos_f5_patient_source_rows_v1 s on s.id=m.source_row_id
  where c.classification='MATCH'
    and c.target_patient_id is not null
    and public.aos_rev_normalize_patient_identifier_v2('EMAIL',s.email_key) is not null
), per_candidate as (
  select
    identifier_type,
    identifier_key,
    canonical_patient_id,
    count(*)::integer evidence_rows,
    bool_or(source_scope='F5_REVIEWED_MATCH') has_reviewed_match,
    jsonb_agg(distinct source_scope order by source_scope) evidence_scopes
  from raw_alias
  where identifier_key is not null and identifier_key <> '' and canonical_patient_id is not null
  group by identifier_type,identifier_key,canonical_patient_id
), scored as (
  select
    pc.*,
    count(*) over(partition by identifier_type,identifier_key)::integer candidate_count
  from per_candidate pc
)
select
  identifier_type,
  identifier_key,
  canonical_patient_id,
  evidence_rows,
  evidence_scopes,
  candidate_count,
  case when candidate_count=1 then 'RESOLVED' else 'CONFLICT' end::text status,
  case
    when identifier_type='CANONICAL_ID' then 'EXACT'
    when has_reviewed_match then 'HIGH'
    else 'MEDIUM'
  end::text confidence_band,
  has_reviewed_match
from scored;

comment on view public.aos_rev_patient_identity_alias_v2 is
'REV-F6.1 private identity lookup bridge. All canonical and F5-reviewed aliases are normalized symmetrically; conflicting aliases remain explicit.';

revoke all on public.aos_rev_patient_identity_alias_v2 from public, anon, authenticated;
grant select on public.aos_rev_patient_identity_alias_v2 to service_role;

select pg_notify('pgrst','reload schema');

commit;
