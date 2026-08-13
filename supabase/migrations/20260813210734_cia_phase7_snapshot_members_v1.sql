create table if not exists public.aos_audiencia_snapshot_miembros (
  snapshot_id uuid not null references public.aos_audiencia_snapshots(id) on delete restrict,
  contact_key text not null,
  identity_status text,
  identity_conflict boolean not null default false,
  resolved_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key(snapshot_id,contact_key),
  constraint aos_audiencia_snapshot_miembros_key_len_chk check (char_length(contact_key) between 3 and 128),
  constraint aos_audiencia_snapshot_miembros_identity_status_len_chk check (identity_status is null or char_length(identity_status)<=80)
);
create index if not exists aos_audiencia_snapshot_miembros_contact_idx on public.aos_audiencia_snapshot_miembros(contact_key,snapshot_id);