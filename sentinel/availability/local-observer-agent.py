#!/usr/bin/env python3
import json
import os
import pathlib
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone

DEFAULT_TARGET = 'https://ascenda-os-production.up.railway.app/health'
DEFAULT_INTERVAL_SECONDS = 60
DEFAULT_GAP_THRESHOLD_SECONDS = 120


def iso_now(ts=None):
    return datetime.fromtimestamp(ts if ts is not None else time.time(), timezone.utc).isoformat().replace('+00:00', 'Z')


def read_json(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return None


def write_json_atomic(path, value):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + '.tmp')
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(value, f, indent=2, sort_keys=True)
        f.write('\n')
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def append_jsonl(path, value):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'a', encoding='utf-8') as f:
        f.write(json.dumps(value, separators=(',', ':')) + '\n')
    os.chmod(path, 0o600)


def safe_health_shape(payload):
    payload = payload if isinstance(payload, dict) else {}
    return {
        'ok': payload.get('ok') is True,
        'service': 'ascenda-phase-s' if payload.get('service') == 'ascenda-phase-s' else 'unexpected',
        'child_alive': payload.get('child_alive') is True,
        'inner_ready': payload.get('inner_ready') is True,
    }


def parse_iso(value):
    if not value or not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()
    except Exception:
        return None


def compute_coverage_gap(previous_seen_iso, now_ts=None, threshold_seconds=DEFAULT_GAP_THRESHOLD_SECONDS):
    previous_ts = parse_iso(previous_seen_iso)
    if previous_ts is None:
        return None
    now_ts = time.time() if now_ts is None else float(now_ts)
    seconds = max(0, int(now_ts - previous_ts))
    if seconds <= int(threshold_seconds):
        return None
    return {
        'type': 'coverage_gap',
        'observer': 'creactive-local-observer',
        'state': 'UNKNOWN',
        'from': iso_now(previous_ts),
        'to': iso_now(now_ts),
        'seconds': seconds,
        'retroactive_health_claim': False,
    }


def probe(target_url, timeout_seconds=10):
    started = time.time()
    request = urllib.request.Request(target_url, method='GET', headers={'User-Agent': 'ascenda-sentinel-local-observer/1'})
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            status = int(response.getcode())
            raw = response.read(8192)
            try:
                payload = json.loads(raw.decode('utf-8'))
            except Exception:
                payload = {}
            health = safe_health_shape(payload)
            semantic_ok = status == 200 and all([
                health['ok'],
                health['service'] == 'ascenda-phase-s',
                health['child_alive'],
                health['inner_ready'],
            ])
            return {
                'timestamp': iso_now(),
                'http_status': status,
                'duration_ms': int((time.time() - started) * 1000),
                'semantic_ok': semantic_ok,
                'health': health,
                'error_code': None,
            }
    except urllib.error.HTTPError as exc:
        return {
            'timestamp': iso_now(),
            'http_status': int(exc.code),
            'duration_ms': int((time.time() - started) * 1000),
            'semantic_ok': False,
            'health': safe_health_shape({}),
            'error_code': 'HTTP_ERROR',
        }
    except Exception as exc:
        code = 'TIMEOUT' if isinstance(exc, TimeoutError) else 'NETWORK_ERROR'
        return {
            'timestamp': iso_now(),
            'http_status': None,
            'duration_ms': int((time.time() - started) * 1000),
            'semantic_ok': False,
            'health': safe_health_shape({}),
            'error_code': code,
        }


def resolve_state_dir():
    return pathlib.Path(os.environ.get(
        'SENTINEL_LOCAL_STATE_DIR',
        str(pathlib.Path.home() / '.local' / 'share' / 'ascenda-sentinel' / 'availability' / 'state')
    ))


def run_once(state_dir=None, target_url=None, gap_threshold_seconds=None, now_ts=None):
    state_dir = pathlib.Path(state_dir) if state_dir else resolve_state_dir()
    state_dir.mkdir(parents=True, exist_ok=True)
    target_url = target_url or os.environ.get('SENTINEL_HEALTH_URL', DEFAULT_TARGET)
    threshold = int(gap_threshold_seconds or os.environ.get('SENTINEL_GAP_THRESHOLD_SECONDS', DEFAULT_GAP_THRESHOLD_SECONDS))
    now_ts = time.time() if now_ts is None else float(now_ts)

    heartbeat_file = state_dir / 'observer-heartbeat.json'
    gaps_file = state_dir / 'coverage-gaps.jsonl'
    samples_file = state_dir / 'health-samples.jsonl'
    resume_file = state_dir / 'resume-report.json'
    latest_file = state_dir / 'latest-health.json'

    previous = read_json(heartbeat_file) or {}
    gap = compute_coverage_gap(previous.get('last_seen'), now_ts, threshold)
    if gap:
        append_jsonl(gaps_file, gap)

    write_json_atomic(heartbeat_file, {
        'observer': 'creactive-local-observer',
        'host': 'CREACTIVE',
        'last_seen': iso_now(now_ts),
        'state': 'ONLINE',
    })

    sample = probe(target_url, int(os.environ.get('SENTINEL_PROBE_TIMEOUT_SECONDS', '10')))
    append_jsonl(samples_file, sample)
    write_json_atomic(latest_file, sample)

    report = {
        'schema_version': 'sentinel-observer-resume/v1',
        'generated_at': iso_now(),
        'observer': 'CREACTIVE',
        'local_observer_state': 'ONLINE',
        'coverage_gap': gap,
        'coverage_gap_semantics': 'UNKNOWN' if gap else 'NONE',
        'current_health': 'HEALTHY' if sample['semantic_ok'] else 'DEGRADED',
        'current_probe': sample,
        'cloud_coverage': {
            'provider': 'uptimerobot',
            'expected_mode': 'continuous-5-minute',
            'local_api_reconciliation': False,
            'history_location': 'UptimeRobot Dashboard',
        },
        'retroactive_claims_forbidden': True,
    }
    write_json_atomic(resume_file, report)
    return report


def main():
    once = '--once' in sys.argv
    interval = int(os.environ.get('SENTINEL_LOCAL_INTERVAL_SECONDS', DEFAULT_INTERVAL_SECONDS))
    while True:
        report = run_once()
        print(json.dumps({
            'observer': report['observer'],
            'local_observer_state': report['local_observer_state'],
            'coverage_gap': report['coverage_gap']['seconds'] if report['coverage_gap'] else 0,
            'current_health': report['current_health'],
        }), flush=True)
        if once:
            return
        time.sleep(interval)


if __name__ == '__main__':
    main()
