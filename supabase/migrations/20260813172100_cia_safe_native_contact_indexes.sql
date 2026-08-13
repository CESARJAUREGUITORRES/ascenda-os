-- CIA Phase 5 performance indexes — write-safe final state.
-- These expressions use PostgreSQL built-ins only. Do not replace them with private-function index expressions.
set lock_timeout='3s';

create index if not exists idx_cia_native_calls_contact_event on public.aos_llamadas (
  (case when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9 then regexp_replace(coalesce(numero_limpio,''),'\D','','g')
        when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11 and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51' then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9)
        else null end), created_at desc
);
create index if not exists idx_cia_native_leads_contact_event on public.aos_leads (
  (case when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9 then regexp_replace(coalesce(numero_limpio,''),'\D','','g')
        when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11 and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51' then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9)
        else null end), created_at desc
);
create index if not exists idx_cia_native_appointments_contact_date on public.aos_agenda_citas (
  (case when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9 then regexp_replace(coalesce(numero_limpio,''),'\D','','g')
        when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11 and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51' then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9)
        else null end), fecha_cita
);
create index if not exists idx_cia_native_sales_contact_date on public.aos_ventas (
  (case when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9 then regexp_replace(coalesce(numero_limpio,''),'\D','','g')
        when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11 and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51' then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9)
        else null end), fecha desc
);
create index if not exists idx_cia_native_patients_contact on public.aos_pacientes (
  (case when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=9 then regexp_replace(coalesce(numero_limpio,''),'\D','','g')
        when length(regexp_replace(coalesce(numero_limpio,''),'\D','','g'))=11 and left(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),2)='51' then right(regexp_replace(coalesce(numero_limpio,''),'\D','','g'),9)
        else null end)
);
create index if not exists idx_cia_native_followups_contact on public.aos_seguimientos (
  (case when length(regexp_replace(coalesce("NUMERO",''),'\D','','g'))=9 then regexp_replace(coalesce("NUMERO",''),'\D','','g')
        when length(regexp_replace(coalesce("NUMERO",''),'\D','','g'))=11 and left(regexp_replace(coalesce("NUMERO",''),'\D','','g'),2)='51' then right(regexp_replace(coalesce("NUMERO",''),'\D','','g'),9)
        else null end)
);
create index if not exists idx_cia_native_base_labels_contact on public.aos_base_etiquetas (
  (case when length(regexp_replace(coalesce(numero,''),'\D','','g'))=9 then regexp_replace(coalesce(numero,''),'\D','','g')
        when length(regexp_replace(coalesce(numero,''),'\D','','g'))=11 and left(regexp_replace(coalesce(numero,''),'\D','','g'),2)='51' then right(regexp_replace(coalesce(numero,''),'\D','','g'),9)
        else null end)
);
