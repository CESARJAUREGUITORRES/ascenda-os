# ASCENDA OS — ZERO-COST VALIDATION STANDARD

**Estado:** CURRENT / CANONICAL  
**Fecha de adopción:** 2026-08-14  
**Ámbito:** todos los workstreams de ASCENDA OS  
**Objetivo:** obtener evidencia reproducible de calidad, seguridad y rollback sin crear infraestructura cloud pagada innecesaria.

---

## 1. PRINCIPIO

Zero-Cost Staging es el estándar preproductivo por defecto de ASCENDA OS.

No significa omitir staging. Significa que la primera y principal capa de staging debe ejecutarse con infraestructura efímera y reproducible ya disponible en GitHub Actions / Supabase CLI / PostgreSQL local, sin conectar CI a producción y sin copiar PII/PHI real.

Una Supabase Cloud Development Branch, proyecto duplicado, entorno Railway adicional u otra infraestructura con costo NO es requisito automático para declarar una fase validada. Solo se incorpora cuando un riesgo o dependencia no puede certificarse suficientemente con el circuito Zero-Cost + preflight/canary controlado.

---

## 2. TERMINOLOGÍA OBLIGATORIA

Para evitar ambigüedad, los agentes deben distinguir:

### GitHub `staging`
Rama de integración/preproducción de código. No implica una base Supabase adicional ni costo cloud.

### Zero-Cost Staging
Entorno efímero creado por CI usando Supabase CLI/PostgreSQL/Docker y fixtures/contracts sin PII. Se destruye al terminar el workflow. Es el staging técnico por defecto para migraciones, RPC, RLS, autorización, performance y rollback.

### Runtime staging / fixture
Entorno temporal de UI/runtime, cuando exista, usado para smoke visual/E2E. Debe reutilizar infraestructura disponible y no debe asumirse como requisito permanente.

### Supabase Cloud Development Branch
Base remota separada dentro de Supabase Cloud. Puede tener costo por hora. Es EXCEPCIONAL: requiere justificación técnica, cotización actual, Impact Report y aprobación explícita del propietario antes de crearla.

---

## 3. LOOP UNIVERSAL ZERO-COST

Todo cambio MEDIUM/HIGH/CRITICAL debe adaptar este circuito al riesgo real:

1. **Bootstrap / recovery**
   - leer `AGENTS.md`, `SECURITY.md`, `docs/control/ASCENDA_CONTROL_MASTER.md`;
   - localizar master/index/checkpoint del workstream;
   - verificar branch, PR, CI y baseline reales.

2. **Impact analysis**
   - localizar código productivo;
   - mapear RPC/tablas/triggers/consumidores;
   - clasificar riesgo;
   - identificar invariantes, blast radius y rollback.

3. **Branch aislada**
   - `feature/*`, `fix/*`, `security/*`, `data/*` o `chore/*`;
   - nunca experimentar en `main`.

4. **Contratos y tests antes del release**
   - sintaxis/static gates;
   - schema/consumer contracts;
   - pgTAP o pruebas equivalentes;
   - autorización positiva/negativa;
   - performance cuando aplique;
   - zero-residue / rollback-only cuando aplique.

5. **Zero-Cost Staging**
   - GitHub Actions levanta Supabase/PostgreSQL local efímero;
   - aplica contratos/fixtures sintéticos sin datos clínicos/personales reales;
   - compila exactamente las migraciones de release;
   - ejecuta lint y pruebas;
   - ejecuta y verifica rollback;
   - genera evidencia/artifact/digest;
   - destruye la base al finalizar.

6. **GitHub integration gate**
   - CI verde;
   - PR revisable;
   - branch `staging` cuando el workstream use integración progresiva;
   - documentación/checkpoint actualizado.

7. **Production read-only preflight**
   - verificar checksums/definiciones/ACL/consumidores/versiones sin mutar producción;
   - confirmar que la baseline real no derivó desde la certificada;
   - confirmar snapshot/restore/rollback disponible cuando corresponda.

8. **Canary / additive rollout cuando el riesgo lo exija**
   - preferir cambios backward-compatible/additive;
   - habilitar primero en alcance mínimo: usuario/rol/sede/panel autorizado;
   - mantener fallback mientras sea seguro;
   - observar smoke y auditoría.

9. **Cutover**
   - cerrar legacy/bypass solo después de canary exitoso cuando la arquitectura lo permita;
   - HIGH/CRITICAL requiere autorización explícita antes de mutar producción.

10. **Post-deploy smoke**
    - validar flujos reales afectados;
    - validar negativas de seguridad;
    - reconciliar datos antes/después;
    - verificar ausencia de regresiones laterales.

11. **Rollback readiness / recovery**
    - rollback debe ser ejecutable, no meramente descrito;
    - cuando sea seguro, probarlo en Zero-Cost Staging;
    - documentar qué estado no puede revertirse y cómo se recupera (p. ej. tokens hash → re-login).

12. **Certification**
    - registrar evidencia, run IDs, digest/checksum y cobertura;
    - diferenciar `ZERO-COST CERTIFIED`, `CANARY CERTIFIED`, `PRODUCTION CERTIFIED`;
    - no usar “100%” si existen gates del alcance todavía abiertos.

---

## 4. GATES MÍNIMOS POR RIESGO

### LOW
- diff revisado;
- sintaxis/lint aplicable;
- smoke.

### MEDIUM
- CI;
- consumer contract;
- Zero-Cost Staging cuando toca DB/runtime compartido;
- rollback proporcional.

### HIGH
Obligatorio además:
- Impact Report;
- migration versionada si aplica;
- autorización positiva/negativa por rol;
- Zero-Cost Staging;
- rollback ejecutado/probado;
- preflight productivo read-only;
- smoke real tras release;
- reconciliación de datos.

### CRITICAL
Obligatorio además:
- threat/trust-boundary review;
- pruebas negativas explícitas;
- secrets/ACL/RLS/SECURITY DEFINER review según aplique;
- artefacto de deploy equivalente al certificado;
- canary/additive rollout cuando sea técnicamente posible;
- final security review con 0 HIGH/CRITICAL abiertos dentro del scope;
- autorización explícita del propietario antes del primer cambio productivo;
- plan de recuperación inmediatamente ejecutable.

---

## 5. PROPIEDADES DE SEGURIDAD DEL ZERO-COST STAGING

El workflow debe procurar estas invariantes:

- no usar service-role/password de Supabase producción;
- no copiar pacientes, DNI, teléfonos, emails, fotos, historia clínica ni otra PII/PHI como fixtures;
- usar datos sintéticos o agregados no identificables;
- pinnear versiones relevantes del toolchain cuando la reproducibilidad lo requiera;
- aplicar migraciones de release EXACTAS, no versiones simplificadas que oculten incompatibilidades;
- ejecutar `supabase db lint --level error` o equivalente;
- destruir el entorno temporal al terminar, incluso en fallo (`if: always()`);
- guardar evidencia con retención finita;
- no modificar pruebas para ocultar un fallo: se corrige implementación/fixture/contrato.

---

## 6. CUÁNDO ESCALAR A INFRAESTRUCTURA CLOUD PAGADA

Una Supabase Cloud Development Branch u otro entorno pagado solo se justifica si existe al menos una dependencia material que no pueda reproducirse adecuadamente mediante Zero-Cost + canary, por ejemplo:

- comportamiento gestionado específico del proveedor imposible de emular localmente;
- integración externa que exige endpoint cloud real;
- Realtime/Storage/Auth administrado cuyo contrato remoto sea el objeto del cambio;
- prueba de red/infra/latencia/region que sea parte del riesgo;
- necesidad de validación remota prolongada por múltiples equipos.

Antes de crearla:
1. explicar qué riesgo específico resuelve;
2. demostrar por qué Zero-Cost no es suficiente;
3. obtener costo actual del proveedor;
4. informar recurrencia y mecanismo de borrado;
5. obtener autorización explícita.

Por defecto, crear entornos efímeros y eliminarlos al cerrar el gate. No mantener staging cloud permanente solo por costumbre.

---

## 7. PRECEDENTES ASCENDA

Este estándar generaliza patrones ya validados en:

- Sales Intelligence V2 — Zero-Cost Staging con Supabase local, migrations, lint, pgTAP, performance y evidencia;
- Sales Intelligence Admin Activation — CI + Zero-Cost + seguridad + rollback + preflight/smoke productivo autorizado;
- Cartera Phase 2 — CI, contratos, pgTAP, lint, Zero-Cost y rollout bloqueado hasta gates coordinados;
- Commercial Intelligence / Call Center — branches feature → GitHub `staging`, rollback-only QA, performance, security gates y Definition of `100_COMPLETE`;
- KronIA K1 — certificado de auth/session/secrets/RPC boundary con Supabase aislado, pruebas negativas, rollback y equivalencia CI↔runtime Railway.

---

## 8. FUENTE DE VERDAD Y RECOVERY

Esta política es transversal. Si un workstream define gates adicionales, se suman; no reemplazan este estándar salvo decisión documentada.

Precedencia:
1. `AGENTS.md` / `SECURITY.md`;
2. este estándar;
3. master/index del workstream;
4. Impact Reports / validation reports;
5. branch/PR/CI actual;
6. Notion como visualización derivada.

Cuando un agente retome ASCENDA debe verificar el estado real antes de asumir que un run o certificado antiguo sigue vigente.

---

## 9. REGLA DE COSTO

**Objetivo: máxima seguridad y reproducibilidad con costo incremental mínimo.**

No confundir ahorro con reducción de controles. Zero-Cost Staging existe para mantener controles fuertes sin crear infraestructura pagada innecesaria. Si el riesgo exige gasto, seguridad prevalece, pero el costo debe ser explícito, justificado y autorizado.
