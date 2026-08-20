from pathlib import Path

sw = Path('app/public/phase2-service-worker.js').read_text(encoding='utf-8')
citas = Path('app/public/citas.html').read_text(encoding='utf-8')

required = [
    "rm[1]==='aos_paciente_360'",
    "aos_patient_history_summary_v1",
    "await getToken()",
    "PATIENT_HISTORY_APP_SESSION_REQUIRED",
    "p_token:t",
    "p_numero:p.p_numero||''",
]
for marker in required:
    if marker not in sw:
        raise SystemExit(f'missing service-worker marker: {marker}')

# The legacy UI call is intentionally preserved for compatibility; the service worker
# is the mandatory cutover layer. There must be exactly one active Citas call.
if citas.count("_rpc('aos_paciente_360'") != 1:
    raise SystemExit('unexpected Citas Patient 360 call count')

block = sw.split("if(rm&&rm[1]==='aos_paciente_360')", 1)[1].split("if(rm&&IDENTITY[rm[1]])", 1)[0]
if 'fetch(req)' in block or 'isMissing' in block:
    raise SystemExit('Patient history cutover must fail closed; legacy fallback detected')

print('REV-F6.0 UI/consumer contract PASS')
