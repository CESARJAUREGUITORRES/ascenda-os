-- ASCENDA OS — CIA Phase 4 service taxonomy confirmed extensions
begin;
insert into public.aos_service_family_taxonomy_v1(raw_family,canonical_category) values
('PQ AGE','PEELINGS'),
('PRP FACIAL','MESOTERAPIA'),
('PRP CAPILAR','CAPILAR')
on conflict(raw_family) do update set canonical_category=excluded.canonical_category,active=true,updated_at=now();
commit;
