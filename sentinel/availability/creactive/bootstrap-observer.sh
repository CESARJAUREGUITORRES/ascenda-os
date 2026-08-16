#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAN_ONLY=0
START_NOW=1
WSL_DISTRO="${SENTINEL_WSL_DISTRO:-Ubuntu}"

for arg in "$@"; do
  case "$arg" in
    --plan-only) PLAN_ONLY=1; START_NOW=0 ;;
    --no-start) START_NOW=0 ;;
    --help)
      cat <<'EOF'
Usage: bash bootstrap-observer.sh [--plan-only] [--no-start]

Installs Sentinel local observer files into the current WSL user profile and,
unless --plan-only is used, registers a limited Windows logon task through WSL interop.
No secrets are read or written.
EOF
      exit 0
      ;;
    *) echo "UNKNOWN_ARGUMENT:$arg" >&2; exit 2 ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo 'SENTINEL_BOOTSTRAP_PYTHON_MISSING' >&2
  exit 20
fi
if ! command -v docker >/dev/null 2>&1; then
  echo 'SENTINEL_BOOTSTRAP_DOCKER_MISSING' >&2
  exit 21
fi
if ! command -v powershell.exe >/dev/null 2>&1; then
  echo 'SENTINEL_BOOTSTRAP_WSL_INTEROP_MISSING' >&2
  exit 22
fi
if ! command -v wslpath >/dev/null 2>&1; then
  echo 'SENTINEL_BOOTSTRAP_WSLPATH_MISSING' >&2
  exit 23
fi

bash "$SCRIPT_DIR/install-observer.sh"

PS_SCRIPT_WIN="$(wslpath -w "$SCRIPT_DIR/Install-SentinelCreactiveTask.ps1")"
PS_ARGS=(-NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN" -WslDistribution "$WSL_DISTRO")
if [ "$PLAN_ONLY" = 1 ]; then PS_ARGS+=(-PlanOnly); fi
if [ "$START_NOW" = 1 ]; then PS_ARGS+=(-StartNow); fi

powershell.exe "${PS_ARGS[@]}"

if [ "$PLAN_ONLY" = 1 ]; then
  echo 'SENTINEL_CREACTIVE_BOOTSTRAP=PLAN_ONLY_PASS'
  exit 0
fi

STATE_DIR="${SENTINEL_LOCAL_STATE_DIR:-$HOME/.local/share/ascenda-sentinel/availability/state}"
for i in $(seq 1 30); do
  if [ -s "$STATE_DIR/resume-report.json" ]; then
    echo 'SENTINEL_CREACTIVE_BOOTSTRAP=PASS'
    echo "RESUME_REPORT=$STATE_DIR/resume-report.json"
    echo 'KUMA_UI=http://127.0.0.1:3001'
    exit 0
  fi
  sleep 2
done

echo 'SENTINEL_CREACTIVE_BOOTSTRAP=TASK_REGISTERED_WAITING_FOR_REPORT'
echo "RESUME_REPORT=$STATE_DIR/resume-report.json"
exit 0
