#!/usr/bin/env bash
set -euo pipefail

RUNTIME_DIR="${SENTINEL_RUNTIME_DIR:-$HOME/.local/share/ascenda-sentinel/availability/runtime}"
STATE_DIR="${SENTINEL_LOCAL_STATE_DIR:-$HOME/.local/share/ascenda-sentinel/availability/state}"
KUMA_NAME="sentinel-uptime-kuma"
KUMA_IMAGE="louislam/uptime-kuma:2"
KUMA_VOLUME="uptime-kuma-data"
KUMA_PORT="127.0.0.1:3001:3001"
WAIT_SECONDS="${SENTINEL_DOCKER_WAIT_SECONDS:-180}"

mkdir -p "$RUNTIME_DIR" "$STATE_DIR"

wait_for_docker() {
  local waited=0
  until docker info >/dev/null 2>&1; do
    if [ "$waited" -ge "$WAIT_SECONDS" ]; then
      echo "SENTINEL_LOCAL_OBSERVER_DOCKER_UNAVAILABLE waited=${waited}s" >&2
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
}

ensure_kuma() {
  docker volume create "$KUMA_VOLUME" >/dev/null
  if docker inspect "$KUMA_NAME" >/dev/null 2>&1; then
    if [ "$(docker inspect -f '{{.State.Running}}' "$KUMA_NAME")" != "true" ]; then
      docker start "$KUMA_NAME" >/dev/null
    fi
  else
    docker run -d \
      --name "$KUMA_NAME" \
      --restart unless-stopped \
      --security-opt no-new-privileges:true \
      -p "$KUMA_PORT" \
      -v "$KUMA_VOLUME:/app/data" \
      "$KUMA_IMAGE" >/dev/null
  fi
}

if ! command -v docker >/dev/null 2>&1; then
  echo 'SENTINEL_LOCAL_OBSERVER_DOCKER_COMMAND_MISSING' >&2
  exit 20
fi
if ! command -v node >/dev/null 2>&1; then
  echo 'SENTINEL_LOCAL_OBSERVER_NODE_MISSING' >&2
  exit 21
fi

wait_for_docker
ensure_kuma

export SENTINEL_LOCAL_STATE_DIR="$STATE_DIR"
export SENTINEL_HEALTH_URL="${SENTINEL_HEALTH_URL:-https://ascenda-os-production.up.railway.app/health}"
export SENTINEL_LOCAL_INTERVAL_MS="${SENTINEL_LOCAL_INTERVAL_MS:-60000}"
export SENTINEL_GAP_THRESHOLD_SECONDS="${SENTINEL_GAP_THRESHOLD_SECONDS:-120}"

AGENT="$RUNTIME_DIR/local-observer-agent.cjs"
if [ ! -f "$AGENT" ]; then
  echo "SENTINEL_LOCAL_OBSERVER_AGENT_MISSING:$AGENT" >&2
  exit 22
fi

# Foreground process intentionally keeps the WSL observer session alive while Windows is on.
exec node "$AGENT"
