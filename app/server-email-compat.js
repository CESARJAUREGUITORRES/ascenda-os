'use strict'

// F16/F4 compatibility bridge for the legacy backend-only Cartero scheduler.
// F4 deliberately strips SUPABASE_SERVICE_ROLE_KEY from its legacy child, while
// server.js still requires a backend credential for Email dedup/audit tables.
// Alias the same Railway secret under the legacy compatibility name already
// supported by server.js/email-gateway without exposing any secret to browser code.
if (!process.env.service_role && process.env.SUPABASE_SERVICE_ROLE_KEY) {
  process.env.service_role = process.env.SUPABASE_SERVICE_ROLE_KEY
}

require('./server-f17')
