const http = require('http')
const fs   = require('fs')
const path = require('path')

const PORT = parseInt(process.env.PORT || '4173', 10)
const DIST = path.join(__dirname, 'dist')
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

  // AppShell — todas las rutas de la app
  if (p === '/app' || p.startsWith('/asesor') || p.startsWith('/admin')) {
    const f = path.join(PUB, 'app.html')
    if (fs.existsSync(f)) { serve(f, res); return }
  }

  // Paneles específicos
  const panelMap = {
    '/calls':   'calls.html',
    '/advisor/calls': 'calls.html',
  }
  if (panelMap[p]) {
    const f = path.join(PUB, panelMap[p])
    if (fs.existsSync(f)) { serve(f, res); return }
  }

  // Assets Vite
  if (p.startsWith('/assets/')) {
    const f = path.join(DIST, p)
    if (fs.existsSync(f)) { serve(f, res); return }
  }

  // Archivos de public/
  if (p !== '/') {
    const f = path.join(PUB, p)
    if (fs.existsSync(f) && !fs.statSync(f).isDirectory()) { serve(f, res); return }
  }

  // SPA fallback → login
  const idx = path.join(DIST, 'index.html')
  if (fs.existsSync(idx)) { serve(idx, res); return }

  res.writeHead(404); res.end('Not found')
}).listen(PORT, '0.0.0.0', () => {
  console.log('AscendaOS en http://0.0.0.0:' + PORT)
  console.log('Paneles: /app (AppShell), /calls (CallCenter)')
})
