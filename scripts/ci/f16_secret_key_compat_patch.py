from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    s = p.read_text()
    if s.count(old) != 1:
        raise SystemExit(f'{label} anchor count={s.count(old)}')
    p.write_text(s.replace(old, new, 1))


replace_once(
    'app/email-gateway.js',
    "    var headers = { apikey: serviceKey, Authorization: 'Bearer ' + serviceKey }\n    if (prefer) headers.Prefer = prefer\n",
    "    var headers = { apikey: serviceKey }\n    if (!/^sb_(?:secret|publishable)_/.test(serviceKey)) headers.Authorization = 'Bearer ' + serviceKey\n    if (prefer) headers.Prefer = prefer\n",
    'email-gateway service headers',
)

replace_once(
    'app/f16-live-canary.js',
    """    return requester(sbUrl + path, {
      method: method || 'GET',
      headers: { apikey: serviceKey, Authorization: 'Bearer ' + serviceKey },
      timeout: 15000
    }, body)
""",
    """    var headers = { apikey: serviceKey }
    if (!/^sb_(?:secret|publishable)_/.test(serviceKey)) headers.Authorization = 'Bearer ' + serviceKey
    return requester(sbUrl + path, {
      method: method || 'GET',
      headers: headers,
      timeout: 15000
    }, body)
""",
    'live-canary service headers',
)

p = Path('app/server.js')
s = p.read_text()
anchor = """function f16RequireEmailBackend(endpoint) {
  if (/^\\/rest\\/v1\\/aos_emails?_/.test(String(endpoint || '')) && !EMAIL_SB_KEY) {
    throw new Error('EMAIL_SERVICE_ROLE_NOT_CONFIGURED')
  }
}

"""
helper = anchor + """function f16SupabaseHeaders(dbKey, extra) {
  var headers = { 'apikey': dbKey }
  if (!/^sb_(?:secret|publishable)_/.test(String(dbKey || ''))) headers.Authorization = 'Bearer ' + dbKey
  return Object.assign(headers, extra || {})
}

"""
if s.count(anchor) != 1:
    raise SystemExit(f'server helper anchor count={s.count(anchor)}')
s = s.replace(anchor, helper, 1)

post_old = "headers: { 'apikey': dbKey, 'Authorization': 'Bearer ' + dbKey, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(data) }"
post_new = "headers: f16SupabaseHeaders(dbKey, { 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(data) })"
if s.count(post_old) != 1:
    raise SystemExit(f'server POST headers anchor count={s.count(post_old)}')
s = s.replace(post_old, post_new, 1)

get_old = "headers: { 'apikey': dbKey, 'Authorization': 'Bearer ' + dbKey }"
get_new = "headers: f16SupabaseHeaders(dbKey)"
if s.count(get_old) != 2:
    raise SystemExit(f'server GET headers anchor count={s.count(get_old)}')
s = s.replace(get_old, get_new)

patch_old = "headers: { 'apikey': dbKey, 'Authorization': 'Bearer ' + dbKey, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), 'Prefer': 'return=minimal' }"
patch_new = "headers: f16SupabaseHeaders(dbKey, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), 'Prefer': 'return=minimal' })"
if s.count(patch_old) != 1:
    raise SystemExit(f'server PATCH headers anchor count={s.count(patch_old)}')
s = s.replace(patch_old, patch_new, 1)
p.write_text(s)

print('F16_SECRET_KEY_COMPAT_PATCH=PASS')
