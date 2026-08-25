-- Synthetic REV authority for WA-7A.1 Zero-Cost tests.
-- Mirrors only the private columns/contracts consumed by the bridge.

create or replace function public.aos_rev_normalize_patient_identifier_v2(p_type text,p_value text)
returns text language plpgsql immutable set search_path='' as $$
declare v_type text:=upper(trim(coalesce(p_type,''))); v text:=trim(coalesce(p_value,'')); v_digits text;
begin
  if v_type='PHONE' then
    v_digits:=regexp_replace(v,'[^0-9]','','g');
    if length(v_digits)<9 then return null; end if;
    return right(v_digits,9);
  elsif v_type='CANONICAL_ID' then return nullif(v,'');
  end if;
  return null;
end
$$;

create table public.aos_rev_patient_identity_alias_v2 (
  identifier_type text,
  identifier_key text,
  canonical_patient_id text,
  evidence_rows integer,
  evidence_scopes jsonb,
  candidate_count integer,
  status text,
  confidence_band text,
  has_reviewed_match boolean
);

revoke all on public.aos_rev_patient_identity_alias_v2 from public,anon,authenticated;
grant select on public.aos_rev_patient_identity_alias_v2 to service_role;
