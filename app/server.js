const http = require('http')
const fs   = require('fs')
const path = require('path')
const PORT = parseInt(process.env.PORT || '4173', 10)
const PUB  = path.join(__dirname, 'public')
const MIME = {
  '.html':'text/html; charset=utf-8','.js':'application/javascript',
  '.css':'text/css','.svg':'image/svg+xml','.png':'image/png','.ico':'image/x-icon'
}
function serve(f,res){
  const mime=MIME[path.extname(f)]||'text/plain'
  fs.readFile(f,(err,d)=>{
    if(err){res.writeHead(404);res.end('Not found');return}
    res.writeHead(200,{'Content-Type':mime})
    res.end(d)
  })
}
http.createServer((req,res)=>{
  const p=req.url.split('?')[0]
  if(p==='/'||p==='/login'){serve(path.join(PUB,'login.html'),res);return}
  if(p==='/app'){serve(path.join(PUB,'app.html'),res);return}
  const f=path.join(PUB,p.slice(1))
  if(fs.existsSync(f)&&!fs.statSync(f).isDirectory()){serve(f,res);return}
  serve(path.join(PUB,'login.html'),res)
}).listen(PORT,'0.0.0.0',()=>{
  console.log('AscendaOS http://0.0.0.0:'+PORT)
  console.log('Rutas: / login | /app AppShell | /PANEL.html directo')
})
