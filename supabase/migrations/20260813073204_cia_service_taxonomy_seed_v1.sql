-- ASCENDA OS — CIA Phase 4 service taxonomy seed
begin;
insert into public.aos_service_family_taxonomy_v1(raw_family,canonical_category) values
('HIDROFACIAL','FACIALES'),
('VITAMINAS','VITAMINAS'),
('TOXINA','TOXINA'),
('DETOX','DETOX'),
('ACIDO HIALURONICO','ACIDO HIALURONICO'),
('EXOSOMAS FACIAL','EXOSOMAS'),
('EXOSOMAS CAPILARES','EXOSOMAS'),
('EXOSOMAS','EXOSOMAS'),
('HIFU','HIFU'),
('ENZIMAS','ENZIMAS'),
('MESOTERAPIA CAPILAR','MESOTERAPIA'),
('MESOTERAPIA FACIAL','MESOTERAPIA'),
('MESOTERAPIA','MESOTERAPIA'),
('BIOESTIMULADOR','BIOESTIMULADOR'),
('CRIOLIPOLISIS','CRIOLIPOLISIS'),
('CONSULTA MEDICA','CONSULTA'),
('PEPTONAS','PEPTONAS'),
('BIOREBITALIZACION','BIOREVITALIZACION')
on conflict(raw_family) do update set canonical_category=excluded.canonical_category,active=true,updated_at=now();
commit;
