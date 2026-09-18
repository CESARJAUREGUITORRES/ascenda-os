# CIA Distribution Planner V1

Date: 2026-09-17 (America/Lima)
Status: STACKED / SAFE-OFF
Base: Audience Workspace V3 (PR #612)
Bulk execution: DISABLED
Human one-contact test: NOT EXECUTED

## Purpose

Build the next layer after the catalog without enabling mass Call Center routing.

The product flow is:

Audience -> Distribution Plan -> Activation -> Assignment/Hopper -> Advisor Work -> Outcome.

V1 in this branch implements only the **planning** portion for multi-advisor distribution.

## What is implemented

- release-state control for CALL / EMAIL / WHATSAPP;
- CALL starts at `HUMAN_CANARY_REQUIRED`, execution disabled, max 1 contact / 1 advisor;
- additive app gateway V4;
- governed distribution preview:
  - validates audience DSL with the canonical registry;
  - counts candidates with resolver V2;
  - validates advisors are active and have `advisor-calls`;
  - projects EQUAL / PERCENTAGE / FIXED quotas;
  - creates no activation, plan or assignment;
- UI planner in Distribución:
  - audience source;
  - quantity;
  - strategy;
  - advisor selection;
  - read-only simulation;
  - projected quantities per advisor;
  - mass activation visibly disabled;
- existing reversible one-contact test remains unchanged.

## Why execution is intentionally absent

The release sequence still requires:

1. deploy Audience Workspace V3;
2. human visual review;
3. validate representative audience counts/previews/CSV;
4. one audience -> one advisor -> one assignment;
5. advisor claims exact assignment;
6. outcome/readback;
7. rollback to baseline;
8. only then raise CALL release state to SINGLE_ADVISOR / LIMITED_ROLLOUT.

No `START_DISTRIBUTION` action exists in this phase. This is a deliberate fail-closed boundary, not missing wiring.
