# Shared Runner Dispatcher V1

Status: STAGED — not certified until reboot + bidirectional canary pass.

## Objective
Use one physical Windows/WSL machine (`CREACTIVE`) for two independent repo-level GitHub Actions runners without concurrent execution:

- ASCENDA OS: user `ascenda-runner`, runner `ASCENDA-ZERO-COST-V2`, label `ascenda-zero-cost-v2`.
- ROO7: user `cesar`, runner `CREACTIVE`, label `ascenda-drop-zero-cost-v1`.

Registrations, repositories and credentials remain separate.

## Coordination model
Two unprivileged user supervisors coordinate through `/var/tmp/ascenda-shared-runner-v1`.

Shared state:
- `runner.lock`: `flock` mutex. Only one listener can own the physical machine.
- `turn`: `ASCENDA` or `ROO7`.
- `active`: current owner or `NONE`.
- `roo7-installed`: installation handshake.
- `armed`: reboot activation handshake.

Each supervisor starts only its own existing repo-level runner. Cross-user sudo is not required or allowed.

## Scheduling semantics
- One listener at a time.
- A running `Runner.Worker` is never preempted.
- After a job completes, or after ~35 seconds listener-idle, ownership yields to the other repo.
- If both repos are idle, ownership continues to rotate. A newly queued job is therefore picked up after the next eligible slice without API polling or shared GitHub credentials.
- Log files rotate at 5 MiB.

## Boot
The existing Windows Startup bridge continues to start WSL. User crontabs start both supervisors on WSL boot. The shared `flock` and `turn` state determine which runner listener becomes active.

The old ASCENDA-only `@reboot /home/ascenda-runner/ascenda-runner-autoboot.sh` entry is removed only by the guarded ARM workflow after the ROO7 side has installed successfully.

## Certification gates
Do not call this CERTIFIED until all pass:

- `BOOT_AUTO=PASS`
- `ASCENDA_AUTO_START=PASS`
- `ROO7_AUTO_START=PASS`
- `SINGLE_RUNNER_LOCK=PASS`
- `NO_PREEMPT_RUNNING_JOB=PASS`
- `ASCENDA_TO_ROO7_SWITCH=PASS`
- `ROO7_TO_ASCENDA_SWITCH=PASS`
- `REBOOT_RECOVERY=PASS`
- `NO_SECRET_IN_LOGS=PASS`

## Rollback
Rollback is local and does not touch runner registration:

1. Stop the two shared supervisor processes.
2. Restore `/home/ascenda-runner/crontab.pre-arm-shared-runner-v1` (or `crontab.before-shared-runner-v1`) as the ASCENDA user.
3. Restore `/home/cesar/crontab.before-shared-runner-v1` as the `cesar` user.
4. Remove only the shared-supervisor `@reboot` entries if manual restoration is preferred.
5. Restart WSL. The prior ASCENDA-only autoboot path can then resume.

Never run `config.sh`; registrations are intentionally preserved.
