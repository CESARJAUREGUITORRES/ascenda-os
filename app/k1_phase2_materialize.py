from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parent
def read(p): return (ROOT/p).read_text(encoding="utf-8")
server=read("server.js")
if re.search(r"const\s+VERIFY_TOKEN\s*=\s*[\'\"][^\'\"]+",server): raise SystemExit("K1: hardcoded VERIFY_TOKEN")
if re.search(r"process\.env\.RESEND_API_KEY\s*\|\|\s*[\'\"][^\'\"]+",server): raise SystemExit("K1: hardcoded Resend fallback")
k1=read("server-k1.js")
if "server-f5.js" not in k1 or "spawn(process.execPath,[\'server-f4.js\']" in k1: raise SystemExit("K1: stale runtime topology")
if "aos_si_token" in read("public/k1-browser-security.js"): raise SystemExit("K1: alternate browser authority")
targets=["server-k1.js","server-f5.js","server-wa4.js","server-wa3.js","server-wa2.js","server-f4.js","server-phase2.js","server.js","public/app.html","public/cerebro.html","public/admin-team.html","public/k1-browser-security.js","public/login.html","public/phase2-auth-shim.js","public/phase2-security-shim.js","public/phase2-service-worker.js"]
manifest={"contract":"kronia-k1-current-runtime-v3","chain":"K1->F5->WA4->WA3->WA2->F4->Phase2/core","files":{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in targets}}
(ROOT/"k1-phase2-runtime-manifest.json").write_text(json.dumps(manifest,sort_keys=True,indent=2)+"\n")
print("KRONIA_K1_CURRENT_RUNTIME=PASS")
