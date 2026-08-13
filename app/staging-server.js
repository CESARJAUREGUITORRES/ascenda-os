const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.PORT || '4173', 10);
const PUB = path.join(__dirname, 'public');
const MIME = {
  '.html':'text/html; charset=utf-8', '.js':'application/javascript; charset=utf-8',
  '.css':'text/css; charset=utf-8', '.json':'application/json; charset=utf-8',
  '.svg':'image/svg+xml', '.png':'image/png', '.jpg':'image/jpeg', '.jpeg':'image/jpeg',
  '.webp':'image/webp', '.ico':'image/x-icon', '.woff':'font/woff', '.woff2':'font/woff2'
};

function safePath(urlPath){
  const clean = decodeURIComponent((urlPath || '/').split('?')[0]);
  const rel = clean === '/' ? 'admin-sales-intelligence-staging.html' : clean.replace(/^\/+/, '');
  const full = path.normalize(path.join(PUB, rel));
  if (!full.startsWith(PUB + path.sep) && full !== PUB) return null;
  return full;
}

http.createServer((req, res) => {
  if (req.url.split('?')[0] === '/health') {
    res.writeHead(200, {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});
    res.end(JSON.stringify({status:'ok', mode:'staging-fixture'}));
    return;
  }
  if (!['GET','HEAD'].includes(req.method)) {
    res.writeHead(405, {'Allow':'GET, HEAD'}); res.end('Method not allowed'); return;
  }
  const file = safePath(req.url);
  if (!file) { res.writeHead(400); res.end('Bad path'); return; }
  fs.stat(file, (err, stat) => {
    if (err || !stat.isFile()) { res.writeHead(404); res.end('Not found'); return; }
    const headers = {
      'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream',
      'Content-Length': stat.size,
      'Cache-Control':'no-cache, no-store, must-revalidate',
      'X-ASCENDA-ENV':'staging-fixture',
      'X-Content-Type-Options':'nosniff'
    };
    res.writeHead(200, headers);
    if (req.method === 'HEAD') { res.end(); return; }
    fs.createReadStream(file).pipe(res);
  });
}).listen(PORT, '0.0.0.0', () => {
  console.log(`[ASCENDA staging fixture] static-only server on ${PORT}`);
});
