#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${ASCENDA_REPO_URL:-https://github.com/CESARJAUREGUITORRES/ascenda-os}"
RUNNER_NAME="${ASCENDA_RUNNER_NAME:-ASCENDA-ZERO-COST-V2}"
RUNNER_LABEL="${ASCENDA_RUNNER_LABEL:-ascenda-zero-cost-v2}"
RUNNER_DIR="${ASCENDA_RUNNER_DIR:-$HOME/actions-runner}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: este bootstrap debe ejecutarse en Linux/WSL2." >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  echo "ERROR: no ejecutar config.sh como root. Usa el usuario dedicado ascenda-runner." >&2
  exit 1
fi

for cmd in curl tar jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: falta $cmd. Instálalo antes de continuar." >&2
    exit 1
  }
done

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [[ ! -x ./config.sh ]]; then
  TAG="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name')"
  VERSION="${TAG#v}"
  ARCHIVE="actions-runner-linux-x64-${VERSION}.tar.gz"
  URL="https://github.com/actions/runner/releases/download/${TAG}/${ARCHIVE}"
  echo "Descargando GitHub Actions Runner ${TAG}..."
  curl -fL "$URL" -o "$ARCHIVE"
  tar xzf "$ARCHIVE"
  rm -f "$ARCHIVE"
fi

printf 'Pega aquí el registration token TEMPORAL generado por GitHub (no se mostrará): '
IFS= read -r -s RUNNER_TOKEN
printf '\n'

if [[ -z "$RUNNER_TOKEN" ]]; then
  echo "ERROR: token vacío." >&2
  exit 1
fi

./config.sh \
  --unattended \
  --replace \
  --url "$REPO_URL" \
  --token "$RUNNER_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABEL" \
  --work "_work"

unset RUNNER_TOKEN

echo
cat <<EOF
Runner configurado.

Siguiente paso, desde $RUNNER_DIR:
  sudo ./svc.sh install $(id -un)
  sudo ./svc.sh start
  sudo ./svc.sh status

En GitHub debe aparecer con labels:
  self-hosted, Linux, X64, $RUNNER_LABEL
EOF
