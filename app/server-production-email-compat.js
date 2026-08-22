'use strict'

// Production-chain compatibility bridge for the backend-only Cartero scheduler.
// The F4 boundary strips SUPABASE_SERVICE_ROLE_KEY before spawning the legacy
// child, while the legacy Email runtime still reads the supported `service_role`
// alias for private dedup/audit tables. Keep the same Railway secret server-side;
// no secret value is exposed to browser code or committed to source.
if (!process.env.service_role && process.env.SUPABASE_SERVICE_ROLE_KEY) {
  process.env.service_role = process.env.SUPABASE_SERVICE_ROLE_KEY
}

require('./server-phase-s-f17')
