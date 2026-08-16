# Sentinel F2 — Registry Change Policy

Cambios futuros al registry siguen estas reglas:

- **Surface drift:** alta/baja/rename de HTML top-level requiere actualización de dominio y evidencia.
- **Runtime drift:** cambio de Railway start command o spawn edge requiere actualizar `runtime.chain` y ejecutar el contrato.
- **Dependency drift:** nueva dependencia externa requiere `id`, tipo, criticality, evidence y estado inicial `UNKNOWN`.
- **Capability drift:** nueva capability requiere dominio, criticality, evidence, data-access relevante y estado inicial `UNKNOWN`.
- **Domain drift:** crear/renombrar dominio es cambio de taxonomía y requiere Impact Report para evitar romper F3–F13.
- **Health drift:** F2 nunca admite `HEALTHY`; la salud se deriva de signal contracts en fases posteriores.
- **Sensitive data:** no se permiten PHI/PII/secrets dentro del registry.
- **Schema drift:** todo cambio incompatible incrementa `schema_version` y debe incluir migración del consumidor Sentinel.

El registry se actualiza mediante branch → contract CI → PR → merge → Notion, nunca directamente en producción.
