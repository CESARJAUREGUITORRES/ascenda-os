# CLINIC MOBILE PANEL ADAPTATION PLAYBOOK V1

**Status:** canonical  
**Started:** 2026-09-15  
**Purpose:** adapt ASCENDA CLINIC panels to mobile without changing or deleting business functionality.

## Permanent rule

> Responsive adaptation must preserve data, routes, events and business behavior. Reflow, contain, scroll or transform presentation; never remove operational information merely to fit a phone.

## Architecture

ASCENDA CLINIC now separates:

1. **Panel business file** — source of functionality and desktop layout (for example `calls.html`).
2. **Shared compact-device classifier** — `clinic-shell-ui-v1.js` applies `clinic-compact-ui` / `clinic-landscape`.
3. **Panel-specific mobile template** — external CSS loaded by the shell, scoped under `.clinic-compact-ui`.
4. **Regression contract** — asserts existing functions/routes/actions remain present and that the mobile layer preserves every operational section.

Desktop fine-pointer layout remains owned by the original panel unless a separate desktop redesign is explicitly approved.

## Adaptation sequence for every panel

### L0 — Inventory
- Identify all visible sections, KPIs, tables, charts, actions, modals, drawers and data controls.
- Identify the authoritative JS handlers and routes.
- Record legacy mobile rules that hide or clip content.

### L1 — Preserve authority
- Do not rewrite the functional panel if CSS can solve the problem.
- Do not rename IDs/classes used by JavaScript.
- Do not remove `onclick`, listeners, RPCs, fetches or state transitions.
- Prefer an external `clinic-<panel>-mobile-vN.css`.

### L2 — Compact layout
- Widths: `min-width:0`, remaining-flex workspace, no viewport + drawer overflow.
- Grids: stack/reflow at compact width.
- Tables: internal horizontal scroll.
- Charts: fit container; preserve the complete dataset.
- Primary actions: retain all actions, stack when needed.
- Touch controls: minimum practical touch height.
- Modals/detail drawers: convert to bottom sheet/full-height panel when appropriate.

### L3 — Landscape
- A touch phone in landscape remains compact UI.
- Use the extra width to move from one to two columns only when content remains legible.
- Never fall back to desktop merely because CSS pixel width exceeds a desktop breakpoint.

### L4 — Desktop protection
- Desktop mouse/fine-pointer layout must remain unchanged unless explicitly authorized.
- Panel-specific mobile CSS must be rooted in `.clinic-compact-ui`.

### L5 — Gates
Minimum gates:
- panel-specific responsive contract;
- existing APP-PWA contract;
- relevant domain contract(s);
- diff verification proving no unintended business-file changes;
- Railway exact-SHA deployment check;
- human canary on vertical + landscape + desktop.

## Call Center V1.2 reference implementation

The first reference implementation after Home Admin is Call Center:
- source authority: `app/public/calls.html`;
- mobile adapter: `app/public/clinic-callcenter-mobile-v12.css`;
- source business file remains unmodified;
- KPIs: 2×N portrait, 5 columns touch-landscape;
- main three-column desktop grid becomes stacked portrait;
- Call Center + Calendar + Score all remain available;
- lead actions stack on narrow portrait;
- call history scrolls inside its card;
- Ficha 360 becomes bottom sheet portrait / side sheet landscape;
- modal forms become mobile sheets;
- desktop remains owned by legacy `calls.html`.

## Panel rollout queue

After Call Center human canary:
1. Agenda
2. Pacientes
3. Ventas / Sales Intelligence
4. Equipo
5. Caja / Cartera
6. Catálogo / Inventario
7. Marketing / WhatsApp / Email
8. Remaining admin/support panels

Each panel must receive its own inventory + adapter + contract rather than broad unverified CSS.
