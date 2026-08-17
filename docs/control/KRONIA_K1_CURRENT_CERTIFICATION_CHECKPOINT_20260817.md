# KronIA K1 — CURRENT v4 Certification Checkpoint — 2026-08-17

## Estado

Candidato de certificación **CRITICAL** para K1. Este checkpoint **no autoriza despliegue, merge ni migración productiva**.

## Baseline CURRENT

- Último `main` absorbido y revalidado en el final-sync: `9ef4ece6c7e764155a97aa2dec63751df38fe461`.
- El final-sync absorbió los cambios CURRENT de F5 y volvió a pasar los contratos F5/K1.
- P0 `aos_secure_write_v2` ya forma parte de la baseline y se prueba explícitamente antes y después de K1.
- Runtime productivo preservado: `Sentinel preload -> K1 -> Phase S -> F5 -> WA4 -> WA3 -> WA2 -> F4 -> Phase2/core`.
- La versión de migración productiva observada antes de preparar el release fue `20260817161248`; las siete migraciones K1 se renumeraron a un bloque posterior para evitar un despliegue fuera de orden.
- El SHA certificado será el commit exacto que active y pase `.github/workflows/kronia-k1-v4-certificate.yml`; no se fija aquí para evitar referencia circular.

## Alcance de seguridad K1

- identidad derivada exclusivamente de Auth V3 / `aos_app_token` autoritativo;
- credenciales de contraseña privadas server-side;
- credenciales de proveedores en `aos_integration_secrets_v1`, sin reintroducir `api_key/api_secret` en el catálogo público;
- cierre de mutaciones directas sensibles por `anon/authenticated`;
- lectura de PII de Equipo mediante `aos_team_feed_v3` con admin + 2FA + `admin-team`;
- gateway tipado para herramientas KronIA;
- `/api/agents/*`, `/api/send-email` y Studio detrás del borde K1 con autoridad admin + 2FA;
- protección de origen, rate limit, tamaño de body y bloqueo de contraseñas por email;
- auditoría y feeds sanitizados;
- revocación de sesiones ante cambios de autoridad;
- Chrome popup y widget flotante alineados con Auth V3;
- no persistencia del password ni del historial de conversación en `chrome.storage`;
- recovery que conserva vault, RLS, PII y retiro de bypasses legacy;
- preservación de Sentinel, Phase S, F5, WhatsApp y controles de upload existentes.

## Migraciones K1 exactas

1. `20260817170000_kronia_k1_private_credentials_auth_v3.sql`
2. `20260817170100_kronia_k1_app_token_control_plane.sql`
3. `20260817170200_kronia_k1_identity_sync.sql`
4. `20260817170300_kronia_k1_feed_schema_alignment.sql`
5. `20260817170400_kronia_k1_auth_v3_branded_alignment.sql`
6. `20260817170500_kronia_k1_team_profile_alignment.sql`
7. `20260817170600_kronia_k1_authority_session_revocation.sql`

Recovery: `supabase/rollbacks/20260814_kronia_k1_phase2_safe_recovery.sql`.

## Gates obligatorios del mismo SHA

El release candidate solo puede considerarse certificado si el mismo commit pasa:

- `behind_by = 0` respecto del `main` vigente inmediatamente antes del certificado;
- orden de release: exactamente 7 migraciones `2026081717*kronia_k1*.sql` y 0 migraciones K1 antiguas;
- reproducción del provider-vault CURRENT antes de K1;
- Cartera pgTAP `1..96` antes de K1;
- P0 `PHASE2_SECURE_WRITE_JSONB_P0=PASS` antes de K1;
- compilación secuencial de las 7 migraciones K1;
- preservación del secreto Resend únicamente en el vault privado;
- certificado Auth V3 / Identity / Control Plane / Team PII;
- branded Auth V3 usando `aos_integration_secrets_v1`;
- idempotencia del provider-vault CURRENT después de K1;
- Cartera pgTAP `1..96` después de K1;
- P0 secure-write después de K1;
- DB lint sin errores;
- contrato F5 + runtime `K1 -> Phase S -> F5`;
- contrato estático de seguridad (`SECURITY DEFINER`, grants, secretos, PII, browser y Chrome);
- smoke dinámico del proxy K1;
- safe recovery sin reabrir secretos, PII ni RPCs raw;
- evidence root SHA-256 reproducible;
- zero residue del runner.

Cualquier drift posterior de `main` que toque runtime, auth, DB, secretos o superficies compartidas invalida el certificado y exige resync + recertificación.

## Producción

El preflight read-only confirmó que K1 aún no estaba aplicada en producción. Este flujo no modifica producción. El cutover productivo requerirá autorización expresa, aplicación controlada de las siete migraciones, despliegue del runtime K1 y post-check de permisos/RPC/identidad/2FA.

## Bloqueo externo de certificación total

Eliminar un secreto del source o moverlo al vault no demuestra por sí solo que una credencial históricamente expuesta haya sido invalidada en el proveedor. Para declarar **K1 productivamente certificada al 100%** todavía se exige evidencia externa de rotación/revocación de cualquier key Resend previamente expuesta y un smoke real de entrega 2FA/email con la credencial vigente.

Hasta obtener esa evidencia, un PASS completo del CI certifica el **release candidate de código y migraciones**, pero no autoriza afirmar cierre productivo total.
