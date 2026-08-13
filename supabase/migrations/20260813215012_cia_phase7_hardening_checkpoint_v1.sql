-- CANONICAL PHASE 7 HARDENING CHECKPOINT. Applied live as 20260813215012.
alter table public.aos_audiencia_snapshots enable row level security;
alter table public.aos_audiencia_snapshot_miembros enable row level security;
alter table public.aos_audiencia_activaciones enable row level security;
alter table public.aos_audiencia_activacion_config enable row level security;
alter table public.aos_audiencia_activacion_estado enable row level security;
alter table public.aos_audiencia_activacion_eventos enable row level security;

create or replace function public.aos_cia_immutable_row_guard_v1()
returns trigger language plpgsql set search_path=public as $$ begin raise exception 'CIA_ROW_IMMUTABLE'; end; $$;
drop trigger if exists trg_aos_cia_activation_event_immutable_v1 on public.aos_audiencia_activacion_eventos;
create trigger trg_aos_cia_activation_event_immutable_v1 before update or delete on public.aos_audiencia_activacion_eventos for each row execute function public.aos_cia_immutable_row_guard_v1();

create or replace function public.aos_cia_activation_config_validate_v1()
returns trigger language plpgsql set search_path=public as $$
begin
 if char_length(btrim(coalesce(new.nombre,''))) not between 3 and 120 then raise exception 'ACTIVATION_NAME_INVALID'; end if;
 if char_length(btrim(coalesce(new.purpose,''))) not between 2 and 120 then raise exception 'ACTIVATION_PURPOSE_INVALID'; end if;
 if new.channel not in ('CALL','EMAIL','SMS','WHATSAPP','AUTOMATION','ANALYSIS','OTHER') then raise exception 'ACTIVATION_CHANNEL_INVALID'; end if;
 if new.mode not in ('BATCH','DYNAMIC') then raise exception 'ACTIVATION_MODE_INVALID'; end if;
 if new.baseline_count<0 or new.baseline_count>100000 then raise exception 'ACTIVATION_BASELINE_COUNT_INVALID'; end if;
 if jsonb_typeof(new.metadata)<>'object' or pg_column_size(new.metadata)>32768 then raise exception 'ACTIVATION_METADATA_INVALID'; end if;
 if new.mode='DYNAMIC' and new.snapshot_id is not null then raise exception 'DYNAMIC_SNAPSHOT_FORBIDDEN'; end if;
 if new.mode='BATCH' and new.snapshot_id is null then raise exception 'BATCH_SNAPSHOT_REQUIRED'; end if;
 return new;
end;$$;
drop trigger if exists trg_aos_cia_activation_config_validate_v1 on public.aos_audiencia_activacion_config;
create trigger trg_aos_cia_activation_config_validate_v1 before insert on public.aos_audiencia_activacion_config for each row execute function public.aos_cia_activation_config_validate_v1();

create or replace function public.aos_cia_activation_config_relation_v1()
returns trigger language plpgsql set search_path=public as $$
declare a_aud uuid; a_ver uuid; s_aud uuid; s_ver uuid; s_state text;
begin
 select audiencia_id,audiencia_version_id into a_aud,a_ver from public.aos_audiencia_activaciones where id=new.activacion_id;
 if a_aud is null then raise exception 'ACTIVATION_NOT_FOUND'; end if;
 if new.mode='BATCH' then
   select audiencia_id,audiencia_version_id,estado into s_aud,s_ver,s_state from public.aos_audiencia_snapshots where id=new.snapshot_id;
   if s_state is distinct from 'READY' then raise exception 'BATCH_SNAPSHOT_NOT_READY'; end if;
   if s_aud is distinct from a_aud or s_ver is distinct from a_ver then raise exception 'BATCH_SNAPSHOT_MISMATCH'; end if;
 end if;
 return new;
end;$$;
drop trigger if exists trg_aos_cia_activation_config_relation_v1 on public.aos_audiencia_activacion_config;
create trigger trg_aos_cia_activation_config_relation_v1 before insert on public.aos_audiencia_activacion_config for each row execute function public.aos_cia_activation_config_relation_v1();
