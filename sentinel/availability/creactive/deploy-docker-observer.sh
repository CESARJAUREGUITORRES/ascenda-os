#!/usr/bin/env bash
set -euo pipefail

BASE="${SENTINEL_INSTALL_BASE:-$HOME/.local/share/ascenda-sentinel/availability}"
RUNTIME_DIR="$BASE/runtime"
STATE_DIR="$BASE/state"
KUMA_NAME="sentinel-uptime-kuma"
OBSERVER_NAME="sentinel-local-observer"
KUMA_IMAGE="louislam/uptime-kuma:2"
OBSERVER_IMAGE="python:3.14-alpine"
KUMA_VOLUME="uptime-kuma-data"
TARGET="${SENTINEL_HEALTH_URL:-https://ascenda-os-production.up.railway.app/health}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVAIL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$RUNTIME_DIR" "$STATE_DIR"
install -m 700 "$AVAIL_DIR/local-observer-agent.py" "$RUNTIME_DIR/local-observer-agent.py"
install -m 600 "$AVAIL_DIR/compose.yaml" "$RUNTIME_DIR/compose.yaml"
chmod 700 "$STATE_DIR"

docker version >/dev/null

docker volume create "$KUMA_VOLUME" >/dev/null

ensure_kuma(){
  if docker inspect "$KUMA_NAME" >/dev/null 2>&1; then
    docker start "$KUMA_NAME" >/dev/null 2>&1 || true
  else
    docker run -d \
      --name "$KUMA_NAME" \
      --restart unless-stopped \
      --security-opt no-new-privileges:true \
      --cap-drop ALL \
      -p 127.0.0.1:3001:3001 \
      -v "$KUMA_VOLUME:/app/data" \
      "$KUMA_IMAGE" >/dev/null
  fi
}

ensure_observer(){
  docker rm -f "$OBSERVER_NAME" >/dev/null 2>&1 || true
  docker run -d \
    --name "$OBSERVER_NAME" \
    --restart unless-stopped \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,size=16m \
    -e SENTINEL_LOCAL_STATE_DIR=/var/lib/ascenda-sentinel \
    -e SENTINEL_HEALTH_URL="$TARGET" \
    -e SENTINEL_LOCAL_INTERVAL_SECONDS=60 \
    -e SENTINEL_GAP_THRESHOLD_SECONDS=120 \
    -v "$RUNTIME_DIR/local-observer-agent.py:/opt/sentinel/local-observer-agent.py:ro" \
    -v "$STATE_DIR:/var/lib/ascenda-sentinel" \
    "$OBSERVER_IMAGE" python3 /opt/sentinel/local-observer-agent.py >/dev/null
}

ensure_kuma
ensure_observer

ok=0
for i in $(seq 1 45); do
  if curl -fsS --max-time 3 http://127.0.0.1:3001/ >/dev/null 2>&1 && [ -s "$STATE_DIR/resume-report.json" ]; then
    ok=1; break
  fi
  sleep 2
done

if [ "$ok" != 1 ]; then
  echo 'SENTINEL_CREACTIVE_DOCKER_OBSERVER_VERIFY_FAILED' >&2
  docker logs --tail 50 "$KUMA_NAME" || true
  docker logs --tail 50 "$OBSERVER_NAME" || true
  exit 31
fi

test "$(docker inspect -f '{{.State.Running}}' "$KUMA_NAME")" = "true"
test "$(docker inspect -f '{{.State.Running}}' "$OBSERVER_NAME")" = "true"

python3 - <<PY
import json, pathlib
p=pathlib.Path(${STATE_DIR@Q})/'resume-report.json'
d=json.loads(p.read_text())
assert d['observer']=='CREACTIVE'
assert d['local_observer_state']=='ONLINE'
assert d['retroactive_claims_forbidden'] is True
assert d['current_health'] in ('HEALTHY','DEGRADED')
print(json.dumps({'observer':d['observer'],'current_health':d['current_health'],'coverage_gap_semantics':d['coverage_gap_semantics']}))
PY

echo 'SENTINEL_CREACTIVE_DOCKER_OBSERVER=PASS'
echo 'KUMA_UI=http://127.0.0.1:3001'
