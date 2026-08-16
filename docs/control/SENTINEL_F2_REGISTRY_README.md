# Sentinel F2 — Registry Usage Contract

`SENTINEL_SYSTEM_REGISTRY_V1.json` es la fuente machine-readable de topología para Sentinel a partir de F2.

Reglas de uso:

1. No usar el registry para declarar salud en tiempo real. En F2 todo estado observable es `UNKNOWN`.
2. No incorporar PHI/PII, payloads, mensajes, nombres de pacientes, teléfonos, emails, documentos, secretos o tokens.
3. Un nuevo HTML top-level en `app/public/` debe clasificarse en exactamente un dominio.
4. Un cambio en `app/railway.json` o en un spawn edge de la cadena Node debe reflejarse en `runtime.chain`.
5. Todo component/dependency referenciado debe existir en el registry.
6. Las relaciones y RPC listadas son el subset crítico por capability, no una copia completa del catálogo PostgreSQL.
7. El snapshot de `pg_catalog` es evidencia agregada; no certifica RLS/security posture.
8. `CLINICAL` usa boundary `metadata-only-no-PHI`.
9. Fases posteriores pueden añadir `signal_contracts`, pero no reescribir la identidad de domains/capabilities sin migration del registry schema.
10. `ci/sentinel/phase2_registry_contract.js` es el gate contra drift y false-green.
