'use strict';

const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { pathToFileURL } = require('url');

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
  throw new Error(message);
}

function canonicalExisting(input, label) {
  const absolute = path.resolve(input);
  if (!fs.existsSync(absolute)) fail(`${label}_MISSING: ${absolute}`);
  return fs.realpathSync.native(absolute);
}

function parseStrictJson(text, label) {
  let i = 0;
  function whitespace() { while (i < text.length && /[\x20\t\r\n]/.test(text[i])) i += 1; }
  function stringToken() {
    const start = i;
    if (text[i++] !== '"') fail(`${label}_JSON_STRING`);
    while (i < text.length) {
      if (text.charCodeAt(i) < 0x20) fail(`${label}_JSON_CONTROL`);
      if (text[i] === '"') { i += 1; return JSON.parse(text.slice(start, i)); }
      if (text[i] === '\\') {
        i += 1;
        if (!/^["\\/bfnrtu]$/.test(text[i] || '')) fail(`${label}_JSON_ESCAPE`);
        if (text[i] === 'u') {
          if (!/^[0-9a-fA-F]{4}$/.test(text.slice(i + 1, i + 5))) fail(`${label}_JSON_UNICODE`);
          i += 4;
        }
      }
      i += 1;
    }
    fail(`${label}_JSON_UNTERMINATED_STRING`);
  }
  function value() {
    whitespace();
    if (text[i] === '{') return object();
    if (text[i] === '[') return array();
    if (text[i] === '"') return stringToken();
    const remaining = text.slice(i);
    const token = /^(?:true|false|null|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)/.exec(remaining);
    if (!token) fail(`${label}_JSON_VALUE`);
    i += token[0].length;
    return JSON.parse(token[0]);
  }
  function object() {
    i += 1; whitespace();
    const output = {}; const seen = new Set();
    if (text[i] === '}') { i += 1; return output; }
    while (true) {
      whitespace();
      if (text[i] !== '"') fail(`${label}_JSON_KEY`);
      const key = stringToken();
      if (seen.has(key)) fail(`${label}_JSON_DUPLICATE_MEMBER: ${key}`);
      seen.add(key); whitespace();
      if (text[i++] !== ':') fail(`${label}_JSON_COLON`);
      output[key] = value(); whitespace();
      if (text[i] === '}') { i += 1; return output; }
      if (text[i++] !== ',') fail(`${label}_JSON_COMMA`);
    }
  }
  function array() {
    i += 1; whitespace();
    const output = [];
    if (text[i] === ']') { i += 1; return output; }
    while (true) {
      output.push(value()); whitespace();
      if (text[i] === ']') { i += 1; return output; }
      if (text[i++] !== ',') fail(`${label}_JSON_COMMA`);
    }
  }
  const parsed = value(); whitespace();
  if (i !== text.length) fail(`${label}_JSON_TRAILING_DATA`);
  return parsed;
}

function live(pid) {
  try { process.kill(pid, 0); return true; }
  catch (error) {
    if (error && error.code === 'ESRCH') return false;
    throw error;
  }
}

async function waitForExit(pid) {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    if (!live(pid)) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  fail(`DAEMON_STILL_LIVE: ${pid}`);
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length !== 3) fail('USAGE: stop_repository_codegraph_daemon.cjs <module-path> <module-sha256> <repository-root>');
  const [moduleArgument, expectedHash, rootArgument] = args;
  if (!/^[0-9a-f]{64}$/.test(expectedHash)) fail('MODULE_SHA256_INVALID');
  const modulePath = canonicalExisting(moduleArgument, 'MODULE');
  const repositoryRoot = canonicalExisting(rootArgument, 'REPOSITORY_ROOT');
  if (path.basename(modulePath).toLowerCase() !== 'daemon-registry.js') fail('MODULE_BASENAME_INVALID');
  const actualHash = crypto.createHash('sha256').update(fs.readFileSync(modulePath)).digest('hex');
  if (actualHash !== expectedHash) fail(`MODULE_SHA256_DRIFT: ${actualHash}`);
  const projectFile = path.join(repositoryRoot, 'project.godot');
  if (!fs.statSync(projectFile).isFile()) fail('REPOSITORY_PROJECT_MISSING');
  const lockPath = path.join(repositoryRoot, '.codegraph', 'daemon.pid');
  let registryRecord = null;
  if (!fs.existsSync(lockPath)) {
    const registryDir = path.join(os.homedir(), '.codegraph', 'daemons');
    const matches = fs.existsSync(registryDir)
      ? fs.readdirSync(registryDir)
        .filter((name) => name.endsWith('.json'))
        .map((name) => parseStrictJson(fs.readFileSync(path.join(registryDir, name), 'utf8'), `DAEMON_REGISTRY_${name}`))
        .filter((record) => record && typeof record.root === 'string' && path.resolve(record.root).toLowerCase() === path.resolve(repositoryRoot).toLowerCase())
      : [];
    if (matches.length > 1) fail('DAEMON_REGISTRY_ROOT_DUPLICATE');
    if (matches.length === 0) {
      process.stdout.write(`${JSON.stringify({ root: repositoryRoot, pid: null, outcome: 'absent' })}\n`);
      return;
    }
    registryRecord = matches[0];
  }
  const lock = registryRecord || parseStrictJson(fs.readFileSync(lockPath, 'utf8'), 'DAEMON_LOCK');
  if (!lock || typeof lock !== 'object' || Array.isArray(lock)) fail('DAEMON_LOCK_OBJECT_REQUIRED');
  const pid = Number(lock.pid);
  if (!Number.isSafeInteger(pid) || pid <= 0) fail('DAEMON_LOCK_PID_INVALID');
  if (typeof lock.root === 'string' && canonicalExisting(lock.root, 'DAEMON_LOCK_ROOT') !== repositoryRoot) fail('DAEMON_LOCK_ROOT_MISMATCH');
  const wasLive = live(pid);

  const imported = await import(pathToFileURL(modulePath).href);
  const stopDaemonAt = imported.stopDaemonAt || (imported.default && imported.default.stopDaemonAt);
  if (typeof stopDaemonAt !== 'function') fail('STOP_DAEMON_AT_EXPORT_MISSING');
  const returned = await stopDaemonAt(repositoryRoot);
  if (!returned || typeof returned !== 'object' || Array.isArray(returned)) fail('STOP_DAEMON_AT_RESULT_OBJECT_REQUIRED');
  const returnedKeys = Object.keys(returned).sort();
  if (JSON.stringify(returnedKeys) !== JSON.stringify(['outcome', 'pid', 'root'])) fail('STOP_DAEMON_AT_RESULT_KEYS');
  if (typeof returned.root !== 'string' || canonicalExisting(returned.root, 'RETURNED_ROOT') !== repositoryRoot) fail('RETURNED_ROOT_MISMATCH');
  if (!Number.isSafeInteger(Number(returned.pid)) || Number(returned.pid) !== pid) fail('RETURNED_PID_MISMATCH');
  const allowedOutcomes = wasLive ? ['term', 'kill'] : ['not-running'];
  if (!allowedOutcomes.includes(returned.outcome)) fail(`RETURNED_OUTCOME_INVALID: ${String(returned.outcome)}`);
  if (wasLive) await waitForExit(pid);
  if (fs.existsSync(lockPath)) fail('DAEMON_LOCK_SURVIVED');
  process.stdout.write(`${JSON.stringify({ root: repositoryRoot, pid, outcome: returned.outcome })}\n`);
}

main().catch((error) => {
  if (!process.exitCode) {
    process.stderr.write(`${error && error.message ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
});
