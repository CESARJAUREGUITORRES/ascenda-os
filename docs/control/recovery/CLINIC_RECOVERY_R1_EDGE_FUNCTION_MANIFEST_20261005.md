# ASCENDA CLINIC — RECOVERY-R1 LEGACY EDGE FUNCTION MANIFEST

**Captured:** 2026-10-05  
**Legacy project:** `ituyqwstonmhnfshnaqz`  
**Mode:** metadata-only preservation  

## Security rule

Raw legacy Edge Function source is intentionally **not** committed to this public repository.

Reason: R1 inspection found that at least one legacy recovery function contains embedded sensitive recovery material. Public recovery evidence is therefore restricted to slug, version, JWT setting, deployment status and Supabase-provided function hash.

No secret/token/passphrase/service-role value is reproduced here.

## Legacy function inventory

| Function | Version | Status | verify_jwt | Supabase function hash | R1 classification |
|---|---:|---|---|---|---|
| `f5-private-ingest-bridge` | 1 | ACTIVE | false | `42742a4a2d54b4f305ee3a830ea4780c672bcccc26d1e1f711b0ee7ae1a1e49e` | recovery ingest bridge / custom transport authorization |
| `f5-recovery-run-20260815` | 1 | ACTIVE | false | `b7689a1fa45283547de6b41b59f0b30f4a1fa6c6f686b0232d76208ba404159e` | sensitive governed recovery runner; raw source PRIVATE ONLY |
| `f5-chat-recovery` | 2 | ACTIVE | true | `f5f1300777a8a6db49e70097b2be11a496c78540da9d8c5778fd8e53c5bf5663` | compressed bundle / idempotent source-row recovery path |
| `f5-brotli-probe` | 2 | ACTIVE | true | `e9d8a991f5449f0ad7ee58b3fe1a42ecebb67c5f9fbbcad797c75cd4fb617cd0` | retired responder (HTTP 410) |
| `f5-env-presence-probe` | 4 | ACTIVE | true | `8d6acdc915f49407af2f4745aaeacac2bd19c9257b3a1fea1e2656b57f150af5` | retired responder (HTTP 410) |
| `f5-github-cipher-ingest` | 2 | ACTIVE | true | `9cc975fe8b296d7578fd7d08f5db8626c5463f94de56c19be8515a7a1f9c9885` | retired responder (HTTP 410) |
| `f5-status-once` | 4 | ACTIVE | true | `84ebb18d1c4c32da5e00405ac22e7bdb5d2632b3dc626a991ca47a3d8f364d8a` | retired responder (HTTP 410) |

## Recovery semantics observed safely

Without storing source payloads, R1 confirmed that the active historical recovery path references:

- the governed compact-row ingest RPC;
- the historical patient source-row staging domain;
- an idempotent recovery model;
- the same six source SHA-256 identities independently certified in `CLINIC_RECOVERY_R1_SOURCE_MANIFEST_20261005.md`.

The four retired functions above should not be blindly redeployed into the replacement Supabase. Their existence is preserved for historical completeness only.

## Cutover rule

No Edge Function from the legacy project is to be deployed to replacement project `gmokacpixfbrsiilsxln` until:

1. its current necessity is proven;
2. secrets are moved to managed environment secrets;
3. hardcoded sensitive material is removed;
4. authentication mode is revalidated;
5. the target DB schema/RPC dependency exists and passes isolated tests.

## R1 result

**LEGACY EDGE FUNCTION METADATA PRESERVATION = PASS**

Seven function identities are recoverably documented without exposing sensitive source material.