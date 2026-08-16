# KronIA K1 — CURRENT Certification Checkpoint — 2026-08-15

## Estado

Candidato de certificación K1. **No implica despliegue ni migración a producción.**

## Baseline

- `main` base al construir este candidato: `047188a215aab15aac7991f640595e287880500e`.
- P0 `aos_secure_write_v2` (#111) ya forma parte de la baseline.
- Runtime CURRENT preservado: `K1 -> F5 -> WA4 -> WA3 -> WA2 -> F4 -> Phase2/core`.
- El candidato es el commit que contiene este checkpoint; no se fija aquí su propio SHA para evitar una referencia circular.

## Alcance K1

- identidad derivada de sesión/app-token autoritativo;
- credenciales privadas server-side y compatibilidad Auth V3;
- cierre de mutaciones/lecturas sensibles directas por `anon`;
- gateway tipado para herramientas KronIA;
- `/api/agents/*`, `/api/send-email` y Studio detrás del borde K1;
- auditoría y feeds sanitizados;
- revocación de sesiones ante cambios de autoridad;
- adaptación Chrome/browser al token canónico;
- recovery que no reabre bypasses legacy;
- preservación de F5/WhatsApp y del staging existente.

## Migrations K1 exactas

1. `20260814170000_kronia_k1_private_credentials_auth_v3.sql`
2. `20260814171000_kronia_k1_app_token_control_plane.sql`
3. `20260814171500_kronia_k1_identity_sync.sql`
4. `20260814171600_kronia_k1_feed_schema_alignment.sql`
5. `20260814171800_kronia_k1_auth_v3_branded_alignment.sql`
6. `20260814172000_kronia_k1_team_profile_alignment.sql`
7. `20260814172100_kronia_k1_authority_session_revocation.sql`

Recovery: `supabase/rollbacks/20260814_kronia_k1_phase2_safe_recovery.sql`.

## Gates para declarar K1 certificada

El mismo SHA debe pasar:

- baseline Cartera antes de K1;
- compilación de las 7 migrations K1;
- certificado Auth/Identity/Control Plane;
- regresión Cartera después de K1;
- DB lint sin errores;
- contrato/runtime CURRENT y sintaxis Node/Python;
- smoke dinámico K1;
- boundary de secretos y autoridad;
- safe recovery;
- evidencia hash reproducible;
- zero residue del runner.

Después del CI debe volver a verificarse drift de `main`. Un cambio superpuesto en runtime/DB invalida el certificado y exige reconstrucción.

## Producción

Preflight previo confirmó que K1 aún no está aplicada en producción. No se hará mutación productiva desde este checkpoint. El cutover productivo requiere autorización expresa y post-check de permisos/RPC/identidad.

## Credenciales de proveedor

La eliminación de secretos del source no prueba por sí sola la revocación de una credencial histórica en el proveedor. La certificación final al 100% exige evidencia de que cualquier key previamente expuesta fue rotada/revocada, además de smoke de 2FA/email con la credencial vigente.
