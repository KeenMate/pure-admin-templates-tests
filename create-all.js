#!/usr/bin/env node
// Generate the test app matrix declared in apps.json.
//
// Usage:
//   node create-all.js                              — all apps (default server)
//   node create-all.js sk                           — SvelteKit only
//   node create-all.js spa                          — Svelte SPA only
//   node create-all.js phx                          — Phoenix LiveView only
//   node create-all.js api                          — API recipe only (no --template-path)
//   node create-all.js local                        — --template-path only
//   node create-all.js --test 9                     — only test-09-*
//   node create-all.js --server http://localhost:8888
//   node create-all.js sk --server http://localhost:8888 --test 3
//
// Invoked from create-all.sh and create-all.ps1 (thin shims).

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync, execSync } = require('child_process');

const DIR = __dirname;
// Conventional sibling layout — same on every dev machine that follows the
// pure-admin-* repo convention. If the user moves things, override via env
// vars PUREADMIN_CLI / PUREADMIN_TEMPLATES.
const PARENT = path.resolve(DIR, '..');
const CLI    = process.env.PUREADMIN_CLI       || path.join(PARENT, 'pure-admin-cli');
const TPL_SK  = path.join(process.env.PUREADMIN_TEMPLATES || path.join(PARENT, 'pure-admin-templates'), 'svelte-sveltekit');
const TPL_SPA = path.join(process.env.PUREADMIN_TEMPLATES || path.join(PARENT, 'pure-admin-templates'), 'svelte-spa');
const TPL_PHX = path.join(process.env.PUREADMIN_TEMPLATES || path.join(PARENT, 'pure-admin-templates'), 'elixir-phoenix-liveview');

const PLACEHOLDERS = { TPL_SK, TPL_SPA, TPL_PHX };

// ── argv ────────────────────────────────────────────────────────────────────
function parseArgs(argv) {
  const out = { only: 'all', server: 'https://pureadmin.io', test: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--server' || a === '-Server') { out.server = argv[++i]; }
    else if (a.startsWith('--server=')) { out.server = a.slice('--server='.length); }
    else if (a === '--test' || a === '-Test') { out.test = String(argv[++i]).padStart(2, '0'); }
    else if (a.startsWith('--test=')) { out.test = a.slice('--test='.length).padStart(2, '0'); }
    else if (['all', 'sk', 'spa', 'phx', 'api', 'local'].includes(a)) { out.only = a; }
    else if (a === '-h' || a === '--help') { printHelp(); process.exit(0); }
    else { console.error(`Unknown argument: ${a}`); process.exit(1); }
  }
  return out;
}

function printHelp() {
  // Echo the doc-comment header so `--help` matches the actual usage above.
  const txt = fs.readFileSync(__filename, 'utf-8');
  const lines = txt.split(/\r?\n/);
  for (const ln of lines.slice(2)) {
    if (!ln.startsWith('//')) break;
    console.log(ln.replace(/^\/\/ ?/, ''));
  }
}

// ── filter ──────────────────────────────────────────────────────────────────
function shouldRun(app, only, testNum) {
  // -test N wins over category filter — exact NN prefix match.
  if (testNum) return app.name.startsWith(`test-${testNum}-`);
  if (only === 'all') return true;
  if (only === app.category) return true;
  switch (only) {
    case 'sk':    return app.category === 'sk-api' || app.category === 'sk-local';
    case 'spa':   return app.category === 'spa-api' || app.category === 'spa-local';
    case 'phx':   return app.category === 'phx-local';
    case 'api':   return app.category === 'sk-api' || app.category === 'spa-api';
    case 'local': return app.category.endsWith('-local');
  }
  return false;
}

// ── substitution ────────────────────────────────────────────────────────────
function resolveFlags(flags) {
  return flags.map(f =>
    f.replace(/\{\{(\w+)\}\}/g, (_, key) => PLACEHOLDERS[key] ?? `{{${key}}}`)
  );
}

// ── runners ─────────────────────────────────────────────────────────────────
function createApp(app, opts, results) {
  const flags = resolveFlags(app.flags);
  console.log('');
  console.log('-'.repeat(50));
  console.log(`  [${app.category}] ${app.name}`);
  console.log(`  Flags: ${flags.join(' ')}`);
  console.log('-'.repeat(50));

  // Validation cases (expectFailure) don't pre-delete — they want to assert
  // the CLI rejects before any directory is created.
  if (!app.expectFailure) {
    const appPath = path.join(DIR, app.name);
    if (fs.existsSync(appPath)) fs.rmSync(appPath, { recursive: true, force: true });
  }

  // Invoke pureadmin.js directly via node — bypasses the npx chain
  // (cmd → npx-cli → cmd → pureadmin) which buffers piped stdout badly on
  // Windows. Direct invocation is faster too (no npx package resolution).
  const cliEntry = path.join(CLI, 'bin', 'pureadmin.js');
  const args = [cliEntry, 'create', app.name, '--no-build',
                '--server', opts.server, ...flags];
  const t0 = Date.now();

  // For expectFailure cases we need to capture output. spawnSync with
  // stdio: 'pipe' deadlocks on Windows when the child produces a lot of
  // output (mix phx.new scaffold prints hundreds of lines before the
  // unknown-flag check runs). execSync uses an internal file-backed pipe
  // that handles large outputs cleanly.
  let proc, output = '';
  if (app.expectFailure) {
    const quoted = args.map(a => `"${a}"`).join(' ');
    const cmd = `"${process.execPath}" ${quoted}`;
    try {
      output = execSync(cmd, { cwd: DIR, encoding: 'utf-8', maxBuffer: 64 * 1024 * 1024 });
      proc = { status: 0 };
    } catch (e) {
      output = (e.stdout?.toString?.() || '') + (e.stderr?.toString?.() || '');
      proc = { status: e.status ?? 1 };
    }
  } else {
    proc = spawnSync(process.execPath, args, { cwd: DIR, stdio: 'inherit' });
  }
  const elapsed = ((Date.now() - t0) / 1000).toFixed(1);

  if (app.expectFailure) {
    const ok = output.includes(app.expectError);
    if (ok) {
      console.log(`  [OK] ${app.name} — correctly rejected (${elapsed}s)`);
      results.pass++;
    } else {
      console.log(`  [FAIL] ${app.name} — expected "${app.expectError}" in CLI output`);
      results.fail++;
      results.failed.push(app.name);
    }
    return;
  }

  // Normal apps: success = package.json (npm) OR mix.exs (Elixir) exists.
  const appPath = path.join(DIR, app.name);
  const ok = fs.existsSync(path.join(appPath, 'package.json'))
          || fs.existsSync(path.join(appPath, 'mix.exs'));
  if (ok) {
    console.log(`  [OK] ${app.name} (${elapsed}s)`);
    results.pass++;
  } else {
    console.log(`  [FAIL] ${app.name} — no package.json or mix.exs (${elapsed}s)`);
    results.fail++;
    results.failed.push(app.name);
  }
}

// ── main ────────────────────────────────────────────────────────────────────
function main() {
  const opts = parseArgs(process.argv.slice(2));

  // Sanity: refuse to start if the CLI / template paths don't exist. Cheap
  // check that catches the "moved repo" footgun before we waste minutes.
  for (const [label, p] of [['CLI', CLI], ['TPL_SK', TPL_SK], ['TPL_SPA', TPL_SPA], ['TPL_PHX', TPL_PHX]]) {
    if (!fs.existsSync(p)) {
      console.error(`  ${label} not found at ${p}`);
      console.error(`  Set PUREADMIN_CLI / PUREADMIN_TEMPLATES env vars to override.`);
      process.exit(1);
    }
  }

  const manifest = JSON.parse(fs.readFileSync(path.join(DIR, 'apps.json'), 'utf-8'));
  const apps = manifest.apps.filter(a => shouldRun(a, opts.only, opts.test));

  if (apps.length === 0) {
    console.error(`  No apps matched (category=${opts.only}${opts.test ? `, test=${opts.test}` : ''}).`);
    process.exit(1);
  }

  if (opts.server) console.log(`Using API server: ${opts.server}`);

  const results = { pass: 0, fail: 0, failed: [] };
  for (const app of apps) createApp(app, opts, results);

  console.log('');
  console.log('='.repeat(50));
  console.log(`  Results: ${results.pass} passed, ${results.fail} failed`);
  if (results.failed.length > 0) {
    console.log('');
    console.log('  Failed tests:');
    for (const n of results.failed) console.log(`    - ${n}`);
  }
  console.log('='.repeat(50));

  process.exit(results.fail === 0 ? 0 : 1);
}

main();
