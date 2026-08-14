#!/usr/bin/env bash
set -euo pipefail

# Zero-Cost CI V2: expose the GitHub runner-bundled Node runtime to shell steps.
# GitHub JavaScript actions can run even when `node` is not exported on PATH.
# This script reuses trusted local runner binaries only: no package install,
# no network download, no secret access, and no hosted-runner fallback.

if command -v node >/dev/null 2>&1; then
  echo "ASCENDA_RUNNER_NODE=ALREADY_AVAILABLE"
  node --version
  exit 0
fi

: "${GITHUB_PATH:?GITHUB_PATH is required on GitHub Actions}"

roots=()
if [[ -n "${RUNNER_TEMP:-}" ]]; then
  roots+=("$(dirname "$(dirname "$RUNNER_TEMP")")")
fi
if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  roots+=("$(dirname "$(dirname "$(dirname "$GITHUB_WORKSPACE")")")")
fi

node_bin=""
for root in "${roots[@]}"; do
  for candidate in \
    "$root"/externals/node*/bin/node \
    "$root"/externals/node*/bin/node.exe \
    "$root"/bin/node; do
    if [[ -x "$candidate" ]]; then
      node_bin="$candidate"
    fi
  done
done

if [[ -z "$node_bin" && -n "${RUNNER_TOOL_CACHE:-}" ]]; then
  for candidate in "$RUNNER_TOOL_CACHE"/node/*/*/bin/node; do
    if [[ -x "$candidate" ]]; then
      node_bin="$candidate"
    fi
  done
fi

if [[ -z "$node_bin" ]]; then
  echo "ASCENDA_RUNNER_NODE=FAIL bundled Node executable not found in trusted runner roots" >&2
  exit 1
fi

node_dir="$(dirname "$node_bin")"
printf '%s\n' "$node_dir" >> "$GITHUB_PATH"

# Validate the exact local binary now. GITHUB_PATH applies to following steps.
"$node_bin" --version
echo "ASCENDA_RUNNER_NODE=PROVISIONED_LOCAL"
