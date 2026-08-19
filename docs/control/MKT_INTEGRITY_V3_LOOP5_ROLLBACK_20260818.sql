-- MKT-INTEGRITY-HOTFIX-V3 — LOOP 5 exact guarded rollback
-- Business date: 2026-08-18 Lima
-- NOTE: Productive Loop-5 DML was NOT applied because the mandatory simulation
-- was blocked by trg_aos_hotfix_manual_agenda_cleanup_call_v1.
-- This file is retained as the exact rollback contract if the two historical
-- rows are ever restored under an authorized later guard/cleanup fix.

BEGIN;

-- Remove direct Agenda links only if they point exactly to the Loop-5 restoration.
UPDATE public.aos_agenda_citas
SET lead_id_origen = NULL,
    llamada_id_origen = NULL
WHERE id = '6b1c4962-a597-45d8-8b72-d721d71c20f4'
  AND lead_id_origen = 5664
  AND llamada_id_origen = 37108;

UPDATE public.aos_agenda_citas
SET lead_id_origen = NULL,
    llamada_id_origen = NULL
WHERE id = 'd80a4d17-5f2e-4169-8814-c5d5c50eac5c'
  AND lead_id_origen = 5599
  AND llamada_id_origen = 37110;

-- Delete only the exact reconstructed historical calls.
DELETE FROM public.aos_llamadas
WHERE id = 37108
  AND fecha = DATE '2026-08-18'
  AND numero_limpio = '991144656'
  AND upper(coalesce(asesor,'')) = 'MIREYA'
  AND upper(coalesce(estado,'')) = 'CITA CONFIRMADA'
  AND tratamiento = 'CAPILAR'
  AND lead_id_origen = 5664
  AND upper(coalesce(origen,'')) = 'MARKETING'
  AND anuncio = 'CAPILAR- INJERTO REEL4'
  AND intento = 1
  AND hora_llamada = '19:16:08'
  AND created_at = TIMESTAMPTZ '2026-08-19 00:16:08.933+00';

DELETE FROM public.aos_llamadas
WHERE id = 37110
  AND fecha = DATE '2026-08-18'
  AND numero_limpio = '980547287'
  AND upper(coalesce(asesor,'')) = 'MIREYA'
  AND upper(coalesce(estado,'')) = 'CITA CONFIRMADA'
  AND tratamiento = 'CAPILAR'
  AND lead_id_origen = 5599
  AND upper(coalesce(origen,'')) = 'MARKETING'
  AND anuncio = 'CAPILAR- INJERTO REEL4'
  AND intento = 1
  AND hora_llamada = '19:23:27'
  AND created_at = TIMESTAMPTZ '2026-08-19 00:23:27.821+00';

-- Deliberately do not touch calls 36912 or 37062 and do not delete Agenda rows.
COMMIT;
