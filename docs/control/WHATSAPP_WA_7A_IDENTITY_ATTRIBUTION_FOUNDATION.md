# WA-7A — WhatsApp Identity & Attribution Foundation

**Decision date:** 2026-08-25 America/Lima  
**Status:** ARCHITECTURE BASELINE / PRE-IMPLEMENTATION  
**Parent program:** `WHATSAPP-REVENUE-HUB-V2`  
**Baseline:** `main@e454c9535eeff00c665794c2ac319dcc38bdf13f`  
**Mutable lane:** `WA-7A`

## 1. Decision

WA-7A is expanded from `Meta Attribution Ingress` to:

`WhatsApp Identity & Attribution Foundation`.

Reason: the 2026 WhatsApp username rollout makes consumer phone numbers optional in messaging relationships. Building attribution on the existing phone-first gateway would create identity loss/duplication and routing failures.

## 2. Evidence classification

### Confirmed provider behavior

Current provider documentation confirms:

- WhatsApp usernames can mask a consumer phone number;
- BSUID is supplied as the business-scoped routing identity;
- phone may be absent;
- username is informational and does not control delivery;
- BSUID is scoped to a business portfolio;
- BSUID may regenerate if the WhatsApp user changes phone number;
- outbound BSUID messaging is supported for normal messaging types where rollout/provider support permits;
- one-tap/zero-tap/copy-code authentication templates require phone numbers;
- Contact Book can preserve phone+BSUID relationships but is portfolio-scoped and configurable.

### Engineering evidence, not policy authority

Public BSP/open-source migrations show recurring implementation hazards:

- duplicate contacts when phone+BSUID later becomes BSUID-only;
- split conversation history;
- phone validators corrupting/rejecting BSUID values;
- reply/status paths that assume E.164;
- need for recipient abstraction and identity aliases.

ASCENDA treats these as design evidence. Policy/permission decisions remain governed by current Meta/provider documentation at implementation and LIVE time.

## 3. Non-goals

WA-7A does not:

- create a new CRM/customer master;
- infer customer identity from username;
- infer attribution from phone;
- build Meta Ads bulk sync (`WA-7B`);
- build the bulk campaign sender;
- activate AI/Copilot/auto-routing;
- scrape/discover consumer usernames;
- bypass marketing consent/eligibility rules.

## 4. Identity entities

### Canonical person/contact

Owned by existing ASCENDA identity boundaries.

### WhatsApp channel alias

Minimum conceptual fields:

- `canonical_identity_id` or governed unresolved reference;
- `business_portfolio_id`;
- `bsuid`;
- `username` nullable/display-only;
- `phone_e164` nullable;
- `status`;
- `valid_from`;
- `valid_to`;
- `superseded_by`;
- `observed_at`;
- provider evidence reference.

Optional provider fields such as `parent_bsuid` may be preserved when actually emitted and understood.

### Channel recipient

Provider-neutral interface:

```text
ChannelRecipient
- channel: WHATSAPP
- kind: PHONE | BSUID
- value
- portfolio_id
```

Transport adapters map this to Meta/BSP-specific payload fields.

## 5. Identity resolution rules

- exact existing alias match is strongest channel continuity evidence;
- BSUID cannot be assumed universal across portfolios;
- username similarity provides no automatic merge authority;
- phone can be a matching signal, but conflicting canonical identities fail closed;
- transition from phone-visible to BSUID-only must retain the same conversation/contact when evidence supports continuity;
- newly disclosed phone joins existing identity only through governed resolution;
- identifier update events preserve old→new lineage.

## 6. Contact verification

Contact facts should carry source and confidence/verification state.

Suggested verification values:

`VERIFIED / CLAIMED / UNKNOWN / CONFLICT`.

Suggested sources:

`META_CONTACT_REQUEST / EXISTING_CRM / LEAD_FORM / MANUAL / IMPORT / PROVIDER_CONTACT_BOOK / OTHER`.

`REQUEST_CONTACT_INFO` is the preferred native mechanism when the product legitimately needs the user's phone. A manually typed or forwarded contact must not silently become verified ownership.

## 7. Attribution / provenance entities

Identity and touchpoint are different entities.

### Channel identity

Who/which WhatsApp relationship is speaking:

`BSUID / PHONE`.

### Acquisition touchpoint

Why/how the conversation originated:

- `ctwa_clid` or provider-equivalent CTWA click id;
- referral/source id/type;
- source URL when supplied;
- `ad_id`;
- `lead_id`;
- campaign source;
- headline/body when permitted;
- immutable raw/sanitized evidence;
- provider message/event IDs;
- received/observed timestamp.

A single canonical person may own multiple touchpoints.

## 8. Ingress ordering

Target:

`signed webhook → replay/idempotency gate → identity-safe envelope → provenance parser → immutable touchpoint → conversation projection → canonical identity resolver`.

Do not digit-normalize unknown sender identifiers before identifying their type.

## 9. Marketing foundation

Future campaigns must operate on governed WhatsApp recipients.

Separate:

1. **Identity** — whom the channel relationship represents.
2. **Reachability** — whether WhatsApp can technically address the recipient.
3. **Marketing eligibility** — whether the recipient may receive the intended marketing category at that time.

Suggested eligibility metadata:

- consent/eligibility state;
- preference stop/resume state when provider emits it;
- suppression reason;
- last observed/checked time;
- policy/provider evidence.

No inference:

`BSUID present → marketing consent`.

## 10. Consumer vs business username

### Consumer username

- optional;
- user-controlled;
- mutable;
- display/discovery mechanism inside WhatsApp;
- never canonical key;
- never cold-prospect import key.

### Business username

May become a valid inbound discovery/acquisition source. Preserve explicit evidence of that source when available; do not fabricate provenance merely because the business owns a username.

## 11. Current ASCENDA gap

`app/wa-gateway.js` currently assumes phone identity:

- `normalizePhone(msg.from)`;
- normalized `wa_id` contact comparison;
- `from_number` as inbound identity;
- outbound `to` requires 8–15 digits.

This is the first implementation boundary to change.

## 12. Required CI contracts before DB/product expansion

At minimum:

1. BSUID-only inbound survives parsing unchanged.
2. phone+BSUID inbound preserves both identifiers.
3. username never controls routing.
4. PHONE outbound remains compatible.
5. BSUID outbound does not pass through E.164 validation.
6. auth templates reject BSUID where provider requires phone.
7. contact/identity continuity does not duplicate when phone disappears.
8. identifier update preserves lineage.
9. touchpoint and channel identity remain separate.
10. absent referral/CTWA data does not fabricate attribution.
11. replay/idempotency remains exact.
12. existing WA-3 owner/2FA/24h send authority remains intact.

## 13. Subphase order

`WA-7A.0 Identity Compatibility`
→ `WA-7A.1 Identity Resolution`
→ `WA-7A.2 Verification & Continuity`
→ `WA-7A.3 Attribution Ingress`
→ `WA-7A.4 Marketing Eligibility Foundation`.

Do not skip 7A.0 to implement CTWA fields first.

## 14. LIVE hold

Supabase HTTP 402 currently prevents fresh production certification. Offline/code/CI work may continue. Any provider behavior that cannot be proven offline remains explicitly `LIVE_PENDING`.

## 15. Revalidation rule

Usernames/BSUID rollout and provider behavior are actively changing during 2026. Before each externally dependent implementation slice and before LIVE certification:

- re-check current Meta/provider documentation;
- compare current payload examples/field names;
- keep provider-specific names in adapters;
- update this contract if authoritative behavior changes.

## 16. External baseline references

- Twilio changelog — WhatsApp Usernames supported, July 7 2026:
  `https://www.twilio.com/en-us/changelog/whatsapp-usernames`
- Twilio key concepts — usernames, BSUID, Contact Book, rollout:
  `https://www.twilio.com/docs/whatsapp/key-concepts`
- Twilio developer guidance — identity migration, July 29 2026:
  `https://www.twilio.com/en-us/blog/products/whatsapp-just-changed-how-customers-identify-themselves`

These references document provider-observed Meta behavior; current Meta/provider policy remains authoritative at execution time.
