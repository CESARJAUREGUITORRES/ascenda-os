#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
const roots = process.argv.slice(2).length ? process.argv.slice(2) : ['app', 'sentinel'];
const allowedExt = new Set(['.js', '.cjs', '.mjs', '.jsx', '.ts', '.tsx', '.html']);
const excludedDirs = new Set(['node_modules', '.git', 'dist', 'build', 'coverage', '.next']);

const patterns = [
  ['SET_INTERVAL', /\bsetInterval\s*\(/],
  ['SET_TIMEOUT', /\bsetTimeout\s*\(/],
  ['MUTATION_OBSERVER', /\bMutationObserver\s*\(/],
  ['VISIBILITY_EVENT', /(?:addEventListener\s*\(\s*['\"]visibilitychange|onvisibilitychange\b)/],
  ['FOCUS_EVENT', /(?:addEventListener\s*\(\s*['\"]focus|\.onfocus\s*=)/],
  ['ONLINE_EVENT', /(?:addEventListener\s*\(\s*['\"]online|\.ononline\s*=)/],
  ['OFFLINE_EVENT', /(?:addEventListener\s*\(\s*['\"]offline|\.onoffline\s*=)/],
  ['PAGEHIDE_EVENT', /(?:addEventListener\s*\(\s*['\"]pagehide|\.onpagehide\s*=)/],
  ['DOCUMENT_HIDDEN', /\bdocument\.hidden\b/],
  ['FETCH', /\bfetch\s*\(/],
  ['WINDOW_FETCH_PATCH', /\bwindow\.fetch\s*=/],
  ['XHR', /\bXMLHttpRequest\b/],
  ['WEBSOCKET', /\bWebSocket\s*\(/],
  ['EVENT_SOURCE', /\bEventSource\s*\(/],
  ['SEND_BEACON', /\bnavigator\.sendBeacon\s*\(/],
  ['SERVICE_WORKER', /\bserviceWorker\b/],
  ['REST_V1', /\/rest\/v1\//],
  ['RPC_PATH', /\/rpc\//],
  ['RPC_HELPER', /\b(?:rpc|sbRpc|serviceRpc)\s*\(/],
  ['SB_FETCH_HELPER', /\b(?:sbFetch|sbGet|api)\s*\(/],
  ['PROMISE_ALL', /\bPromise\.all\s*\(/],
  ['MAP_CALL', /\.map\s*\(/],
  ['SELECT_STAR_URL', /select=\*/i],
  ['SELECT_STAR_CLIENT', /\.select\s*\(\s*['\"]\*['\"]\s*\)/],
  ['LARGE_LIMIT', /(?:limit=|\.limit\s*\()\s*(?:1[0-9]{2,}|[2-9][0-9]{2,})/i],
  ['POLL_NAME', /\b(?:poll|polling|heartbeat|refresh|refetch|retry|backoff|pump|cron|worker|tick)\w*\b/i],
];

const redactionRules = [
  [/eyJ[A-Za-z0-9._-]{20,}/g, '[JWT_REDACTED]'],
  [/(?:sk|sbp|ghp|github_pat|xox[baprs])-?[A-Za-z0-9_\-]{12,}/gi, '[TOKEN_REDACTED]'],
  [/(Authorization\s*[:=]\s*)[^,;\n]+/gi, '$1[REDACTED]'],
  [/(apikey\s*[:=]\s*)[^,;\n]+/gi, '$1[REDACTED]'],
];

function sanitizeLine(line) {
  let out = String(line || '').trim();
  for (const [re, replacement] of redactionRules) out = out.replace(re, replacement);
  if (out.length > 260) out = out.slice(0, 257) + '...';
  return out;
}

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory() && excludedDirs.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (allowedExt.has(path.extname(entry.name).toLowerCase())) out.push(full);
  }
  return out;
}

function literalIntervalMs(line) {
  const m = line.match(/setInterval\s*\([^\n]*?,\s*(\d{2,})\s*\)/);
  return m ? Number(m[1]) : null;
}

const files = [...new Set(roots.flatMap(root => walk(path.join(repoRoot, root))))].sort();
const findings = [];
const fileFacts = new Map();

for (const file of files) {
  const rel = path.relative(repoRoot, file).replaceAll('\\', '/');
  const text = fs.readFileSync(file, 'utf8');
  const lines = text.split(/\r?\n/);
  const facts = {
    file: rel,
    lineCount: lines.length,
    hasNetworkPrimitive: false,
    hasRecurrentConstruct: false,
    hasVisibilityGuard: false,
    patternCounts: {},
  };

  lines.forEach((line, i) => {
    for (const [name, re] of patterns) {
      if (!re.test(line)) continue;
      facts.patternCounts[name] = (facts.patternCounts[name] || 0) + 1;
      if (['FETCH','XHR','WEBSOCKET','EVENT_SOURCE','SEND_BEACON','REST_V1','RPC_PATH','RPC_HELPER','SB_FETCH_HELPER'].includes(name)) facts.hasNetworkPrimitive = true;
      if (['SET_INTERVAL','SET_TIMEOUT','MUTATION_OBSERVER','VISIBILITY_EVENT','FOCUS_EVENT','ONLINE_EVENT','OFFLINE_EVENT','PAGEHIDE_EVENT','SERVICE_WORKER'].includes(name)) facts.hasRecurrentConstruct = true;
      if (name === 'DOCUMENT_HIDDEN' || name === 'VISIBILITY_EVENT') facts.hasVisibilityGuard = true;
      findings.push({
        file: rel,
        line: i + 1,
        pattern: name,
        intervalMs: name === 'SET_INTERVAL' ? literalIntervalMs(line) : null,
        source: sanitizeLine(line),
      });
    }
  });
  fileFacts.set(rel, facts);
}

const countsByPattern = {};
for (const f of findings) countsByPattern[f.pattern] = (countsByPattern[f.pattern] || 0) + 1;

const recurrentNetworkCandidates = [...fileFacts.values()]
  .filter(f => f.hasRecurrentConstruct && f.hasNetworkPrimitive)
  .map(f => ({
    file: f.file,
    hasVisibilityGuard: f.hasVisibilityGuard,
    recurrent: Object.fromEntries(Object.entries(f.patternCounts).filter(([k]) => ['SET_INTERVAL','SET_TIMEOUT','MUTATION_OBSERVER','VISIBILITY_EVENT','FOCUS_EVENT','ONLINE_EVENT','OFFLINE_EVENT','PAGEHIDE_EVENT','SERVICE_WORKER'].includes(k))),
    network: Object.fromEntries(Object.entries(f.patternCounts).filter(([k]) => ['FETCH','XHR','WEBSOCKET','EVENT_SOURCE','SEND_BEACON','REST_V1','RPC_PATH','RPC_HELPER','SB_FETCH_HELPER'].includes(k))),
    broadReadSignals: Object.fromEntries(Object.entries(f.patternCounts).filter(([k]) => ['SELECT_STAR_URL','SELECT_STAR_CLIENT','LARGE_LIMIT'].includes(k))),
    fanoutSignals: Object.fromEntries(Object.entries(f.patternCounts).filter(([k]) => ['PROMISE_ALL','MAP_CALL'].includes(k))),
  }))
  .sort((a, b) => a.file.localeCompare(b.file));

const fastIntervalFindings = findings
  .filter(f => f.pattern === 'SET_INTERVAL' && Number.isFinite(f.intervalMs) && f.intervalMs < 5000)
  .map(f => ({ file: f.file, line: f.line, intervalMs: f.intervalMs }));

const broadReadFindings = findings
  .filter(f => ['SELECT_STAR_URL','SELECT_STAR_CLIENT','LARGE_LIMIT'].includes(f.pattern))
  .map(f => ({ file: f.file, line: f.line, pattern: f.pattern }));

const result = {
  schema: 'asc-perf-runtime-census/v1',
  generatedAt: new Date().toISOString(),
  roots,
  filesScanned: files.length,
  linesScanned: [...fileFacts.values()].reduce((n, f) => n + f.lineCount, 0),
  findingsCount: findings.length,
  countsByPattern,
  recurrentNetworkCandidateCount: recurrentNetworkCandidates.length,
  fastIntervalCandidateCount: fastIntervalFindings.length,
  broadReadCandidateCount: broadReadFindings.length,
  recurrentNetworkCandidates,
  fastIntervalFindings,
  broadReadFindings,
  findings,
  notes: [
    'Static evidence only; candidates require runtime/consumer triage before defect classification.',
    'SET_TIMEOUT is intentionally broad because recursive timers cannot be reliably identified with single-line regex.',
    'No secrets should be emitted; source lines are redacted defensively.',
  ],
};

const outDir = process.env.RUNNER_TEMP || path.join(repoRoot, '.tmp');
fs.mkdirSync(outDir, { recursive: true });
const outPath = path.join(outDir, 'asc-perf-runtime-census.json');
fs.writeFileSync(outPath, JSON.stringify(result, null, 2));

console.log('ASC-PERF-1A STATIC CENSUS');
console.log(`files_scanned=${result.filesScanned}`);
console.log(`lines_scanned=${result.linesScanned}`);
console.log(`findings=${result.findingsCount}`);
console.log(`recurrent_network_candidate_files=${result.recurrentNetworkCandidateCount}`);
console.log(`fast_interval_candidates_lt_5000ms=${result.fastIntervalCandidateCount}`);
console.log(`broad_read_candidates=${result.broadReadCandidateCount}`);
console.log('counts_by_pattern=' + JSON.stringify(result.countsByPattern));
console.log('candidate_files_begin');
for (const item of recurrentNetworkCandidates) {
  console.log(JSON.stringify({ file: item.file, hiddenGuard: item.hasVisibilityGuard, recurrent: item.recurrent, network: item.network, broad: item.broadReadSignals, fanout: item.fanoutSignals }));
}
console.log('candidate_files_end');
console.log(`census_json=${outPath}`);
