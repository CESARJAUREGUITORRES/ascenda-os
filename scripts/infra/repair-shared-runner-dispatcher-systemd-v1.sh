#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo 'ERROR: ejecutar con sudo bash <repair-script>' >&2
  exit 2
fi

ASC_USER='ascenda-runner'
ROO_USER='cesar'
STATE_DIR='/var/tmp/ascenda-shared-runner-v1'
BASE_INSTALLER='/home/ascenda-runner/shared-runner-dispatcher-v1/install.sh'
SERVICE_STATE="$STATE_DIR/systemd-services.pre-dispatcher-v1"
SERVICE_ROLLBACK='/usr/local/sbin/ascenda-shared-runner-systemd-restore-v1'

if [ -x '/home/ascenda-runner/actions-runner/actions-runner/run.sh' ]; then
  ASC_DIR='/home/ascenda-runner/actions-runner/actions-runner'
elif [ -x '/home/ascenda-runner/actions-runner/run.sh' ]; then
  ASC_DIR='/home/ascenda-runner/actions-runner'
else
  echo 'ERROR: no se encontro run.sh de ASCENDA' >&2
  exit 3
fi
ROO_DIR='/home/cesar/actions-runner'

test -x "$ASC_DIR/run.sh"
test -x "$ROO_DIR/run.sh"
test -x "$BASE_INSTALLER"

# Never mutate runner lifecycle while any GitHub Actions job is executing.
if pgrep -u "$ASC_USER" -f 'Runner.Worker' >/dev/null 2>&1 || pgrep -u "$ROO_USER" -f 'Runner.Worker' >/dev/null 2>&1; then
  echo 'ERROR: hay un Runner.Worker activo. La reparacion no hizo cambios.' >&2
  exit 4
fi

install -d -m 2770 -g docker "$STATE_DIR"

service_name_for_dir() {
  local dir="$1"
  if [ -s "$dir/.service" ]; then
    tr -d '\r\n' < "$dir/.service"
  fi
}

ASC_SERVICE="$(service_name_for_dir "$ASC_DIR")"
ROO_SERVICE="$(service_name_for_dir "$ROO_DIR")"

service_state() {
  local service="$1" field="$2"
  if [ -z "$service" ]; then
    printf '%s' 'absent'
    return 0
  fi
  if [ "$field" = 'active' ]; then
    systemctl is-active "$service" 2>/dev/null || true
  else
    systemctl is-enabled "$service" 2>/dev/null || true
  fi
}

# Preserve the pre-repair service lifecycle exactly once for deterministic rollback.
if [ ! -s "$SERVICE_STATE" ]; then
  {
    printf 'ASC|%s|%s|%s\n' "$ASC_SERVICE" "$(service_state "$ASC_SERVICE" enabled)" "$(service_state "$ASC_SERVICE" active)"
    printf 'ROO7|%s|%s|%s\n' "$ROO_SERVICE" "$(service_state "$ROO_SERVICE" enabled)" "$(service_state "$ROO_SERVICE" active)"
  } > "$SERVICE_STATE"
  chgrp docker "$SERVICE_STATE"
  chmod 0660 "$SERVICE_STATE"
fi

neutralize_service() {
  local side="$1" service="$2"
  if [ -z "$service" ]; then
    echo "$side service: not installed"
    return 0
  fi
  echo "$side service: $service"
  systemctl stop "$service" 2>/dev/null || true
  systemctl disable "$service" 2>/dev/null || true
  systemctl reset-failed "$service" 2>/dev/null || true
  if systemctl is-active --quiet "$service"; then
    echo "ERROR: $side legacy service sigue activo: $service" >&2
    exit 5
  fi
  echo "$side legacy service: inactive"
}

neutralize_service ASCENDA "$ASC_SERVICE"
neutralize_service ROO7 "$ROO_SERVICE"

# Restore helper is intentionally separate from the dispatcher rollback so the
# original runner service state can be restored even if the dispatcher files change.
cat > "$SERVICE_ROLLBACK" <<EOF
#!/usr/bin/env bash
set -euo pipefail
[ "\${EUID}" -eq 0 ] || { echo 'run with sudo' >&2; exit 2; }
STATE_FILE='$SERVICE_STATE'
[ -s "\$STATE_FILE" ] || { echo 'service state missing' >&2; exit 3; }
if pgrep -u '$ASC_USER' -f 'Runner.Worker' >/dev/null 2>&1 || pgrep -u '$ROO_USER' -f 'Runner.Worker' >/dev/null 2>&1; then
  echo 'ERROR: active Runner.Worker; service restore aborted' >&2
  exit 4
fi
while IFS='|' read -r side service enabled active; do
  [ -n "\$service" ] || continue
  if [ "\$enabled" = 'enabled' ]; then systemctl enable "\$service" >/dev/null; fi
  if [ "\$active" = 'active' ]; then systemctl start "\$service"; fi
  echo "RESTORED \$side service=\$service enabled=\$enabled active=\$active"
done < "\$STATE_FILE"
echo 'SHARED_RUNNER_SYSTEMD_RESTORE=PASS'
EOF
chmod 0755 "$SERVICE_ROLLBACK"

# Re-run the audited V1 installer only after legacy service autostart is neutralized.
bash "$BASE_INSTALLER"
sleep 3

listeners="$(pgrep -af 'Runner.Listener run' 2>/dev/null | wc -l || true)"
asc_workers="$(pgrep -u "$ASC_USER" -f 'Runner.Worker' 2>/dev/null | wc -l || true)"
roo_workers="$(pgrep -u "$ROO_USER" -f 'Runner.Worker' 2>/dev/null | wc -l || true)"

echo '=== SHARED RUNNER SYSTEMD REPAIR V1 ==='
echo "ASC_SERVICE=${ASC_SERVICE:-absent}"
echo "ROO_SERVICE=${ROO_SERVICE:-absent}"
echo "LISTENERS=${listeners:-0}"
echo "ASC_WORKERS=${asc_workers:-0}"
echo "ROO_WORKERS=${roo_workers:-0}"
echo "SERVICE_ROLLBACK=$SERVICE_ROLLBACK"

if [ "${listeners:-0}" -gt 1 ]; then
  echo 'ERROR: mas de un Runner.Listener despues de la reparacion' >&2
  exit 6
fi
if [ "${asc_workers:-0}" -ne 0 ] || [ "${roo_workers:-0}" -ne 0 ]; then
  echo 'ERROR: aparecio un Worker durante la reparacion; revisar antes de continuar' >&2
  exit 7
fi

echo 'SHARED_RUNNER_SYSTEMD_REPAIR=PASS'
