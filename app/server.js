const http = require('http')
const fs   = require('fs')
const path = require('path')

const PORT = parseInt(process.env.PORT || '4173', 10)
const PUB  = path.join(__dirname, 'public')

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript',
  '.css':  'text/css',
  '.svg':  'image/svg+xml',
  '.ico':  'image/x-icon',
  '.png':  'image/png',
  '.woff2':'font/woff2',
}

function serve(filePath, res) {
  const mime = MIME[path.extname(filePath)] || 'text/plain'
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return }
    res.writeHead(200, { 'Content-Type': mime })
    res.end(data)
  })
}

http.createServer((req, res) => {
  const p = req.url.split('?')[0]

  // Login — raiz
  if (p === '/' || p === '/login') {
    serve(path.join(PUB, 'login.html'), res); return
  }

  // AppShell
  if (p === '/app' || p.startsWith('/asesor') || p.startsWith('/admin')) {
    serve(path.join(PUB, 'app.html'), res); return
  }

  // Paneles
  const panelMap = {
    '/calls':         'calls.html',
    '/advisor-home':  'advisor-home.html',
    '/admin-home':    'admin-home.html',
  }
  if (panelMap[p]) {
    const f = path.join(PUB, panelMap[p])
    if (fs.existsSync(f)) { serve(f, res); return }
  }

  // Cualquier otro archivo en public/
  const f = path.join(PUB, p.slice(1))
  if (fs.existsSync(f) && !fs.statSync(f).isDirectory()) {
    serve(f, res); return
  }

  // 404
  res.writeHead(404); res.end('Not found')

}).listen(PORT, '0.0.0.0', () => {
  console.log('AscendaOS en http://0.0.0.0:' + PORT)
  console.log('/ -> login.html | /app -> AppShell | /calls -> CallCenter')
})
