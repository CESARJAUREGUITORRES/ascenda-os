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

function serveFile(filePath, res) {
  const ext  = path.extname(filePath)
  const mime = MIME[ext] || 'text/plain'
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return }
    res.writeHead(200, { 'Content-Type': mime })
    res.end(data)
  })
}

http.createServer((req, res) => {
  const urlPath = req.url.split('?')[0]

  // Rutas de la app (AppShell) -> servir app.html desde public/
  if (urlPath === '/app' || urlPath.startsWith('/asesor') || urlPath.startsWith('/admin')) {
    const appHtml = path.join(PUB, 'app.html')
    if (fs.existsSync(appHtml)) { serveFile(appHtml, res); return }
  }

  // Assets de Vite (CSS, JS, fonts)
  if (urlPath.startsWith('/assets/')) {
    const assetFile = path.join(DIST, urlPath)
    if (fs.existsSync(assetFile)) { serveFile(assetFile, res); return }
  }

  // Public files
  const pubFile = path.join(PUB, urlPath === '/' ? '' : urlPath)
  if (fs.existsSync(pubFile) && !fs.statSync(pubFile).isDirectory()) {
    serveFile(pubFile, res); return
  }

  // SPA fallback -> index.html de Vite (login)
  const indexFile = path.join(DIST, 'index.html')
  if (fs.existsSync(indexFile)) { serveFile(indexFile, res); return }

  res.writeHead(404); res.end('Not found')
}).listen(PORT, '0.0.0.0', () => {
  console.log('AscendaOS en http://0.0.0.0:' + PORT)
})
