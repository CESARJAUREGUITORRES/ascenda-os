#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVAIL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST_BASE="${SENTINEL_INSTALL_BASE:-$HOME/.local/share/ascenda-sentinel/availability}"
RUNTIME_DIR="$DEST_BASE/runtime"
STATE_DIR="$DEST_BASE/state"

mkdir -p "$RUNTIME_DIR" "$STATE_DIR"
install -m 700 "$AVAIL_DIR/local-observer-agent.py" "$RUNTIME_DIR/local-observer-agent.py"
install -m 700 "$SCRIPT_DIR/start-observer.sh" "$RUNTIME_DIR/start-observer.sh"
install -m 600 "$AVAIL_DIR/compose.yaml" "$RUNTIME_DIR/compose.yaml"

cat > "$DEST_BASE/INSTALLATION.json" <<EOF
{
  "schema_version": "sentinel-local-observer-install/v1",
  "host": "CREACTIVE",
  "runtime_dir": "$RUNTIME_DIR",
  "state_dir": "$STATE_DIR",
  "target": "https://ascenda-os-production.up.railway.app/health",
  "admin_ui": "http://127.0.0.1:3001",
  "agent_runtime": "python3-stdlib",
  "contains_secrets": false
}
EOF
chmod 600 "$DEST_BASE/INSTALLATION.json"

echo "SENTINEL_LOCAL_OBSERVER_INSTALLED=$DEST_BASE"
echo "NEXT_WINDOWS_AUTOSTART=Run Install-SentinelCreactiveTask.ps1 from Windows PowerShell"
