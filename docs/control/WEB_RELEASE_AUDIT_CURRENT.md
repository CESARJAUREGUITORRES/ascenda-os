# ASCENDA OS — Web Release Audit CURRENT

**Captured:** 2026-09-15  
**Standard:** `docs/control/WEB_RELEASE_STANDARD_V1.md`  
**Runtime mutation status:** **DEFERRED** while the current HIGH/CRITICAL portfolio lock belongs to another active workstream.

## Inventory

Read-only scan of the current production frontend source:

- `app/public/*.html` plus `app/index.html`;
- **47 HTML files inspected**;
- **20 full HTML documents**;
- **27 shell fragments/partials**.

Fragments are not expected to carry their own `<html>`, `<title>`, viewport or favicon. Those requirements belong to the owning shell/document.

## Current findings

### Full documents

- title present: **19 / 20**;
- viewport present: **19 / 20**;
- meta description present: **0 / 20**;
- explicit robots/noindex present: **2 / 20**;
- explicit favicon present: **4 / 20**.

The full-document exception without normal title/viewport metadata is `app/public/admin-patients.html` and must be classified/normalized before runtime certification.

### Cross-surface findings

Across the 47 scanned HTML files:

- raw images missing `alt`: **38**;
- files containing native `alert()`, `confirm()` or `prompt()`: **24**.

These counts include fragments because accessibility and branded-dialog rules apply to the rendered UI even when the source is injected into a parent shell.

## Classification

ASCENDA OS is primarily an authenticated internal operational application.

Therefore:

- public SEO discovery is **N/A** for normal admin/advisor panels;
- sitemap is **N/A** for the private application surface;
- Google Business Profile is **N/A** to the authenticated app itself;
- WhatsApp CTA is **N/A** to internal operating panels unless a specific public conversion page explicitly requires it;
- transactional/public utility pages such as booking/survey/recovery should still be treated as privacy-sensitive and should not be indexed by default.

## Recommended runtime remediation — queued, not yet executed

Do not implement these while another HIGH/CRITICAL program owns the repository lock.

### R1 — global private-app HTTP hardening

Prefer one server/shell authority rather than hand-editing dozens of pages:

- `X-Robots-Tag: noindex, nofollow, noarchive` for authenticated/private application responses;
- `X-Content-Type-Options: nosniff`;
- `Referrer-Policy: strict-origin-when-cross-origin`;
- frame protection compatible with actual ASCENDA embedding requirements;
- minimal `Permissions-Policy`;
- HSTS at the HTTPS production boundary when deployment topology is confirmed.

CSP must be introduced only after auditing current inline scripts/styles and external providers. Do not deploy a strict CSP blindly.

### R2 — robots/private indexing

Add an intentional `robots.txt` policy for the production application and validate that previews/staging are also non-indexable.

Do not create a public sitemap for private app screens.

### R3 — document metadata normalization

For the 20 full documents:

- unique title;
- viewport;
- favicon;
- private/noindex metadata or equivalent response header;
- meta description only where the document is meaningfully shareable/public; for strictly internal screens it is optional once noindex is enforced.

### R4 — accessibility repair

- add meaningful `alt` to informative images;
- use empty `alt=""` for decorative images;
- validate keyboard/focus/labels in interactive screens;
- maintain WCAG 2.2 AA contrast.

### R5 — branded dialogs

Replace app-owned browser `alert/confirm/prompt` with ASCENDA branded modal/toast/confirmation components.

Native browser/system dialogs remain allowed only when the platform requires them, for example permission prompts or unavoidable `beforeunload` protection.

### R6 — error/404 experience

Introduce one branded 404/error path at the server/shell layer instead of maintaining page-specific ad-hoc responses.

### R7 — automated CI scanner

Create a web-release scanner that:

- distinguishes full HTML documents from fragments;
- enforces metadata only on full documents;
- rejects new native dialogs;
- rejects new raw images without `alt`;
- validates private-app indexing policy;
- checks required common security headers;
- records exceptions explicitly.

The scanner must be additive and must not cause unrelated HIGH/CRITICAL workflows to mutate production.

## Security finding requiring separate handling

The read-only audit of the current server source exposed configuration values embedded directly in source code that should be reviewed under the repository's existing security/secrets process.

Do **not** print those values into issues, docs, logs or chat. Do **not** perform an ad-hoc credential rotation from this web-quality workstream.

Create a separate security remediation gate when the active portfolio lock permits it.

## Release state

`ASCENDA OS WEB RELEASE STANDARD V1` is **NOT YET RUNTIME-CERTIFIED**.

Governance is active now; runtime remediation is queued behind the active workstream lock.

Closure requires:

1. R1-R7 implemented on an isolated branch;
2. relevant CI green;
3. exact-SHA deploy;
4. desktop/mobile authenticated smoke;
5. critical panel regression check;
6. direct verification of headers/indexability;
7. no regression in current Google/Conversations/Revenue lanes.
