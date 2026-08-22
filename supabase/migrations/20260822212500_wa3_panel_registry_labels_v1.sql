-- WA-3 canary UX governance: make WhatsApp panel permissions explicit and durable.
update public.aos_paneles_disponibles
set nombre='WhatsApp Hub — Admin/Supervisor', categoria='admin'
where id='admin-whatsapp';

update public.aos_paneles_disponibles
set nombre='WhatsApp Hub — Asesor', categoria='asesor'
where id='whatsapp-agent';
