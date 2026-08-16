'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const DEFAULT_TARGET = 'https://ascenda-os-production.up.railway.app/health';
const DEFAULT_INTERVAL_MS = 60_000;
const DEFAULT_GAP_THRESHOLD_SECONDS = 120;

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch (_) { return null; }
}

function writeJsonAtomic(file, value) {
  const tmp = `${file}.tmp`;
  fs.writeFileSync(tmp, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(tmp, file);
}

function appendJsonl(file, value) {
  fs.appendFileSync(file, `${JSON.stringify(value)}\n`, { mode: 0o600 });
}

function safeHealthShape(input = {}) {
  return {
    ok: input.ok === true,
    service: input.service === 'ascenda-phase-s' ? 'ascenda-phase-s' : 'unexpected',
    child_alive: input.child_alive === true,
    inner_ready: input.inner_ready === true,
  };
}

function computeCoverageGap(previousSeenIso, nowMs = Date.now(), thresholdSeconds = DEFAULT_GAP_THRESHOLD_SECONDS) {
  if (!previousSeenIso) return null;
  const previousMs = Date.parse(previousSeenIso);
  if (!Number.isFinite(previousMs)) return null;
  const seconds = Math.max(0, Math.floor((nowMs - previousMs) / 1000));
  if (seconds <= thresholdSeconds) return null;
  return {
    type: 'coverage_gap',
    observer: 'creactive-local-observer',
    state: 'UNKNOWN',
    from: new Date(previousMs).toISOString(),
    to: new Date(nowMs).toISOString(),
    seconds,
    retroactive_health_claim: false,
  };
}

async function probe(targetUrl, timeoutMs = 10_000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const started = Date.now();
  try {
    const response = await fetch(targetUrl, {
      method: 'GET',
      redirect: 'follow',
      signal: controller.signal,
      headers: { 'user-agent': 'ascenda-sentinel-local-observer/1' },
    });
    let payload = {};
    try { payload = await response.json(); } catch (_) { payload = {}; }
    const health = safeHealthShape(payload);
    const semanticOk = response.status === 200 && health.ok && health.service === 'ascenda-phase-s' && health.child_alive && health.inner_ready;
    return {
      timestamp: new Date().toISOString(),
      http_status: response.status,
      duration_ms: Date.now() - started,
      semantic_ok: semanticOk,
      health,
      error_code: null,
    };
  } catch (error) {
    return {
      timestamp: new Date().toISOString(),
      http_status: null,
      duration_ms: Date.now() - started,
      semantic_ok: false,
      health: safeHealthShape({}),
      error_code: error && error.name === 'AbortError' ? 'TIMEOUT' : 'NETWORK_ERROR',
    };
  } finally {
    clearTimeout(timer);
  }
}

function resolveStateDir() {
  return process.env.SENTINEL_LOCAL_STATE_DIR || path.join(os.homedir(), '.local', 'share', 'ascenda-sentinel', 'availability', 'state');
}

async function runOnce(options = {}) {
  const stateDir = options.stateDir || resolveStateDir();
  const targetUrl = options.targetUrl || process.env.SENTINEL_HEALTH_URL || DEFAULT_TARGET;
  const thresholdSeconds = Number(options.gapThresholdSeconds || process.env.SENTINEL_GAP_THRESHOLD_SECONDS || DEFAULT_GAP_THRESHOLD_SECONDS);
  ensureDir(stateDir);

  const heartbeatFile = path.join(stateDir, 'observer-heartbeat.json');
  const gapsFile = path.join(stateDir, 'coverage-gaps.jsonl');
  const samplesFile = path.join(stateDir, 'health-samples.jsonl');
  const resumeFile = path.join(stateDir, 'resume-report.json');
  const latestFile = path.join(stateDir, 'latest-health.json');

  const nowMs = options.nowMs || Date.now();
  const previous = readJson(heartbeatFile);
  const gap = computeCoverageGap(previous && previous.last_seen, nowMs, thresholdSeconds);
  if (gap) appendJsonl(gapsFile, gap);

  // Observer heartbeat is independent of ASCENDA health. This prevents target downtime
  // from being confused with observer downtime.
  writeJsonAtomic(heartbeatFile, {
    observer: 'creactive-local-observer',
    host: 'CREACTIVE',
    last_seen: new Date(nowMs).toISOString(),
    state: 'ONLINE',
  });

  const sample = await probe(targetUrl, Number(process.env.SENTINEL_PROBE_TIMEOUT_MS || 10_000));
  appendJsonl(samplesFile, sample);
  writeJsonAtomic(latestFile, sample);

  const report = {
    schema_version: 'sentinel-observer-resume/v1',
    generated_at: new Date().toISOString(),
    observer: 'CREACTIVE',
    local_observer_state: 'ONLINE',
    coverage_gap: gap,
    coverage_gap_semantics: gap ? 'UNKNOWN' : 'NONE',
    current_health: sample.semantic_ok ? 'HEALTHY' : 'DEGRADED',
    current_probe: sample,
    cloud_coverage: {
      provider: 'sentry-uptime',
      expected_mode: 'continuous',
      local_api_reconciliation: false,
      history_location: 'Sentry Monitors/Uptime',
    },
    retroactive_claims_forbidden: true,
  };
  writeJsonAtomic(resumeFile, report);
  return report;
}

async function main() {
  const once = process.argv.includes('--once');
  const stateDir = resolveStateDir();
  const intervalMs = Number(process.env.SENTINEL_LOCAL_INTERVAL_MS || DEFAULT_INTERVAL_MS);

  const execute = async () => {
    const report = await runOnce({ stateDir });
    console.log(JSON.stringify({
      observer: report.observer,
      local_observer_state: report.local_observer_state,
      coverage_gap: report.coverage_gap ? report.coverage_gap.seconds : 0,
      current_health: report.current_health,
    }));
  };

  await execute();
  if (once) return;
  setInterval(() => execute().catch(err => console.error(`SENTINEL_LOCAL_OBSERVER_ERROR:${err && err.message ? err.message : 'unknown'}`)), intervalMs);
}

if (require.main === module) {
  main().catch(error => {
    console.error(`SENTINEL_LOCAL_OBSERVER_FATAL:${error && error.message ? error.message : 'unknown'}`);
    process.exitCode = 1;
  });
}

module.exports = { safeHealthShape, computeCoverageGap, probe, runOnce };
