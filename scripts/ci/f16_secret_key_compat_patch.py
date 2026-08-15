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

pairs = [
    (
        "headers: { 'apikey': dbKey, 'Authorization': 'Bearer ' + dbKey, 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(data) }",
        "headers: f16SupabaseHeaders(dbKey, { 'Content-Type': 'application/json', 'Prefer': 'return=minimal', 'Content-Length': Buffer.byteLength(data) })",
        'server POST headers',
    ),
    (
        "headers: { 'apikey': dbKey, 'Authorization': 'Bearer ' + dbKey }",
        "headers: f16SupabaseHeaders(dbKey)",
        'server GET headers',
    ),
    (
        "headers: { 'apikey': dbKey, 'Authorization': 'Bearer ' + dbKey, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), 'Prefer': 'return=minimal' }",
        "headers: f16SupabaseHeaders(dbKey, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), 'Prefer': 'return=minimal' })",
        'server PATCH headers',
    ),
]
for old, new, label in pairs:
    if s.count(old) != 1:
        raise SystemExit(f'{label} anchor count={s.count(old)}')
    s = s.replace(old, new, 1)
p.write_text(s)

print('F16_SECRET_KEY_COMPAT_PATCH=PASS')
