#!/usr/bin/env bash
set -euo pipefail

fail=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    fail=1
  fi
}

printf 'ASCENDA_ZERO_COST_CI_V2_HEALTHCHECK\n'
printf 'host=%s arch=%s user=%s\n' "$(uname -s)" "$(uname -m)" "$(id -un)"

[[ "$(uname -s)" == "Linux" ]] || { echo 'FAIL  Linux required'; fail=1; }
[[ "$(uname -m)" == "x86_64" ]] || { echo 'FAIL  X64 required'; fail=1; }
[[ "$(id -u)" -ne 0 ]] || { echo 'FAIL  runner must not run as root'; fail=1; }

check 'git' git --version
check 'curl' curl --version
check 'python3' python3 --version
check 'psql' psql --version
check 'docker-cli' docker version

# GitHub JavaScript actions use the runner-bundled Node runtime even when the
# `node` binary is not exported to shell steps. Reuse that trusted local binary
# and publish its directory through GITHUB_PATH for subsequent Zero-Cost steps.
if command -v node >/dev/null 2>&1; then
  check 'node' node --version
elif [[ -n "${RUNNER_TEMP:-}" && -n "${GITHUB_PATH:-}" ]]; then
  if bash "$(dirname "${BASH_SOURCE[0]}")/expose-runner-node.sh" >/dev/null 2>&1; then
    echo 'PASS  runner-node-bundled'
  else
    echo 'FAIL  runner-node-bundled'
    fail=1
  fi
else
  echo 'FAIL  node unavailable and runner metadata missing'
  fail=1
fi

if command -v docker >/dev/null 2>&1; then
  if docker run --rm hello-world >/dev/null 2>&1; then
    echo 'PASS  docker-container-smoke'
  else
    echo 'FAIL  docker-container-smoke'
    fail=1
  fi
fi

free_kb="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
if [[ "${free_kb:-0}" -ge 10485760 ]]; then
  echo 'PASS  disk-free>=10GB'
else
  echo 'FAIL  disk-free<10GB'
  fail=1
fi

# We never print values. Presence of obvious production-secret names is enough to fail.
for name in SUPABASE_SERVICE_ROLE_KEY SUPABASE_DB_PASSWORD DATABASE_URL RESEND_API_KEY OPENAI_API_KEY; do
  if [[ -n "${!name:-}" ]]; then
    echo "FAIL  unexpected-secret-env:$name"
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo 'ASCENDA_ZERO_COST_CI_V2_HEALTHCHECK=FAIL'
  exit 1
fi

echo 'ASCENDA_ZERO_COST_CI_V2_HEALTHCHECK=PASS'
