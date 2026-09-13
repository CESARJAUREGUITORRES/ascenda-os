-- Transactional email polish for appointment reprogramming.
-- Keep the stored editable template, but make the visible header concise and consistent
-- with the Resend subject produced by the application server.

update public.aos_email_plantillas
set asunto='Tu cita fue reprogramada | Zi Vital',
    updated_at=now()
where lower(tipo)='reprogramacion'
  and activo=true;
