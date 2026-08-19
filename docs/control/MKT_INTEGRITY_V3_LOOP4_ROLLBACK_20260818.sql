-- MKT-INTEGRITY-HOTFIX-V3 / LOOP 4
-- Exact rollback for deterministic late-lead trace links.
-- Preconditions: only revert rows whose AFTER values exactly match this Loop-4 package.

begin;

update public.aos_agenda_citas a
set lead_id_origen = null,
    llamada_id_origen = null
from (values
  ('1c3467c9-0536-4c71-86e1-561638e9401c'::text,2819::bigint,14828::bigint),
  ('f5b8243b-f21f-4a8c-804a-641b888c1e2e',2847,15076),
  ('2830674b-66bc-4104-a920-62f2f313aaab',2875,15468),
  ('33dc643c-78e8-4ef2-a235-7e174c98bbb5',4045,30320),
  ('883962de-e15b-42b8-89da-6db8a6b12704',5001,33358),
  ('df37e522-ce4b-4edc-aa79-0b7bf4e1517d',5444,36025)
) x(id,expected_lead,expected_call)
where a.id=x.id
  and a.lead_id_origen=x.expected_lead
  and a.llamada_id_origen=x.expected_call;

update public.aos_llamadas ll
set lead_id_origen = null
from (values
  (14546::bigint,2799::bigint),(14547,2802),(14548,2798),(14828,2819),(15076,2847),(15468,2875),
  (15800,2881),(15801,2883),(17043,2922),(17818,3005),(18130,3019),(18131,3018),(18132,3020),(18133,3023),
  (18134,3021),(18135,3022),(18304,3047),(21692,3321),(21693,3320),(21722,3322),(23096,3420),(30320,4045),
  (33358,5001),(36025,5444)
) x(id,expected_lead)
where ll.id=x.id
  and ll.lead_id_origen=x.expected_lead;

commit;
