\set ON_ERROR_STOP on

create extension if not exists pgcrypto;

create table if not exists public.aos_security_log (
  id bigserial primary key,
  usuario text,
  accion text,
  detalles jsonb,
  created_at timestamptz default now()
);

-- Minimal canonical patient contract required only by isolated F5 preview tests.
create table if not exists public.aos_pacientes (
  "ID_PACIENTE" text primary key,
  "Nombres" text,
  "Apellidos" text,
  "Teléfono" text,
  "Email" text,
  "N° documento" text,
  "Sexo" text,
  "Fecha de nacimiento" text,
  "Dirección" text,
  "Ocupación" text,
  numero_limpio text,
  distrito text,
  departamento text,
  ciudad text
);
