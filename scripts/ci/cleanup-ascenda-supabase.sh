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

echo "ASCENDA_ZERO_RESIDUE=PASS containers=${#containers[@]} networks=${#networks[@]} volumes=${#volumes[@]}"
