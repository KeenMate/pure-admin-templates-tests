# pure-admin-test-apps

End-to-end test harness for [`@keenmate/pureadmin`](https://github.com/keenmate/pure-admin-cli) — the CLI that scaffolds Pure Admin apps from templates.

This repo generates a deterministic matrix of apps (SvelteKit, Svelte SPA, Phoenix LiveView) covering different flag combinations, then runs Playwright specs against each. Failures are attributable to a single dimension because every variant changes only one axis from a baseline.

## Layout

```
Makefile                # Convenience targets — make create / make test / make clean
apps.json               # Single source of truth — the matrix declared here
create-all.js           # Reads apps.json + runs the CLI (the actual logic)
create-all.{sh,ps1}     # Thin shims around create-all.js (kept for habit)
test.ps1                # Build + serve + Playwright for one app, a category, or all
run.ps1                 # `make <target>` (default: dev) in a single test app
clean.ps1               # Remove Playwright output and per-app temp logs

playwright.config.js    # One project per app — pinned baseURL + per-flavor testMatch
tests/
  _lib/                 # Shared fixture + selector helpers
    test.js             # Auto error collection (pageerror + console.error)
    selectors.js        # expectChrome, expectTheme, expectSidebarLink, expectPanelToggle, ...
  sveltekit/            # SK specs (sk-defaults, sk-full, sk-preset-full, sk-preset-poc)
  spa/                  # SPA specs (spa-defaults, spa-full, spa-preset-full)
  phoenix/              # Phoenix specs (phx-no-ecto, phx-minimal)

test-NN-*/              # Generated apps (gitignored; recreated on demand)
```

## The matrix

| #  | Tech       | Variant                     | Notes                                                |
|----|------------|-----------------------------|------------------------------------------------------|
| 01 | SvelteKit  | defaults                    | Baseline — no panels, no preset                      |
| 02 | SvelteKit  | full                        | --font-awesome --profile-panel --settings-panel      |
| 03 | SvelteKit  | preset full                 | Company keenmate + preset full                       |
| 04 | SvelteKit  | preset poc                  | Minimal preset (just dashboard)                      |
| 05 | SvelteKit  | tpl defaults                | Mirror of 01 via --template-path                     |
| 06 | SvelteKit  | tpl full                    | Mirror of 02 via --template-path                     |
| 07 | SvelteKit  | tpl preset                  | Mirror of 03 via --template-path                     |
| 08 | Svelte SPA | full                        | Hash routing baseline                                |
| 09 | Svelte SPA | preset full                 | SPA + preset (Products route from master-detail)     |
| 10 | Svelte SPA | tpl defaults                | Mirror of 08-ish via --template-path                 |
| 11 | Svelte SPA | tpl full                    | Same as 08 via --template-path                       |
| 12 | Svelte SPA | tpl preset                  | Same as 09 via --template-path                       |
| 13 | Phoenix    | defaults (with ecto)        | Needs Postgres                                       |
| 14 | Phoenix    | no-ecto                     | **Covered by phx specs**                             |
| 15 | Phoenix    | minimal (--no-mailer/dash)  | **Covered by phx specs**                             |
| 16 | Phoenix    | full-phx-flags (with ecto)  | Needs Postgres                                       |
| 17 | Phoenix    | full (with ecto)            | Needs Postgres                                       |
| 18 | Phoenix    | bad flag (validation)       | Asserts CLI rejects unknown flags                    |

Each SK/SPA app gets a unique port `4200 + NN`, so multi-app runs are collision-free. Phoenix apps share port 4000 (compile-time dev config) and run sequentially.

Every SK/SPA app uses the `corporate` theme so theme-CSS-link assertions are deterministic. Phoenix apps keep per-app themes for variety (one-dark, tokyo-night, nato, audi).

## Generate the apps

```powershell
.\create-all.ps1                    # everything
.\create-all.ps1 sk                 # SvelteKit only
.\create-all.ps1 spa                # Svelte SPA only
.\create-all.ps1 phx                # Phoenix only
.\create-all.ps1 -Test 9            # just test-09-*
.\create-all.ps1 -Server http://localhost:8888    # against a local pureadmin.io
```

Generation calls the **local CLI** at `C:\Git\KM\pure-admin-cli` (not the published npm package), so CLI changes are picked up immediately.

## Run the tests

```powershell
.\test.ps1                # test-01 (default)
.\test.ps1 09             # test-09 alone
.\test.ps1 all            # every SK + SPA app, sequentially
.\test.ps1 sk             # every SK app
.\test.ps1 spa            # every SPA app
.\test.ps1 phx            # test-14 + test-15 (no-DB Phoenix)
.\test.ps1 api            # SK + SPA, API recipe only
.\test.ps1 local          # SK + SPA, --template-path only
```

For each app, `test.ps1`:
1. **SK/SPA**: `pnpm run build` → `pnpm exec vite preview --strictPort` → wait for HTTP 200 → `npx playwright test --project=<name>` → kill server.
2. **Phoenix**: `cmd /c mix deps.get` → `cmd /c mix phx.server` → wait for HTTP 200 on 4000 → Playwright → kill by port owner.

Per-app Playwright projects pin a `baseURL` and a `testMatch`, so `--project=test-NN-...` is enough to run the right spec against the right server.

## Run a single app for dev

```powershell
.\run.ps1 14 dev          # make dev in test-14-* (Phoenix → mix phx.server)
.\run.ps1 03 build        # make build in test-03-* (Svelte → vite build)
```

## Clean up

```powershell
.\clean.ps1               # Playwright output (playwright-report/, test-results/) + temp logs
.\clean.ps1 apps          # wipe all generated test-NN-* dirs (regenerate via create-all)
.\clean.ps1 all           # both
```

Harness files (scripts, configs, `tests/`, `node_modules/`) are never touched.

## Adding a new app variant

1. Add an entry to `apps.json` — `name`, `category`, `flags` (use `{{TPL_SK}}` / `{{TPL_SPA}}` / `{{TPL_PHX}}` placeholders for `--template-path`).
2. Add a project to `playwright.config.js` — `baseURL: http://127.0.0.1:42NN/` (or 4000 for Phoenix), `testMatch: <flavor>/<spec-name>.spec.js`.
3. Drop the spec in `tests/<flavor>/`. Reuse `_lib/selectors.js` helpers — most assertions are one-liners.
4. Regenerate the app with `.\create-all.ps1 -Test NN` and run `.\test.ps1 NN`.

## Sibling repos

- `../pure-admin-cli` — the CLI being tested (`@keenmate/pureadmin`)
- `../pure-admin-templates` — template definitions fetched by the CLI
- `../pure-admin-themes` — theme packages downloaded into generated apps
- `../svelte-pure-admin` — Svelte component library used by SK + SPA chrome
