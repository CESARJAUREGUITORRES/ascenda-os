'use strict'

// Backend-only compatibility for Railway/Supabase service-role naming.
// Existing Ascenda runtimes consume both the canonical
// SUPABASE_SERVICE_ROLE_KEY name and the legacy Railway `service_role` alias.
// Normalize only inside the server process environment; never log, serialize,
// commit, or expose either secret value to browser code.
// Preserve an explicitly configured value when both names already exist.
if (!process.env.SUPABASE_SERVICE_ROLE_KEY && process.env.service_role) {
  process.env.SUPABASE_SERVICE_ROLE_KEY = process.env.service_role
}
if (!process.env.service_role && process.env.SUPABASE_SERVICE_ROLE_KEY) {
  process.env.service_role = process.env.SUPABASE_SERVICE_ROLE_KEY
}
