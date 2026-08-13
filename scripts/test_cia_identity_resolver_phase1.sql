-- ASCENDA OS — CIA Phase 1 Identity Resolver contract tests
-- READ ONLY. Run after applying the Phase 1 migration in a controlled environment.

-- 1) Basic normalization examples
select 'normalize_9_digit' as test,
       case when public.aos_cia_normalize_contact_key_v1('999 888 777') = '999888777' then 'PASS' else 'FAIL' end as status
union all
select 'normalize_51_prefix',
       case when public.aos_cia_normalize_contact_key_v1('+51 999 888 777') = '999888777' then 'PASS' else 'FAIL' end
union all
select 'reject_short',
       case when public.aos_cia_normalize_contact_key_v1('12345') is null then 'PASS' else 'FAIL' end;

-- 2) One row per contact key
select 'unique_contact_key' as test,
       case when count(*) = count(distinct contact_key) then 'PASS' else 'FAIL' end as status,
       count(*) as observed
from public.aos_cia_contact_identity_v1;

-- 3) All keys are valid 9-digit V1 keys
select 'all_keys_9_digits' as test,
       case when bool_and(contact_key ~ '^\d{9}$') then 'PASS' else 'FAIL' end as status,
       count(*) as observed
from public.aos_cia_contact_identity_v1;

-- 4) Resolved identities always have canonical patient
select 'resolved_has_canonical' as test,
       case when coalesce(bool_and(canonical_patient_id is not null), true) then 'PASS' else 'FAIL' end as status,
       count(*) as observed
from public.aos_cia_contact_identity_v1
where identity_status = 'RESOLVED';

-- 5) Non-resolved identities never get a canonical patient
select 'nonresolved_has_no_canonical' as test,
       case when coalesce(bool_and(canonical_patient_id is null), true) then 'PASS' else 'FAIL' end as status,
       count(*) as observed
from public.aos_cia_contact_identity_v1
where identity_status <> 'RESOLVED';

-- 6) Canonical profile is never FUSIONADO
select 'canonical_never_fused' as test,
       case when coalesce(bool_and(upper(coalesce(canonical_patient_state,'')) <> 'FUSIONADO'), true) then 'PASS' else 'FAIL' end as status,
       count(*) as observed
from public.aos_cia_contact_identity_v1
where canonical_patient_id is not null;

-- 7) CONFLICT means multiple non-fused patient rows
select 'conflict_exactly_multi_nonfused' as test,
       case when coalesce(bool_and(non_fused_count > 1 and canonical_patient_id is null), true) then 'PASS' else 'FAIL' end as status,
       count(*) as observed
from public.aos_cia_contact_identity_v1
where identity_status = 'CONFLICT';

-- 8) FUSED_ONLY cannot produce canonical identity
select 'fused_only_safe' as test,
       case when coalesce(bool_and(non_fused_count = 0 and fused_count > 0 and canonical_patient_id is null), true) then 'PASS' else 'FAIL' end as status,
       count(*) as observed
from public.aos_cia_contact_identity_v1
where identity_status = 'FUSED_ONLY';

-- 9) Source flags JSON matches booleans
select 'source_flags_consistent' as test,
       case when bool_and(
         (source_flags->>'patient')::boolean = has_patient_source and
         (source_flags->>'lead')::boolean = has_lead and
         (source_flags->>'call')::boolean = has_call and
         (source_flags->>'appointment')::boolean = has_appointment and
         (source_flags->>'sale')::boolean = has_sale
       ) then 'PASS' else 'FAIL' end as status,
       count(*) as observed
from public.aos_cia_contact_identity_v1;

-- 10) Distribution report (not hard-coded because production remains live)
select identity_status,
       count(*) as contacts,
       count(*) filter(where canonical_patient_id is not null) as canonical_profiles
from public.aos_cia_contact_identity_v1
group by identity_status
order by identity_status;

-- 11) Unresolved quality lane report
select source_type, resolution_status, count(*) as rows
from public.aos_cia_identity_unresolved_v1
group by source_type, resolution_status
order by source_type, resolution_status;

-- 12) Performance check
explain (analyze, buffers)
select count(*) from public.aos_cia_contact_identity_v1;
