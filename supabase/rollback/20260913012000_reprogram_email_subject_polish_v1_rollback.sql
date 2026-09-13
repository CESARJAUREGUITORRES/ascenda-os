-- Restore the prior ZIVITAL reprogramming template header.
update public.aos_email_plantillas
set asunto='🔄 Tu cita ha sido reprogramada — Zi Vital',
    updated_at=now()
where lower(tipo)='reprogramacion'
  and activo=true;
