-- ASCENDA OS — CIA Phase 4 item-label accent normalization fix
begin;
create or replace function public.aos_cia_normalize_item_label_v1(p_raw text)
returns text language sql immutable parallel safe as $$
with s0 as (
 select translate(upper(btrim(coalesce(p_raw,''))),'ÁÉÍÓÚÜÑÀÈÌÒÙÄËÏÖ','AEIOUUNAEIOUAEIO') s
), s1 as (
 select regexp_replace(regexp_replace(s,'\s*\(?PROMO\)?\s*$','','i'),'\s+[0-9]+\s*(ML|MG|G|GR|CAPS|CAP|UN|UND)\s*$','','i') s from s0
)
select nullif(regexp_replace(s,'[^A-Z0-9]+','','g'),'') from s1;
$$;
commit;
