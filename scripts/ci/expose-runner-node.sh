#!/usr/bin/env bash
set -euo pipefail

# Zero-Cost CI V2: expose the GitHub runner-bundled Node runtime to shell steps.
# GitHub JavaScript actions can run even when `node` is not exported on PATH.
# This script reuses the trusted local runner runtime; it does not install packages,
# download a toolchain, expose secrets, or switch to a hosted runner.

if command -v node >/dev/null 2>&1; then
  echo "ASCENDA_RUNNER_NODE=ALREADY_AVAILABLE"
  node --version
  exit 0
fi

: "${RUNNER_TEMP:?RUNNER_TEMP is required on the GitHub self-hosted runner}"
: "${GITHUB_PATH:?GITHUB_PATH is required on GitHub Actions}"

runner_root="$(dirname "$(dirname "$RUNNER_TEMP")")"
externals_dir="$runner_root/externals"

if [ ! -d "$externals_dir" ]; then
  echo "ASCENDA_RUNNER_NODE=FAIL externals directory missing" >&2
  exit 1
fi

node_bin="$(find "$externals_dir" -mindepth 3 -maxdepth 3 -type f -path '*/bin/node' -print | sort -V | tail -n 1)"
if [ -z "$node_bin" ] || [ ! -f "$node_bin" ]; then
  echo "ASCENDA_RUNNER_NODE=FAIL bundled Node binary not found" >&2
  exit 1
fi

node_dir="$(dirname "$node_bin")"
printf '%s\n' "$node_dir" >> "$GITHUB_PATH"

# Validate the exact binary now; GITHUB_PATH takes effect on subsequent steps.
"$node_bin" --version
echo "ASCENDA_RUNNER_NODE=PROVISIONED_LOCAL"
