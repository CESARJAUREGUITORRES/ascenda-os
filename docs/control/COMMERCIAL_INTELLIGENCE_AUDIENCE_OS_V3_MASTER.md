# ASCENDA OS — Commercial Intelligence & Audience OS V3

**Role:** architecture mother / stable product contract  
**Live status:** use `docs/control/commercial-intelligence/CIA_MASTER_ALIGNMENT_CURRENT.md` and `ROADMAP_STATUS.md`  
**Production Supabase:** `ituyqwstonmhnfshnaqz`

## Historical full specification

The original full Product Spec V3 / technical Impact Report / implementation map was committed as:

`a8f9233aafd86ca7c4a2d1070d3bb5de7c995da4`

That document remains the architecture mother. Its original status text (`READY FOR PHASE 0`) is historical and must never be used as the live roadmap state.

## Stable architecture contract

CIA V3 transforms operational ASCENDA data into a governed commercial control plane:

`Source Data → Identity Resolution → Commercial Facts → Segmentation → Audience Engine → Context/Eligibility → Activation → Assignment → Advisor Work → Request/Approval → Commercial Intelligence → KronIA → Channel Adapters → Outcomes/Attribution`

### Non-negotiable invariants

1. **One audience truth.** An audience belongs to ASCENDA, not Email, WhatsApp, SMS or Call Center.
2. **Separate concepts.** Audience ≠ eligibility ≠ activation ≠ assignment ≠ work view ≠ request ≠ approval ≠ execution.
3. **Source data remains intact.** New layers resolve/aggregate/version; they do not move operational rows between source tables.
4. **Identity is explicit.** `numero_limpio/contact_key` is a current bridge, not an eternal identity model; conflicts remain explicit.
5. **Deterministic rules decide.** SQL/RPC/policies calculate facts, eligibility and state. AI interprets, explains and proposes.
6. **Human authority remains explicit.** Ownership/resource-sensitive actions require governed authority/approval.
7. **Recommendation is not authority.** Recommendation → proposal → request → human decision → execute are distinct transitions.
8. **UNKNOWN/freshness fail closed.** Missing evidence is not permission.
9. **Version and audit material decisions.** Audiences, policies, snapshots, requests, outcomes and governed channel facts must be reproducible.
10. **No big-bang migration.** Use additive adapters, fallback, canary, rollback and progressive ACL closure.
11. **Commercial scope excludes ordinary use of clinical free text, diagnoses, clinical photos, prescriptions and full medical-history content as commercial features.**
12. **Provider-neutral channels.** Email/WhatsApp/SMS transports are adapters over canonical Audience/Activation; provider choice must not create a second customer/audience truth.

## Stable phase architecture

- F0 Baseline & Contracts
- F1 Identity Resolver
- F2 Commercial Facts
- F3 Segmentation Engine
- F4 Audience Resolver
- F5 Panel Central Skeleton
- F6 Audience Library Persistence
- F7 Snapshots & Activation
- F8 Channel Context & Availability
- F9 Assignment Engine
- F10 Advisor Control Center
- F11 Call Center Integration V3
- F12 Advisor Work Views
- F13 Requests & Approval Engine
- F14 Commercial Intelligence Shadow
- F15 KronIA + Multiagent Orchestration
- F16 Email Integration
- F17 SMS / WhatsApp / Future Channels
- F18 Attribution, Learning & Hardening

## Live-control documents

Before any implementation, read:

1. `AGENTS.md`
2. `docs/control/commercial-intelligence/CIA_AGENT_BOOTSTRAP_CURRENT.md`
3. `docs/control/commercial-intelligence/CIA_MASTER_ALIGNMENT_CURRENT.md`
4. `docs/control/commercial-intelligence/CIA_EXECUTION_PLAYBOOK_V1.md`
5. `docs/control/commercial-intelligence/ROADMAP_STATUS.md`
6. current phase evidence + GitHub CURRENT + production readiness RPCs

If documentation disagrees with live GitHub/Supabase, stop and repair control state before writing code.
