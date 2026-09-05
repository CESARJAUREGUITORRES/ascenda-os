from pathlib import Path
p=Path('app/server-wa4.js')
s=p.read_text()
for line in [
    "const WA_ACCESS_TOKEN=process.env.WHATSAPP_ACCESS_TOKEN||'';\n",
    "const WA_PHONE_NUMBER_ID=process.env.WHATSAPP_PHONE_NUMBER_ID||'';\n",
    "const WA_GRAPH_VERSION=process.env.WHATSAPP_GRAPH_VERSION||'';\n",
]:
    s=s.replace(line,'')
if 'WHATSAPP_ACCESS_TOKEN' in s or 'WHATSAPP_PHONE_NUMBER_ID' in s or 'WHATSAPP_GRAPH_VERSION' in s:
    raise SystemExit('WA4_PROVIDER_SECRET_BOUNDARY_STILL_PRESENT')
p.write_text(s)
