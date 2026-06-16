# Changelog

## 2026-06-16

**Initial public layout.** The harness was working for weeks but lived as an
ad-hoc collection of scripts; today it's a coherent repo with a documented
matrix and a single source of truth.

- Wrote `README.md` describing the 18-app matrix (SK / SPA / Phoenix), the
  per-app Playwright projects, the shared `_lib` fixture + selectors, and
  the create/test/clean/run script flow.
- Added Phoenix LiveView coverage: `test.ps1` now has an `Invoke-PhoenixTest`
  branch (`mix deps.get` + `mix phx.server` via `cmd /c`, port 4000, kill by
  port owner). New specs `phx-no-ecto` (test-14) and `phx-minimal` (test-15)
  reuse the shared `_lib` helpers — Phoenix HEEx components emit the same
  `.pa-*` classes as the Svelte components, so no Phoenix-specific selectors.
  `phx` category in `test.ps1` runs both sequentially; with-DB apps (13/16/17)
  excluded by name.
- Replaced duplicated app definitions in `create-all.sh` + `create-all.ps1`
  with a single `apps.json` manifest. The icon-flag drift between the bash
  and PowerShell versions (test-13/14/15/16) had been silently misreporting
  what we were actually testing. `create-all.js` reads the manifest, resolves
  `{{TPL_SK}}` / `{{TPL_SPA}}` / `{{TPL_PHX}}` placeholders from the sibling
  repo layout, invokes `pureadmin.js` directly via node (skips the npx chain
  which buffers stdout badly on Windows), and uses `execSync` for the
  `expectFailure` validation case (test-18) so we can capture `mix phx.new`'s
  ~50s output without a pipe deadlock.
- Added `clean.ps1` — `output` (default), `apps`, `all` modes. Picks up
  per-app preview/phx logs from `$env:TEMP` too.
- Removed 15 stale test scaffolds (`test-bare-*`, `test-bundled-*`,
  `test-form-demo*`, `test-fresh-sk`, `test-14b-phx`, `test-17-phx-panels`,
  ...), the old e2e harness (`e2e/`, `e2e.{ps1,sh}`, `test01.{ps1,sh}`),
  four `demo-*` sandbox dirs, output dirs, and `martinova-aplikace`.
  `.gitignore` updated to exclude `playwright-report/` and `test-results/`,
  dead `.e2e-*.log` entries dropped.
- Dropped dead npm scripts from `package.json` (the `e2e*` entries pointed
  at deleted `e2e.sh`); kept `playwright:install`.
- Added `Makefile` with `create`, `test`, `clean`, `install`, and the `sk`
  / `spa` / `phx` shortcuts. Accepts `TEST=NN`, `ONLY=...`, `SERVER=...`.
