-- CONV-L5 controlled human-canary media. Reuses existing public brand logo; no customer/clinical content.
insert into public.aos_conv_l5_media_catalog_v1(media_type,title,description,public_url,tags,active,approved_for_whatsapp,sort_order)
select 'image','AscendaOS','Identidad visual oficial de AscendaOS',
       'https://ituyqwstonmhnfshnaqz.supabase.co/storage/v1/object/public/logos/logos/logo_sin_fondo_1776998822498.png',
       array['ascenda','logo','marca'],true,true,1
where not exists (
  select 1 from public.aos_conv_l5_media_catalog_v1
  where public_url='https://ituyqwstonmhnfshnaqz.supabase.co/storage/v1/object/public/logos/logos/logo_sin_fondo_1776998822498.png'
);
