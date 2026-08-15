\set ON_ERROR_STOP on
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table public.aos_usuarios(
  id uuid primary key default extensions.gen_random_uuid(), codigo_asesor text unique, nombre text, rol text,
  nivel_jerarquia integer, activo boolean default true, two_factor boolean default true,
  paneles_acceso text[] default '{}', sedes_permitidas text[] default '{}'
);
create table public.aos_rrhh(codigo_asesor text primary key,nombre text,estado text default 'ACTIVO');
create table public.aos_app_sessions_v3(
  token_hash text primary key,user_id uuid,assurance_level text,expires_at timestamptz,revoked boolean default false,
  last_used_at timestamptz default now()
);
create table public.aos_security_log(id bigserial primary key,usuario text,accion text,detalles jsonb,created_at timestamptz default now());

create or replace function public.aos_app_actor_v3(p_token text,p_required_panel text default null,p_require_2fa boolean default false)
returns uuid language sql stable security definer set search_path to '' as $$
  select s.user_id from public.aos_app_sessions_v3 s join public.aos_usuarios u on u.id=s.user_id
  where s.token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and s.revoked=false and s.expires_at>now() and u.activo=true
    and (not p_require_2fa or s.assurance_level='PASSWORD_2FA')
    and (p_required_panel is null or coalesce(u.paneles_acceso,'{}') @> array[p_required_panel]::text[]) limit 1
$$;

create table public.aos_ventas(
 id bigserial primary key,venta_id text,fecha date,nombres text,apellidos text,dni text,celular text,tratamiento text,descripcion text,
 pago text,monto numeric,estado_pago text,asesor text,atendio text,sede text,tipo text,numero_limpio text,nro_doc text,estado_doc text,
 tipo_comprobante text,created_at timestamptz default now(),updated_at timestamptz default now(),moneda text default 'PEN',cotizacion_id text
);
create table public.aos_product_identity_v1(product_key text primary key,canonical_name text,active boolean default true);
create table public.aos_product_alias_v2(alias_key text primary key,alias_text text,product_key text,default_qty numeric default 1,default_is_pack boolean default false,active boolean default true);
create table public.aos_product_sale_fact_v1(
 sale_id bigint primary key,product_key text,raw_alias_key text,physical_qty numeric,is_pack boolean,resolution_status text,resolution_source text,locked boolean default false,note text,created_at timestamptz default now(),updated_at timestamptz default now()
);
create or replace function public.aos_product_normalize_alias_v2(p_value text) returns text language sql immutable set search_path to 'pg_catalog' as $$
 select nullif(regexp_replace(translate(upper(btrim(coalesce(p_value,''))),'ÁÀÂÄÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇ','AAAAAEEEEIIIIOOOOOUUUUNC'),'[^A-Z0-9]+','','g'),'')
$$;
create or replace function public.aos_product_resolve_sale_test() returns trigger language plpgsql set search_path to '' as $$
declare k text; a record;
begin
 if upper(trim(coalesce(new.tipo,'')))<>'PRODUCTO' and upper(trim(coalesce(new.tratamiento,''))) not like '%COMPRA%PRODUCTO%' then delete from public.aos_product_sale_fact_v1 where sale_id=new.id; return new; end if;
 k:=public.aos_product_normalize_alias_v2(new.descripcion);
 select * into a from public.aos_product_alias_v2 where alias_key=k and active=true limit 1;
 insert into public.aos_product_sale_fact_v1(sale_id,product_key,raw_alias_key,physical_qty,is_pack,resolution_status,resolution_source,locked,updated_at)
 values(new.id,a.product_key,k,case when a.product_key is null then null else coalesce(a.default_qty,1) end,case when a.product_key is null then null else coalesce(a.default_is_pack,false) end,case when a.product_key is null then 'REVIEW_REQUIRED' else 'RESOLVED' end,'TEST_ALIAS',false,now())
 on conflict(sale_id) do update set product_key=excluded.product_key,raw_alias_key=excluded.raw_alias_key,physical_qty=excluded.physical_qty,is_pack=excluded.is_pack,resolution_status=excluded.resolution_status,updated_at=now();
 return new;
end$$;
create trigger trg_aos_product_sync_sale_v1 after insert or update of tipo,tratamiento,descripcion on public.aos_ventas for each row execute function public.aos_product_resolve_sale_test();

create table public.aos_import_ventas_batches(id bigserial primary key,batch_hash text unique,total_rows integer,resultado jsonb,created_at timestamptz default now());
create table public.aos_caja_sesiones(id text primary key,sede text,estado text,abierto_por_user_id uuid,created_at timestamptz default now());
create table public.aos_cotizaciones(id text primary key,numero_limpio text,nombre_paciente text,dni_paciente text,estado text,subtotal numeric,total_pagado numeric,saldo_pendiente numeric,sede text,asesor text,fecha_creacion date,updated_at timestamptz default now());
create table public.aos_pagos(id text primary key default extensions.gen_random_uuid()::text,monto numeric default 0,created_at timestamptz default now());
create table public.aos_cartera_reconciliacion(
 id uuid primary key default extensions.gen_random_uuid(),source_type text,venta_row_id bigint,cotizacion_id text,pago_id text,grupo_pago_id uuid,rol_pago text,
 estado_reconciliacion text,confianza text,monto_registrado numeric,total_compra_esperado numeric,saldo_confirmado numeric,source_active boolean default true,
 evidencia jsonb default '{}',observacion text,confirmado_por uuid,confirmed_at timestamptz,created_at timestamptz default now(),updated_at timestamptz default now()
);

create or replace function public.aos_ventas_admin(p_mes integer,p_anio integer,p_sede text default '',p_asesor text default '') returns jsonb language sql security definer set search_path to '' as $$
 with x as (select * from public.aos_ventas where extract(month from fecha)=p_mes and extract(year from fecha)=p_anio and (coalesce(p_sede,'')='' or upper(sede)=upper(p_sede)) and (coalesce(p_asesor,'')='' or upper(asesor)=upper(p_asesor)))
 select jsonb_build_object('nVentas',count(*),'factTotal',coalesce(sum(monto),0),'nProd',count(*) filter(where tipo='PRODUCTO'),'factProd',coalesce(sum(monto) filter(where tipo='PRODUCTO'),0),'nServ',count(*) filter(where tipo<>'PRODUCTO'),'detalle',coalesce(jsonb_agg(to_jsonb(x) order by fecha desc,id desc),'[]'::jsonb)) from x
$$;
create or replace function public.aos_ventas_admin_anio(p_anio integer,p_sede text default '',p_asesor text default '') returns jsonb language sql security definer set search_path to '' as $$
 with x as (select * from public.aos_ventas where extract(year from fecha)=p_anio and (coalesce(p_sede,'')='' or upper(sede)=upper(p_sede)) and (coalesce(p_asesor,'')='' or upper(asesor)=upper(p_asesor)))
 select jsonb_build_object('nVentas',count(*),'factTotal',coalesce(sum(monto),0),'detalle',coalesce(jsonb_agg(to_jsonb(x) order by fecha desc,id desc),'[]'::jsonb)) from x
$$;

create or replace function public.aos_editar_venta(p_venta_id bigint,p_campos jsonb,p_editado_por text,p_rol text,p_origen text default 'test') returns jsonb language plpgsql security definer set search_path to '' as $$
begin
 update public.aos_ventas set
  fecha=coalesce((p_campos->>'fecha')::date,fecha),
  descripcion=case when p_campos?'descripcion' then p_campos->>'descripcion' else descripcion end,
  tratamiento=case when p_campos?'tratamiento' then p_campos->>'tratamiento' else tratamiento end,
  monto=case when p_campos?'monto' then (p_campos->>'monto')::numeric else monto end,
  sede=case when p_campos?'sede' then p_campos->>'sede' else sede end,
  tipo=case when p_campos?'tipo' then p_campos->>'tipo' else tipo end,
  estado_pago=case when p_campos?'estado_pago' then p_campos->>'estado_pago' else estado_pago end,
  updated_at=now()
 where id=p_venta_id;
 return jsonb_build_object('ok',found,'total',case when found then 1 else 0 end);
end$$;

create or replace function public.aos_importar_ventas(p_ventas jsonb) returns jsonb language plpgsql security definer set search_path to '' as $$
declare r jsonb;n integer:=0;h text:=md5(p_ventas::text);v_num text;v_tipo text;v_res jsonb;
begin
 if exists(select 1 from public.aos_import_ventas_batches where batch_hash=h) then return jsonb_build_object('insertados',0,'duplicados',jsonb_array_length(p_ventas),'errores',0); end if;
 for r in select value from jsonb_array_elements(p_ventas) loop
   v_num:=regexp_replace(coalesce(r->>'celular',''),'[^0-9]','','g');if length(v_num)>9 then v_num:=right(v_num,9);end if;
   v_tipo:=case when upper(coalesce(r->>'tratamiento','')) like '%COMPRA%' or upper(coalesce(r->>'tratamiento','')) like '%PRODUCTO%' or upper(coalesce(r->>'tratamiento',''))='OTROS' then 'PRODUCTO' else 'SERVICIO' end;
   insert into public.aos_ventas(fecha,nombres,apellidos,dni,celular,numero_limpio,tratamiento,descripcion,pago,monto,estado_pago,asesor,atendio,sede,tipo)
   values((r->>'fecha')::date,r->>'nombres',r->>'apellidos',r->>'dni',r->>'celular',v_num,r->>'tratamiento',r->>'descripcion',r->>'pago',(r->>'monto')::numeric,coalesce(r->>'estado_pago','PAGO COMPLETO'),r->>'asesor',r->>'atendio',upper(r->>'sede'),v_tipo);n:=n+1;
 end loop;
 v_res:=jsonb_build_object('insertados',n,'duplicados',0,'errores',0);insert into public.aos_import_ventas_batches(batch_hash,total_rows,resultado) values(h,jsonb_array_length(p_ventas),v_res);return v_res;
end$$;

create or replace function public.aos_grabar_venta_caja(p_sede text,p_usuario text,p_sesion_id text,p_numero_limpio text,p_nombres text,p_apellidos text,p_celular text,p_dni text,p_asesor text,p_doctor text,p_items jsonb,p_metodo_pago text,p_monto_total numeric,p_moneda text,p_tipo_comprobante text,p_nro_doc text,p_estado_pago text,p_nota text,p_tipo text,p_fecha text,p_razon_social_id text default null,p_monto_pagado numeric default null) returns jsonb language plpgsql security definer set search_path to '' as $$
declare vid bigint;d text;begin d:=coalesce(p_items->0->>'descripcion',p_items->0->>'nombre','CAJA');insert into public.aos_ventas(fecha,nombres,apellidos,dni,celular,numero_limpio,tratamiento,descripcion,pago,monto,estado_pago,asesor,atendio,sede,tipo) values(p_fecha::date,p_nombres,p_apellidos,p_dni,p_celular,p_numero_limpio,case when upper(p_tipo)='PRODUCTO' then 'COMPRA DE PRODUCTO' else coalesce(p_items->0->>'nombre','SERVICIO') end,d,p_metodo_pago,p_monto_total,p_estado_pago,p_asesor,p_doctor,upper(p_sede),upper(p_tipo)) returning id into vid;return jsonb_build_object('ok',true,'venta_id',vid);end$$;

create or replace function public.aos_cartera_reconcile(p_token text,p_case_id uuid,p_expected_updated_at timestamptz,p_estado text,p_confianza text default 'CONFIRMADA',p_total_esperado numeric default null,p_saldo_confirmado numeric default null,p_cotizacion_id text default null,p_rol_pago text default 'ADELANTO',p_observacion text default '') returns jsonb language plpgsql security definer set search_path to '' as $$
declare c record;begin select * into c from public.aos_cartera_reconciliacion where id=p_case_id for update;if c.id is null then return jsonb_build_object('ok',false,'error','NOT_FOUND');end if;if c.updated_at<>p_expected_updated_at then return jsonb_build_object('ok',false,'error','STALE_CASE');end if;update public.aos_cartera_reconciliacion set estado_reconciliacion=p_estado,confianza=p_confianza,total_compra_esperado=p_total_esperado,saldo_confirmado=p_saldo_confirmado,cotizacion_id=coalesce(p_cotizacion_id,cotizacion_id),rol_pago=p_rol_pago,observacion=p_observacion,updated_at=now() where id=p_case_id;return jsonb_build_object('ok',true,'caseId',p_case_id);end$$;
