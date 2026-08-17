# F17 History Equivalence Audit

**Mode:** static, read-only comparison of the canonical repository migration against hashes derived from the already-applied production migration statement.

## Function blocks

| Function | Live normalized MD5 | Local normalized MD5 | Live raw length | Local raw length | Result |
|---|---|---|---:|---:|---|
| `aos_cia_channel_prepare_send_v1` | `4f543dc1cdd14ff5de45cbfb2e46bf22` | `4f543dc1cdd14ff5de45cbfb2e46bf22` | 3929 | 4239 | **PASS** |
| `aos_cia_channel_register_canary_recipient_v1` | `414bbc58a5cac480d8d8d25b4b9046ad` | `414bbc58a5cac480d8d8d25b4b9046ad` | 1813 | 1869 | **PASS** |
| `aos_cia_channel_mark_dispatch_v1` | `ec44383bc5d55171a077ec275ca07c0a` | `ec44383bc5d55171a077ec275ca07c0a` | 2589 | 2674 | **PASS** |
| `aos_cia_channel_ingest_inbound_v1` | `658086ad3f58013642ef56c97013c8a6` | `658086ad3f58013642ef56c97013c8a6` | 1794 | 1855 | **PASS** |
| `aos_cia_channel_record_provider_event_v1` | `ba6cc31ed74e9199e135d75ef1178d2f` | `ba6cc31ed74e9199e135d75ef1178d2f` | 1354 | 1415 | **PASS** |

## Auxiliary DDL / ACL

| Surface | Live normalized MD5 | Local normalized MD5 | Result |
|---|---|---|---|
| `ALTER TABLE expires_at` prefix | `5600c40c0f56929e8e79500b2553864a` | `5600c40c0f56929e8e79500b2553864a` | **PASS** |
| service-only ACL revoke/grant block | `0f6f2a8e7b7dee77d4b7f820fbac20ee` | `0f6f2a8e7b7dee77d4b7f820fbac20ee` | **PASS** |

Repository-only descriptive `COMMENT ON FUNCTION` statements after the ACL block: **4**.

## Decision

**DURABLE/SECURITY SQL EQUIVALENT.** All five function blocks, the `expires_at` DDL and service-only ACL block match production after comment/whitespace normalization. Whole-file MD5 drift is attributable to formatting and repository-only descriptive comments. The final F17 file is eligible for version alignment, subject to replay-order validation with the four superseded intermediate production migrations represented as explicit no-op history tombstones.
