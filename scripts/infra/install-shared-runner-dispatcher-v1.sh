#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo 'ERROR: ejecutar con sudo bash <installer>' >&2
  exit 2
fi

ASC_USER='ascenda-runner'
ROO_USER='cesar'
ASC_HOME='/home/ascenda-runner'
ROO_HOME='/home/cesar'
ROO_DIR='/home/cesar/actions-runner'
STATE_DIR='/var/tmp/ascenda-shared-runner-v1'
SUPERVISOR='/usr/local/libexec/ascenda-shared-runner-supervisor-v1'
ROLLBACK='/usr/local/sbin/ascenda-shared-runner-rollback-v1'
LEGACY_VISIBLE='/home/ascenda-runner/bin/visible-runner.sh'
LEGACY_BACKUP='/home/ascenda-runner/bin/visible-runner.sh.pre-shared-runner-v1'
ASC_LOG='/home/ascenda-runner/shared-runner-supervisor-v1.log'
ROO_LOG='/home/cesar/shared-runner-supervisor-v1.log'

if [ -x '/home/ascenda-runner/actions-runner/actions-runner/run.sh' ]; then
  ASC_DIR='/home/ascenda-runner/actions-runner/actions-runner'
elif [ -x '/home/ascenda-runner/actions-runner/run.sh' ]; then
  ASC_DIR='/home/ascenda-runner/actions-runner'
else
  echo 'ERROR: no se encontro run.sh de ASCENDA' >&2
  exit 3
fi

getent passwd "$ASC_USER" >/dev/null
getent passwd "$ROO_USER" >/dev/null
test -x "$ASC_DIR/run.sh"
test -x "$ROO_DIR/run.sh"
grep -Fq 'CESARJAUREGUITORRES/ascenda-os' "$ASC_DIR/.runner"
grep -Fq 'CESARJAUREGUITORRES/roosiete' "$ROO_DIR/.runner"
id -nG "$ASC_USER" | grep -qw docker
id -nG "$ROO_USER" | grep -qw docker

# Never preempt a job already executing.
if pgrep -u "$ASC_USER" -f 'Runner.Worker' >/dev/null 2>&1 || pgrep -u "$ROO_USER" -f 'Runner.Worker' >/dev/null 2>&1; then
  echo 'ERROR: hay un Runner.Worker activo. Esperar a que termine el job y volver a ejecutar.' >&2
  exit 4
fi

install -d -m 0755 /usr/local/libexec /usr/local/sbin
install -d -m 2770 -g docker "$STATE_DIR"
touch "$STATE_DIR/runner.lock" "$STATE_DIR/turn" "$STATE_DIR/active"
chgrp docker "$STATE_DIR/runner.lock" "$STATE_DIR/turn" "$STATE_DIR/active"
chmod 0660 "$STATE_DIR/runner.lock" "$STATE_DIR/turn" "$STATE_DIR/active"

cat > "$SUPERVISOR" <<'SUPERVISOR_SCRIPT'
#!/usr/bin/env bash
set -u

SELF="${1:?SELF}"
RUNNER_DIR="${2:?RUNNER_DIR}"
OTHER="${3:?OTHER}"
LOG="${4:?LOG}"
STATE_DIR='/var/tmp/ascenda-shared-runner-v1'
GLOBAL_LOCK="$STATE_DIR/runner.lock"
TURN="$STATE_DIR/turn"
ACTIVE="$STATE_DIR/active"
SIDE_LOCK="$STATE_DIR/${SELF,,}.supervisor.lock"
IDLE_SLICE=20
POLL=2

[ -d "$STATE_DIR" ] || exit 3
touch "$SIDE_LOCK" 2>/dev/null || exit 3
chgrp docker "$SIDE_LOCK" 2>/dev/null || true
chmod 0660 "$SIDE_LOCK" 2>/dev/null || true

# Exactly one supervisor process per side.
exec 8>"$SIDE_LOCK"
/usr/bin/flock -n 8 || exit 0

rotate_log() {
  [ -f "$LOG" ] || return 0
  local size
  size=$(/usr/bin/stat -c%s "$LOG" 2>/dev/null || echo 0)
  if [ "${size:-0}" -gt 5242880 ]; then
    /bin/mv -f "$LOG" "$LOG.1" 2>/dev/null || true
  fi
}
log() {
  rotate_log
  printf '[%s] [%s] %s\n' "$(/bin/date -Is)" "$SELF" "$*" >> "$LOG"
}
stop_listener() {
  local pid="$1"
  /bin/kill -TERM "$pid" 2>/dev/null || true
  for _ in $(seq 1 10); do
    /bin/kill -0 "$pid" 2>/dev/null || return 0
    /bin/sleep 1
  done
  log 'listener did not stop within grace period; retaining lock and listener'
  return 1
}

log 'supervisor started'
while true; do
  turn=$(cat "$TURN" 2>/dev/null || echo ROO7)
  if [ "$turn" != "$SELF" ]; then
    /bin/sleep "$POLL"
    continue
  fi

  exec 9>"$GLOBAL_LOCK"
  if ! /usr/bin/flock -n 9; then
    exec 9>&-
    /bin/sleep "$POLL"
    continue
  fi

  turn=$(cat "$TURN" 2>/dev/null || echo ROO7)
  if [ "$turn" != "$SELF" ]; then
    exec 9>&-
    /bin/sleep "$POLL"
    continue
  fi

  printf '%s\n' "$SELF" > "$ACTIVE"
  log 'listener starting'
  cd "$RUNNER_DIR" || {
    log 'runner directory missing; yielding'
    printf '%s\n' "$OTHER" > "$TURN"
    printf '%s\n' 'NONE' > "$ACTIVE"
    exec 9>&-
    /bin/sleep 5
    continue
  }

  ./run.sh >> "$LOG" 2>&1 &
  listener_pid=$!
  idle_since=$(/bin/date +%s)
  worker_seen=0
  intentional_yield=0

  while /bin/kill -0 "$listener_pid" 2>/dev/null; do
    now=$(/bin/date +%s)
    if /usr/bin/pgrep -u "$(id -u)" -f "$RUNNER_DIR/bin/Runner.Worker" >/dev/null 2>&1; then
      worker_seen=1
      idle_since=$now
    else
      idle_for=$((now-idle_since))
      if [ "$idle_for" -ge "$IDLE_SLICE" ]; then
        log "idle ${idle_for}s; yielding to $OTHER"
        if stop_listener "$listener_pid"; then
          wait "$listener_pid" 2>/dev/null || true
          intentional_yield=1
          printf '%s\n' "$OTHER" > "$TURN"
          printf '%s\n' 'NONE' > "$ACTIVE"
          break
        else
          idle_since=$now
          log 'yield deferred because listener is still alive'
        fi
      fi
    fi
    /bin/sleep "$POLL"
  done

  if [ "$intentional_yield" -eq 0 ] && ! /bin/kill -0 "$listener_pid" 2>/dev/null; then
    if [ "$worker_seen" -eq 1 ]; then
      log "listener exited after work; yielding to $OTHER"
    else
      log "listener exited unexpectedly; yielding to $OTHER"
    fi
    printf '%s\n' "$OTHER" > "$TURN"
    printf '%s\n' 'NONE' > "$ACTIVE"
  fi

  exec 9>&-
  /bin/sleep "$POLL"
done
SUPERVISOR_SCRIPT
chmod 0755 "$SUPERVISOR"

# Preserve the existing ASCENDA-only Windows bridge once, then turn that same
# path into a dispatcher-aware status bridge. No Windows task needs reconfiguration.
if [ -f "$LEGACY_VISIBLE" ] && [ ! -f "$LEGACY_BACKUP" ]; then
  cp -a "$LEGACY_VISIBLE" "$LEGACY_BACKUP"
fi
cat > "$LEGACY_VISIBLE" <<EOF
#!/usr/bin/env bash
set -u
STATE_DIR='$STATE_DIR'
SUPERVISOR='$SUPERVISOR'
ASC_DIR='$ASC_DIR'
LOG='$ASC_LOG'
if [ -f "\$STATE_DIR/installed" ]; then
  if ! /usr/bin/pgrep -u "\$(id -u)" -f "\$SUPERVISOR ASCENDA" >/dev/null 2>&1; then
    /usr/bin/nohup "\$SUPERVISOR" ASCENDA "\$ASC_DIR" ROO7 "\$LOG" >/dev/null 2>&1 &
  fi
  echo 'ASCENDA SHARED RUNNER DISPATCHER V1 activo'
  echo 'Esta ventana ya no fuerza ASCENDA; el dispatcher arbitra ASCENDA <-> ROO7.'
  exec /usr/bin/tail -n 40 -F "\$LOG"
fi
if [ -x '$LEGACY_BACKUP' ]; then exec '$LEGACY_BACKUP'; fi
echo 'Legacy runner bridge unavailable' >&2
exit 1
EOF
chown "$ASC_USER":"$(id -gn "$ASC_USER")" "$LEGACY_VISIBLE"
chmod 0755 "$LEGACY_VISIBLE"

# Back up crontabs in stable rollback locations.
crontab -u "$ASC_USER" -l > "$ASC_HOME/crontab.pre-shared-runner-v1" 2>/dev/null || :
crontab -u "$ROO_USER" -l > "$ROO_HOME/crontab.pre-shared-runner-v1" 2>/dev/null || :
chown "$ASC_USER":"$(id -gn "$ASC_USER")" "$ASC_HOME/crontab.pre-shared-runner-v1"
chown "$ROO_USER":"$(id -gn "$ROO_USER")" "$ROO_HOME/crontab.pre-shared-runner-v1"

rewrite_crontab() {
  local user="$1" self="$2" dir="$3" other="$4" log="$5"
  local current cleaned
  current=$(crontab -u "$user" -l 2>/dev/null || true)
  cleaned=$(printf '%s\n' "$current" \
    | grep -vF '# ASCENDA_ZERO_COST_V2_AUTOBOOT' \
    | grep -vF '# ASCENDA_SHARED_RUNNER_DISPATCHER_V1' \
    | grep -vF '# ROO7_SHARED_RUNNER_DISPATCHER_V1' \
    | grep -vF '/home/ascenda-runner/ascenda-runner-autoboot.sh' \
    | grep -vF '/home/ascenda-runner/bin/visible-runner.sh' \
    | grep -vF 'shared-runner-supervisor-v1' \
    | grep -vF 'ascenda-shared-runner-supervisor-v1' || true)
  {
    printf '%s\n' "$cleaned"
    printf '%s\n' "# ${self}_SHARED_RUNNER_DISPATCHER_V1"
    printf '@reboot /usr/bin/nohup %q %q %q %q %q >/dev/null 2>&1 &\n' "$SUPERVISOR" "$self" "$dir" "$other" "$log"
  } | sed '/^[[:space:]]*$/N;/^\n$/D' | crontab -u "$user" -
}
rewrite_crontab "$ASC_USER" ASCENDA "$ASC_DIR" ROO7 "$ASC_LOG"
rewrite_crontab "$ROO_USER" ROO7 "$ROO_DIR" ASCENDA "$ROO_LOG"

cat > "$ROLLBACK" <<EOF
#!/usr/bin/env bash
set -euo pipefail
[ "\${EUID}" -eq 0 ] || { echo 'run with sudo' >&2; exit 2; }
if pgrep -u '$ASC_USER' -f 'Runner.Worker' >/dev/null 2>&1 || pgrep -u '$ROO_USER' -f 'Runner.Worker' >/dev/null 2>&1; then
  echo 'ERROR: active Runner.Worker; rollback aborted' >&2
  exit 3
fi
pkill -TERM -u '$ASC_USER' -f '$SUPERVISOR' 2>/dev/null || true
pkill -TERM -u '$ROO_USER' -f '$SUPERVISOR' 2>/dev/null || true
pkill -TERM -u '$ASC_USER' -f 'Runner.Listener run' 2>/dev/null || true
pkill -TERM -u '$ROO_USER' -f 'Runner.Listener run' 2>/dev/null || true
sleep 2
if [ -f '$LEGACY_BACKUP' ]; then cp -a '$LEGACY_BACKUP' '$LEGACY_VISIBLE'; chown '$ASC_USER':'$(id -gn "$ASC_USER")' '$LEGACY_VISIBLE'; chmod 0755 '$LEGACY_VISIBLE'; fi
if [ -f '$ASC_HOME/crontab.pre-shared-runner-v1' ]; then crontab -u '$ASC_USER' '$ASC_HOME/crontab.pre-shared-runner-v1'; fi
if [ -f '$ROO_HOME/crontab.pre-shared-runner-v1' ]; then crontab -u '$ROO_USER' '$ROO_HOME/crontab.pre-shared-runner-v1'; fi
rm -f '$STATE_DIR/installed' '$STATE_DIR/armed'
printf '%s\n' ASCENDA > '$STATE_DIR/turn' 2>/dev/null || true
printf '%s\n' NONE > '$STATE_DIR/active' 2>/dev/null || true
if [ -x '$LEGACY_VISIBLE' ]; then runuser -u '$ASC_USER' -- /usr/bin/nohup '$LEGACY_VISIBLE' >/dev/null 2>&1 & fi
echo 'SHARED_RUNNER_DISPATCHER_ROLLBACK=PASS'
EOF
chmod 0755 "$ROLLBACK"

# Mark installed before killing the legacy bridge so a Windows relaunch is safe.
printf '%s\n' installed > "$STATE_DIR/installed"
printf '%s\n' ROO7 > "$STATE_DIR/turn"
printf '%s\n' NONE > "$STATE_DIR/active"
chgrp docker "$STATE_DIR/installed" "$STATE_DIR/turn" "$STATE_DIR/active"
chmod 0660 "$STATE_DIR/installed" "$STATE_DIR/turn" "$STATE_DIR/active"

# Retire legacy ASCENDA-only loop. Since Worker was checked above, this does not
# interrupt a running CI job.
pkill -TERM -u "$ASC_USER" -f '/home/ascenda-runner/bin/visible-runner.sh' 2>/dev/null || true
pkill -TERM -u "$ASC_USER" -f 'Runner.Listener run' 2>/dev/null || true
pkill -TERM -u "$ROO_USER" -f 'Runner.Listener run' 2>/dev/null || true
pkill -TERM -u "$ASC_USER" -f "$SUPERVISOR" 2>/dev/null || true
pkill -TERM -u "$ROO_USER" -f "$SUPERVISOR" 2>/dev/null || true
sleep 3

# Start both coordinators. ROO7 receives first turn because it currently has
# queued certification work. The global flock guarantees a single listener.
runuser -u "$ASC_USER" -- /usr/bin/nohup "$SUPERVISOR" ASCENDA "$ASC_DIR" ROO7 "$ASC_LOG" >/dev/null 2>&1 &
runuser -u "$ROO_USER" -- /usr/bin/nohup "$SUPERVISOR" ROO7 "$ROO_DIR" ASCENDA "$ROO_LOG" >/dev/null 2>&1 &
sleep 5

echo '=== SHARED RUNNER DISPATCHER V1 ==='
echo "ASCENDA_DIR=$ASC_DIR"
echo "ROO7_DIR=$ROO_DIR"
echo "TURN=$(cat "$STATE_DIR/turn" 2>/dev/null || echo missing)"
echo "ACTIVE=$(cat "$STATE_DIR/active" 2>/dev/null || echo missing)"
echo "ASC_SUPERVISOR=$(pgrep -u "$ASC_USER" -f "$SUPERVISOR ASCENDA" >/dev/null && echo running || echo stopped)"
echo "ROO_SUPERVISOR=$(pgrep -u "$ROO_USER" -f "$SUPERVISOR ROO7" >/dev/null && echo running || echo stopped)"
listeners=$(pgrep -af 'Runner.Listener run' 2>/dev/null | wc -l || true)
echo "LISTENERS=${listeners:-0}"
echo "ROLLBACK=$ROLLBACK"
echo 'SHARED_RUNNER_DISPATCHER_INSTALL=PASS'
