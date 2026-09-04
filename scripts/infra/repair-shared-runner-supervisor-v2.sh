#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo 'ERROR: ejecutar con sudo bash <repair-script>' >&2
  exit 2
fi

SUPERVISOR='/usr/local/libexec/ascenda-shared-runner-supervisor-v1'
STATE_DIR='/var/tmp/ascenda-shared-runner-v1'
ASC_USER='ascenda-runner'
ROO_USER='cesar'
ASC_DIR='/home/ascenda-runner/actions-runner/actions-runner'
ROO_DIR='/home/cesar/actions-runner'
ASC_LOG='/home/ascenda-runner/shared-runner-supervisor-v1.log'
ROO_LOG='/home/cesar/shared-runner-supervisor-v1.log'

if pgrep -u "$ASC_USER" -f 'Runner.Worker' >/dev/null 2>&1 || pgrep -u "$ROO_USER" -f 'Runner.Worker' >/dev/null 2>&1; then
  echo 'ERROR: hay un Runner.Worker activo; no se hizo ningun cambio.' >&2
  exit 4
fi

test -f "$SUPERVISOR"
cp -a "$SUPERVISOR" "${SUPERVISOR}.pre-v2.$(date +%s)"

python3 - "$SUPERVISOR" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='''stop_listener() {\n  local pid="$1"\n  /bin/kill -TERM "$pid" 2>/dev/null || true\n'''
new='''stop_listener() {\n  local pid="$1"\n  # run.sh is a wrapper; its child Runner.Listener may survive if only the\n  # wrapper PID is terminated. Stop the real listener for this runner user\n  # before yielding the global lock.\n  /usr/bin/pkill -TERM -u "$(id -u)" -f 'Runner.Listener run' 2>/dev/null || true\n  /bin/kill -TERM "$pid" 2>/dev/null || true\n'''
if old not in s and new not in s:
    raise SystemExit('ERROR: stop_listener pattern not found')
if old in s:
    s=s.replace(old,new,1)
old_worker='''if /usr/bin/pgrep -u "$(id -u)" -f "$RUNNER_DIR/bin/Runner.Worker" >/dev/null 2>&1; then'''
new_worker='''if /usr/bin/pgrep -u "$(id -u)" -f 'Runner.Worker' >/dev/null 2>&1; then'''
if old_worker not in s and new_worker not in s:
    raise SystemExit('ERROR: worker detection pattern not found')
if old_worker in s:
    s=s.replace(old_worker,new_worker,1)
p.write_text(s)
PY
chmod 0755 "$SUPERVISOR"

# Stop both coordinators/listeners only after the active-worker guard above.
pkill -TERM -u "$ASC_USER" -f "$SUPERVISOR" 2>/dev/null || true
pkill -TERM -u "$ROO_USER" -f "$SUPERVISOR" 2>/dev/null || true
pkill -TERM -u "$ASC_USER" -f 'Runner.Listener run' 2>/dev/null || true
pkill -TERM -u "$ROO_USER" -f 'Runner.Listener run' 2>/dev/null || true
sleep 3

printf '%s\n' ROO7 > "$STATE_DIR/turn"
printf '%s\n' NONE > "$STATE_DIR/active"

runuser -u "$ASC_USER" -- /usr/bin/nohup "$SUPERVISOR" ASCENDA "$ASC_DIR" ROO7 "$ASC_LOG" >/dev/null 2>&1 &
runuser -u "$ROO_USER" -- /usr/bin/nohup "$SUPERVISOR" ROO7 "$ROO_DIR" ASCENDA "$ROO_LOG" >/dev/null 2>&1 &
sleep 6

listeners=$(pgrep -af 'Runner.Listener run' 2>/dev/null | wc -l || true)
asc_workers=$(pgrep -u "$ASC_USER" -f 'Runner.Worker' 2>/dev/null | wc -l || true)
roo_workers=$(pgrep -u "$ROO_USER" -f 'Runner.Worker' 2>/dev/null | wc -l || true)

echo '=== SHARED RUNNER SUPERVISOR V2 REPAIR ==='
echo "TURN=$(cat "$STATE_DIR/turn" 2>/dev/null || echo missing)"
echo "ACTIVE=$(cat "$STATE_DIR/active" 2>/dev/null || echo missing)"
echo "LISTENERS=${listeners:-0}"
echo "ASC_WORKERS=${asc_workers:-0}"
echo "ROO_WORKERS=${roo_workers:-0}"

if [ "${listeners:-0}" -gt 1 ]; then
  echo 'ERROR: mas de un Runner.Listener despues del V2 repair' >&2
  exit 6
fi
if [ "${asc_workers:-0}" -ne 0 ] || [ "${roo_workers:-0}" -ne 0 ]; then
  echo 'ERROR: aparecio un Worker durante la reparacion' >&2
  exit 7
fi

echo 'SHARED_RUNNER_SUPERVISOR_V2_REPAIR=PASS'
