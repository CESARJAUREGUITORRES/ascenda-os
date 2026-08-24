'use strict'

// ASC-PERF runtime bootstrap hard-off.
// app/server.js imports this module before evaluating background schedulers.
// Force Studio hibernation fail-closed even if a platform/deployment overrides
// the repository start command or injects AOS_STUDIO_BACKGROUND_ENABLED=true.
// Studio UI/data/manual APIs remain intact; reactivation requires a governed
// code change, CI, production canary, and rollback evidence.
process.env.AOS_STUDIO_BACKGROUND_ENABLED = 'false'

module.exports = require('./email-gateway-core')
