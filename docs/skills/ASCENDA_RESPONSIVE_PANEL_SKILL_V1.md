# ASCENDA RESPONSIVE PANEL SKILL V1

Use this skill whenever a panel in ASCENDA CLINIC must work on phone/tablet without breaking its desktop or business behavior.

## Input
- logical view ID from `VIEW_MAP`;
- resolved file from `PANEL_ROUTES`;
- current `main` SHA;
- current compact classifier from `clinic-shell-ui-v1.js`.

## Procedure

### 1. Inventory
Capture root container, desktop grids/flex layout, fixed/min widths, tables, charts, actions, modals/overlays/drawers, tabs/filters, existing media rules and any rule that hides content.

### 2. Freeze functional authority
Record IDs, inline handlers, named JS functions, external scripts, route and role gates. Do not rename/remove them. Prefer a new external CSS adapter.

### 3. Select mobile transformation
- multi-column KPI/grid → 2×N or 1×N;
- wide operational grid → stack preserving order;
- wide table → internal horizontal scroll;
- side drawer → bottom sheet portrait / side sheet landscape;
- centered modal → bottom sheet/full-width compact modal;
- 3-pane communication UI → horizontal pane track or compact master-detail;
- 7-day calendar → preserve 7 days; contain/scroll if needed;
- chart → container-fit; preserve dataset;
- long tabs → horizontal tab scroll;
- dense form → 1 column portrait, 2 where safe landscape.

### 4. Scope
Every layout-changing selector must start with `.clinic-compact-ui`. Panel-specific selectors should additionally use `.workspace[data-active-view="<view>"]`.

### 5. Touch landscape
Use `.clinic-landscape`; do not use width alone. A landscape phone stays compact.

### 6. Preservation rules
Never solve fit by deleting operational content. Prefer reflow, scroll or sheets.

### 7. Contract
Assert registry coverage, route presence, business handler presence, mobile asset wiring, compact scoping, table overflow, drawer/modal treatment and no functional panel diff unless declared.

### 8. Regression
At minimum run syntax, responsive registry contract, CLINIC UI contract, APP-PWA V2, relevant domain contract and `git diff` for protected functional files.

### 9. Deploy
Scoped branch → PR → exact tested head → merge → Railway exact SHA → runtime healthy.

### 10. Canary
Verify portrait, landscape touch, drawer expanded/collapsed, primary action, detail/modal, scroll/table and desktop original composition.

## Output record
Store view_id, route, family, adapter, baseline_status, human_canary, protected business file and gate/run evidence.