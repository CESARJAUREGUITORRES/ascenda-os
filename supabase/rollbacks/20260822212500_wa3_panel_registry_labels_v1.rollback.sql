-- Roll back WA-3 panel labels/categories to the immediately previous registry state.
update public.aos_paneles_disponibles
set nombre='WhatsApp Live Inbox', categoria='admin'
where id='admin-whatsapp';

update public.aos_paneles_disponibles
set nombre='WhatsApp Hub', categoria='asesor'
where id='whatsapp-agent';
