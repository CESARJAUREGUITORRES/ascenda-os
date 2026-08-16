-- F17 P0 recovery: remain fail-closed.
-- We intentionally do NOT restore browser write privileges that were unnecessary
-- for the observed consumer. Recovery preserves SELECT compatibility only.

begin;

revoke insert, update, delete, truncate, references, trigger
  on table public.aos_plantillas_whatsapp
  from anon, authenticated;

grant select on table public.aos_plantillas_whatsapp to anon, authenticated;

commit;