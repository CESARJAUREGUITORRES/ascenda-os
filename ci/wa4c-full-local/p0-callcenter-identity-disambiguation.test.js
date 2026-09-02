const fs=require('node:fs');
const assert=require('node:assert/strict');

const migration=fs.readFileSync('supabase/migrations/20260902192500_p0_callcenter_identity_disambiguation_v1.sql','utf8');
const rollback=fs.readFileSync('supabase/rollbacks/20260902192500_p0_callcenter_identity_disambiguation_v1_recovery.sql','utf8');

function has(re,msg){assert.match(migration,re,msg);}
function lacks(re,msg){assert.doesNotMatch(migration,re,msg);}

// Additive identity boundary.
has(/aos_callcenter_manual_agenda_identity_v1\s*\(/i,'explicit manual identity resolver missing');
has(/MATCH_SELECTED/,'unique selected identity status missing');
has(/v_matches\s*<>\s*1/i,'resolver must fail closed unless exactly one patient matches');
has(/INSUFFICIENT_EXPLICIT_IDENTITY/,'missing insufficient-identity failure');
has(/EXPLICIT_IDENTITY_STILL_AMBIGUOUS/,'missing still-ambiguous failure');
has(/NO_EXACT_SELECTED_MATCH/,'missing no-exact-match failure');
has(/Nombres/i,'first-name exact boundary missing');
has(/Apellidos/i,'last-name exact boundary missing');
has(/N° documento/i,'document exact boundary missing');
has(/Email/i,'email exact boundary missing');

// Exception is deliberately narrow: MANUAL + AGENDA_ONLY only.
has(/v_action='AGENDA_ONLY'\s+and\s+v_source='MANUAL'/i,'selected identity route must be manual agenda-only');
has(/return public\.aos_callcenter_commit_manual_agenda_selected_v1/i,'agenda-only selected route missing');
has(/return public\.aos_callcenter_commit_action_core_v1/i,'existing governed core fallback missing');
assert.equal((migration.match(/aos_callcenter_commit_manual_agenda_selected_v1\s*\(/gi)||[]).length>=2,true,'selected core not defined/routed');

// No commercial credit, no call, no lead attribution on this exception.
has(/beneficiary_scope[^;]*CLINIC/is,'clinic beneficiary boundary missing');
has(/ALLOW_NO_COMMERCIAL_CREDIT/,'no-commercial-credit status missing');
has(/AGENDA_ONLY_SELECTED_IDENTITY/,'selected agenda-only reason missing');
has(/'callId',null/,'selected route must not create a call');
has(/'leadId',null/,'selected route must not assign a lead');
has(/lead_id_origen,llamada_id_origen[\s\S]*null,null/i,'agenda-only insert must keep call/lead links null');

// Person-specific active appointment protection must be preserved.
has(/aos_callcenter_selected_active_appointment_v1\s*\(/i,'selected-patient active appointment guard missing');
has(/ACTIVE_APPOINTMENT_EXISTS/,'active appointment fail-closed missing');

// Existing identity/commercial policy remains authoritative outside this exception.
lacks(/create\s+or\s+replace\s+function\s+public\.aos_callcenter_credit_context_v2/i,'must not rewrite credit context');
lacks(/create\s+or\s+replace\s+function\s+public\.aos_callcenter_resolve_identity_fast_v3/i,'must not rewrite fast identity resolver');
lacks(/create\s+or\s+replace\s+function\s+public\.aos_rev_resolve_patient_identity_v2/i,'must not rewrite canonical identity resolver');
lacks(/statement_timeout/i,'must not increase or change statement timeout');

// Prepare may defer only IDENTITY_CONFLICT to AGENDA_ONLY; marker remains present.
has(/v_state->>'error'='IDENTITY_CONFLICT'/i,'prepare conflict branch missing');
has(/identityConflictDeferred/i,'deferred conflict marker missing');
has(/allowedActions','\["AGENDA_ONLY"\]'/i,'conflict prepare must expose only agenda-only');

// Rollback must restore the pre-P0 public routing and remove every additive helper.
assert.match(rollback,/create\s+or\s+replace\s+function\s+public\.aos_callcenter_prepare_action_v1/i,'prepare rollback missing');
assert.match(rollback,/return public\.aos_callcenter_commit_action_core_v1/i,'commit rollback must restore governed core route');
assert.doesNotMatch(rollback,/identityConflictDeferred/i,'rollback must remove conflict deferral');
assert.match(rollback,/drop function if exists public\.aos_callcenter_commit_manual_agenda_selected_v1/i,'selected core drop missing');
assert.match(rollback,/drop function if exists public\.aos_callcenter_selected_active_appointment_v1/i,'active guard drop missing');
assert.match(rollback,/drop function if exists public\.aos_callcenter_manual_agenda_identity_v1/i,'identity helper drop missing');

console.log('P0 Call Center identity disambiguation contracts PASS');
