#!/usr/bin/env bash
set -euo pipefail

# Dedicated ASCENDA runner hygiene. The repo-level runner executes one job at a
# time, so no legitimate concurrent ASCENDA Supabase fixture should be running.
# Remove only Supabase Docker resources whose names contain "ascenda".

mapfile -t containers < <(docker ps -aq --filter 'name=supabase_' | while read -r id; do
  [ -n "$id" ] || continue
  name="$(docker inspect --format '{{.Name}}' "$id" 2>/dev/null | sed 's#^/##')"
  if [[ "$name" == supabase_*ascenda* ]]; then printf '%s\n' "$id"; fi
done)

if ((${#containers[@]})); then
  docker rm -f "${containers[@]}" >/dev/null
fi

mapfile -t networks < <(docker network ls --format '{{.Name}}' | grep -E '^supabase_.*ascenda' || true)
for n in "${networks[@]}"; do docker network rm "$n" >/dev/null 2>&1 || true; done

mapfile -t volumes < <(docker volume ls --format '{{.Name}}' | grep -E '^supabase_.*ascenda' || true)
for v in "${volumes[@]}"; do docker volume rm -f "$v" >/dev/null 2>&1 || true; done

# Prove the common isolated DB ports used by ASCENDA are not held by a surviving
# ASCENDA Supabase container. Do not kill arbitrary host processes.
for port in 54322 55322 56322 57322 58322; do
  if docker ps --format '{{.Ports}} {{.Names}}' | grep -E "0\.0\.0\.0:${port}->" | grep -q 'ascenda'; then
    echo "ASCENDA_ZERO_RESIDUE=FAIL port=$port" >&2
    exit 1
  fi
done

# GitHub's self-hosted runner already ships a Node runtime under `externals` for
# Actions. The service account does not expose it in the interactive shell PATH.
# Reuse that bundled runtime for later CI smoke/static steps instead of installing
# a second Node distribution or using paid hosted infrastructure.
if [[ -n "${GITHUB_PATH:-}" && -n "${RUNNER_WORKSPACE:-}" ]]; then
  runner_root="$(cd "$(dirname "$RUNNER_WORKSPACE")/.." && pwd)"
  node_dir="${runner_root}/externals/node24/bin"
  if [[ -x "${node_dir}/node" ]]; then
    printf '%s\n' "$node_dir" >> "$GITHUB_PATH"
    echo "ASCENDA_RUNNER_NODE=PASS runtime=node24"
  else
    echo "ASCENDA_RUNNER_NODE=FAIL bundled node24 not found" >&2
    exit 1
  fi
fi

echo "ASCENDA_ZERO_RESIDUE=PASS containers=${#containers[@]} networks=${#networks[@]} volumes=${#volumes[@]}"
