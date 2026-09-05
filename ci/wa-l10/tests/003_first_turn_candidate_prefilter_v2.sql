\set ON_ERROR_STOP on

-- Approximate current PROD text volume without PII/PHI: ~234 active services with ~12.7k-char
-- derived commercial search_text and ~27 categories with ~8k-char search_text.
insert into public.aos_catalogo_servicios(
  nombre,nombre_corto,tipo,categoria,descripcion_comercial,beneficios,duracion_sesion,
  num_sesiones,frecuencia,precio_base,precio_oferta,faqs,tags,estado,updated_at
)
select
  'Synthetic Service '||g,
  'Synthetic '||g,
  'SERVICIO',
  'Synthetic',
  'Commercial fixture '||g,
  'Approved synthetic benefit',
  '30 min','1','Según evaluación',100,null,
  jsonb_build_array(jsonb_build_object('q','FAQ '||g,'a',repeat('contenido comercial aprobado ',450))),
  'synthetic service fixture '||g,
  'ACTIVO',now()
from generate_series(1,230) g;

insert into public.aos_catalogo_categorias(
  id,nombre,descripcion_comercial,beneficios,faqs,estado,updated_at
)
select
  'synthetic-cat-'||g,
  'Synthetic Category '||g,
  'Synthetic category fixture '||g,
  'Approved category benefit',
  jsonb_build_array(jsonb_build_object('q','FAQ category '||g,'a',repeat('categoria comercial aprobada ',300))),
  'ACTIVO',now()
from generate_series(1,26) g;

DO $$
DECLARE
  v_services integer;
  v_categories integer;
BEGIN
  select count(*) into v_services from public.aos_catalogo_servicios where coalesce(estado,'ACTIVO')='ACTIVO';
  select count(*) into v_categories from public.aos_catalogo_categorias where coalesce(estado,'ACTIVO')='ACTIVO';
  if v_services < 234 then raise exception 'WA_L10_V2_SERVICE_SCALE_INCOMPLETE:%',v_services; end if;
  if v_categories < 27 then raise exception 'WA_L10_V2_CATEGORY_SCALE_INCOMPLETE:%',v_categories; end if;
END $$;

set statement_timeout='3000ms';

DO $$
BEGIN
  if not exists(
    select 1
    from public.aos_wa4a_knowledge_search_v1(
      'Hola, quisiera información sobre Botox y cómo puedo agendar una evaluación.',
      12,
      null
    )
    where knowledge_id='service:10000000-0000-4000-8000-000000000001'
      and score>0
      and (evidence_ref->>'relation')='public.aos_catalogo_servicios'
  ) then
    raise exception 'WA_L10_EXACT_FIRST_TURN_RETRIEVAL_FAILED';
  end if;
END $$;

DO $$
BEGIN
  if not exists(
    select 1 from public.aos_wa4a_knowledge_search_v1('botox precio',12,array['CATALOG'])
    where knowledge_id='service:10000000-0000-4000-8000-000000000001' and score>0
  ) then raise exception 'WA_L10_V2_BOTOX_REGRESSION'; end if;

  if not exists(
    select 1 from public.aos_wa4a_knowledge_search_v1('miraflores',12,array['HOURS'])
    where domain='HOURS'
  ) then raise exception 'WA_L10_V2_HOURS_REGRESSION'; end if;

  if exists(
    select 1 from public.aos_wa4a_knowledge_search_v1('laser conflict',12,array['CATALOG'])
    where subject_id in ('10000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000004')
  ) then raise exception 'WA_L10_V2_CONFLICT_FAIL_CLOSED_REGRESSION'; end if;
END $$;

reset statement_timeout;

select 'WA_L10_FIRST_TURN_V2_STRICT_3S_PASS' as result;
