const http = require('http')
const fs   = require('fs')
const path = require('path')

const PORT = parseInt(process.env.PORT || '4173', 10)
const DIST = path.join(__dirname, 'dist')

console.log('Sirviendo desde:', DIST)
console.log('Puerto:', PORT)

if (!fs.existsSync(DIST)) {
  console.error('ERROR: carpeta dist/ no existe. El build falló.')
  process.exit(1)
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript',
  '.css':  'text/css',
  '.svg':  'image/svg+xml',
  '.ico':  'image/x-icon',
  '.png':  'image/png',
  '.woff2':'font/woff2',
}

http.createServer((req, res) => {
  const urlPath = req.url.split('?')[0]
  let file = path.join(DIST, urlPath === '/' ? 'index.html' : urlPath)

  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(DIST, 'index.html')
  }

  const ext  = path.extname(file)
  const mime = MIME[ext] || 'application/octet-stream'

  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return }
    res.writeHead(200, { 'Content-Type': mime })
    res.end(data)
  })
}).listen(PORT, '0.0.0.0', () => {
  console.log('AscendaOS corriendo en http://0.0.0.0:' + PORT)
})
