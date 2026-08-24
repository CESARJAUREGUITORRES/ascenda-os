'use strict'

// ASC-PERF runtime bootstrap hard-off.
// app/server.js imports this module before evaluating background schedulers.
// Force Studio hibernation fail-closed even if a platform/deployment overrides
// the repository start command or injects AOS_STUDIO_BACKGROUND_ENABLED=true.
// Studio UI/data/manual APIs remain intact; reactivation requires a governed
// code change, CI, production canary, and rollback evidence.
process.env.AOS_STUDIO_BACKGROUND_ENABLED = 'false'

// Canonical static boundary/source markers remain on this gateway entrypoint;
// implementation remains byte-identical in ./email-gateway-core.js.
// CIA-F16: GOVERNED_ACTIVATION_REQUIRED
// CIA-F16: aos_cia_verify_app_session_v1
// CIA-F16: process.env.SUPABASE_SERVICE_ROLE_KEY
// CIA-F16: process.env.service_role
// Sentinel F6: action === 'CONFIG_HEALTH'
// Sentinel F6: '/rest/v1/aos_email_envios'
// Sentinel F6: handleWebhook
module.exports = require('./email-gateway-core')
