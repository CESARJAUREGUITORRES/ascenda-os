# Web Release Standard V1

Status: **MANDATORY RELEASE GATE**

Applies to every public website, landing page, storefront, marketing surface, customer-facing web application and PWA maintained in this repository.

Authenticated/internal application screens still inherit the accessibility, security, performance, error-handling, privacy and observability rules below. SEO, Google Business Profile and WhatsApp requirements may be marked `N/A` when they do not logically apply.

A web-facing release must not be declared production-ready until every applicable item is either **PASS** or explicitly documented as **N/A with reason**.

## Core 20 — mandatory baseline

1. **Legal notice / terms / business identity**
   - Public site exposes the legally appropriate owner/operator identity and terms/contact information.
2. **Privacy policy**
   - Clear privacy notice covering collected data, purposes, processors, retention and user rights applicable to the product.
3. **Cookie / tracker consent**
   - Required when non-essential cookies or trackers are used.
   - Do not show a meaningless cookie banner when only strictly necessary storage is used.
   - Analytics/ads that require consent must not fire before consent.
4. **HTTPS enforced**
   - HTTP redirects to HTTPS.
   - No mixed content.
   - HSTS when deployment/platform permits it safely.
5. **Unique page title + meta description**
   - Meaningful, human-readable and page-specific.
6. **Structured data**
   - Use only schema.org types that truthfully match the page/business/content.
   - Validate JSON-LD and never fabricate ratings/reviews/business facts.
7. **Sitemap + robots.txt**
   - Production sitemap is valid and current.
   - robots.txt is intentional.
   - No accidental production `noindex`; staging/previews must not be indexed.
8. **Favicon / app identity**
   - Favicon and appropriate icon set present.
   - PWA surfaces also require manifest/app icons.
9. **Image alternative text**
   - Meaningful images have useful `alt`.
   - Decorative images use empty alt rather than spam text.
10. **Optimized images**
    - Prefer modern formats (AVIF/WebP when supported), responsive sizes, dimensions declared and lazy loading when appropriate.
11. **Load performance optimized**
    - Avoid unnecessary JS, blocking assets, oversized fonts/media and unbounded third-party scripts.
12. **Color contrast**
    - Meet WCAG 2.2 AA for normal UI text/controls unless a documented exception exists.
13. **Responsive/mobile quality**
    - No horizontal overflow, clipped controls, unreadable text or hover-only critical actions.
14. **Custom 404**
    - Branded, useful recovery/navigation path.
    - Public applications should also have a safe 500/error experience.
15. **Broken links repaired**
    - No known broken critical internal links or CTAs at release.
16. **Forms protected against abuse**
    - Server-side validation, rate limiting and anti-spam control appropriate to risk.
    - CAPTCHA only when needed; honeypot/risk controls are acceptable alternatives.
17. **WhatsApp visible when it is a real conversion channel**
    - Required only for businesses whose approved customer journey uses WhatsApp.
    - Link/number must be current, accessible and tracked consistently.
18. **Analytics installed and governed**
    - Measurement must be intentional, tested and privacy-consistent.
    - Consent-required analytics/ads must respect consent state.
19. **One primary call to action**
    - Each page/hero/state should have one clearly dominant primary CTA.
    - Secondary actions are allowed; the rule prevents competing primary conversions, not all additional buttons.
20. **Google Business Profile when locally applicable**
    - Required for eligible local/physical businesses where Google Business Profile is part of discovery.
    - Name/address/phone/hours must match the site and canonical business data.

## Extended mandatory quality gates

21. **Canonical URL + social metadata**
    - Canonical URL where appropriate.
    - Open Graph/social preview title, description and image for public shareable pages.
    - `hreflang` only when multilingual alternates actually exist.
22. **Accessibility beyond contrast**
    - Keyboard navigation, visible focus, semantic headings, labels, accessible names, sensible tab order and reduced-motion handling where applicable.
23. **Security headers / browser hardening**
    - Use CSP where feasible, `X-Content-Type-Options`, appropriate `Referrer-Policy`, frame/embedding controls and a minimal `Permissions-Policy`.
    - Never expose service-role keys, secrets or privileged credentials to browser code.
24. **Privacy / indexing boundaries**
    - Authenticated, personal, transactional and sensitive pages are not publicly indexable unless explicitly intended.
    - Minimize PII in URLs, analytics, logs and client-side errors.
25. **Core Web Vitals target**
    - Target p75: LCP <= 2.5 s, INP <= 200 ms, CLS <= 0.1 on representative production traffic/devices.
    - A known regression requires an explicit exception/owner decision.
26. **Observability**
    - Production errors have a monitored destination (for example Sentry or equivalent) when the product has an observability stack.
    - Do not send secrets or unnecessary PII to telemetry.
27. **Release smoke + rollback**
    - Verify the exact deployed SHA/version, homepage/critical routes, key CTA/form, 404 and authentication boundary when applicable.
    - Know the rollback/redeploy path before closing the release.
28. **Staging/previews**
    - Preview/staging environments must not accidentally become canonical/indexed production.
    - Test credentials/fixtures must not leak to public production.
29. **PWA-specific gate when applicable**
    - Valid manifest, icons, scope/start URL, service worker update behavior, install flow and permission onboarding.
    - Browser/OS permission prompts remain native; app-owned onboarding uses product branding.
30. **Third-party dependency hygiene**
    - Remove unused pixels/widgets/scripts.
    - Review privacy/security/performance impact of embedded chat, maps, fonts, video, analytics and payment widgets.

## Release evidence

For every web-facing release, attach or record evidence for applicable items:

- exact commit/deployment SHA;
- public URL/environment;
- desktop + mobile smoke;
- responsive check;
- critical CTA/form result;
- robots/sitemap/indexability result;
- privacy/cookie behavior;
- accessibility spot-check;
- security-header/HTTPS check;
- performance evidence or known exception;
- analytics/observability check;
- 404/error-path check;
- rollback path.

## Rule for AI agents / developers

Do not treat visual completion as production readiness.

Before declaring a website, landing page, storefront or public web flow complete:

`BUILD PASS -> WEB RELEASE GATE PASS -> DEPLOY EXACT SHA -> PUBLIC SMOKE -> PRODUCTION READY`

If an item is not applicable, state `N/A` and why. Never silently skip it.
