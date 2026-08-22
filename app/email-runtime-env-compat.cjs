'use strict'

// Backend-only compatibility for the legacy Cartero transactional Email worker.
// F4 strips SUPABASE_SERVICE_ROLE_KEY before spawning its legacy child, while
// server.js/email-gateway already support `service_role` as the Railway alias.
// Copy only inside the server process environment; no secret value is logged,
// committed, serialized, or exposed to browser code.
if (!process.env.service_role && process.env.SUPABASE_SERVICE_ROLE_KEY) {
  process.env.service_role = process.env.SUPABASE_SERVICE_ROLE_KEY
}
