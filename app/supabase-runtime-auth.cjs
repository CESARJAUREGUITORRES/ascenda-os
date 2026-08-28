'use strict'

// Supabase API-key compatibility for backend runtimes.
// Legacy JWT keys may be sent as both apikey + Bearer authorization.
// New sb_secret_* / sb_publishable_* keys are API keys, not JWTs, so they
// must not be placed in Authorization: Bearer. Never log the key value.
function buildSupabaseHeaders(key, extra) {
  const k=String(key||'')
  const headers={apikey:k}
  if (k && !/^sb_(?:secret|publishable)_/.test(k)) headers.Authorization='Bearer '+k
  return Object.assign(headers,extra||{})
}

module.exports={buildSupabaseHeaders}
