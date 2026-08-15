\set ON_ERROR_STOP on

-- Mirror the production schema privilege prerequisite before applying the P0.
revoke create on schema public from public;
revoke create on schema public from anon;
revoke create on schema public from authenticated;

-- Synthetic Phase-2 Caja wrappers. Their bodies are irrelevant here; the P0
-- must be able to harden their function-level search_path using exact signatures.
create or replace function public.aos_caja_abrir_v2(text,text,numeric,numeric,numeric,date)
returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;
create or replace function public.aos_caja_cerrar_v2(text,text,numeric,numeric,numeric,numeric,text)
returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;
create or replace function public.aos_caja_editar_pago_v2(text,text,text,text,numeric,text,text,text,text,text,uuid)
returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;
create or replace function public.aos_caja_eliminar_venta_v2(text,text,text)
returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;
create or replace function public.aos_caja_ingreso_extra_v2(text,text,text,date,text,numeric,text)
returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;
create or replace function public.aos_caja_registrar_gasto_v2(text,text,text,date,text,numeric,text,text)
returns jsonb language sql security definer as $$ select '{"ok":true}'::jsonb $$;

-- Synthetic audited legacy Cartera read gateway. The P0 V2 bridge must wrap it
-- only after strong Auth V3 succeeds.
create or replace function public.aos_cartera_gateway(
  p_token text,p_estado text default '',p_sede text default '',p_limit integer default 50,p_offset integer default 0
) returns jsonb
language sql
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'ok',true,'summary',jsonb_build_object('activeCases',0),'rows','[]'::jsonb,
    'policy',jsonb_build_object('advanceIsPaymentNotBalance',true)
  )
$$;
