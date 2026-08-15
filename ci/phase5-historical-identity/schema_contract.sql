\set ON_ERROR_STOP on

create extension if not exists pgcrypto;

create table if not exists public.aos_security_log (
  id bigserial primary key,
  usuario text,
  accion text,
  detalles jsonb,
  created_at timestamptz default now()
);
