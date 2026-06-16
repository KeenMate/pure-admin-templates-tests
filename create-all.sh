#!/usr/bin/env bash
# Generate a series of pure-admin test apps with different configurations.
#
# Usage:
#   bash create-all.sh                               — run all (default server)
#   bash create-all.sh sk                            — only SvelteKit
#   bash create-all.sh spa                           — only Svelte SPA
#   bash create-all.sh phx                           — only Phoenix LiveView
#   bash create-all.sh api                           — only API-based tests
#   bash create-all.sh local                         — only local --template-path
#   bash create-all.sh --server http://localhost:8888 — use local API
#   bash create-all.sh all --server http://localhost:8888
#
# Mirror of create-all.ps1 — the two must stay in sync.
set -u

ONLY="all"
SERVER=""

# Parse args: supports positional category + --server URL in any order
while [ $# -gt 0 ]; do
  case "$1" in
    --server) SERVER="$2"; shift 2;;
    --server=*) SERVER="${1#--server=}"; shift;;
    all|sk|spa|phx|api|local) ONLY="$1"; shift;;
    -h|--help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: bash create-all.sh [all|sk|spa|phx|api|local] [--server URL]" >&2
      exit 1;;
  esac
done

CLI="/c/Git/KM/pure-admin-cli"
TPL_SK="/c/Git/KM/pure-admin-templates/svelte-sveltekit"
TPL_SPA="/c/Git/KM/pure-admin-templates/svelte-spa"
TPL_PHX="/c/Git/KM/pure-admin-templates/elixir-phoenix-liveview"
DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_ARGS=()
if [ -n "$SERVER" ]; then
  SERVER_ARGS=("--server" "$SERVER")
  echo "Using API server: $SERVER"
fi

PASS=0
FAIL=0
FAILED_TESTS=()

want() {
  # want <test-category>  — returns 0 if this test should run
  local cat="$1"
  case "$ONLY" in
    all) return 0;;
    "$cat") return 0;;
  esac
  # sk / spa / phx → any mode of that technology
  case "$ONLY:$cat" in
    sk:sk-api|sk:sk-local) return 0;;
    spa:spa-api|spa:spa-local) return 0;;
    phx:phx-local) return 0;;
    api:sk-api|api:spa-api) return 0;;
    local:sk-local|local:spa-local|local:phx-local) return 0;;
  esac
  return 1
}

create_app() {
  local cat="$1"; shift
  local name="$1"; shift
  if ! want "$cat"; then return 0; fi

  echo ""
  echo "--------------------------------------------------"
  echo "  [$cat] $name"
  echo "  Flags: $*"
  echo "--------------------------------------------------"

  rm -rf "$DIR/$name"
  cd "$DIR"
  npx --prefix "$CLI" pureadmin create "$name" --no-build ${SERVER_ARGS[@]+"${SERVER_ARGS[@]}"} "$@" 2>&1 || true

  # Success = app dir has either package.json (npm) or mix.exs (Elixir)
  if [ -f "$DIR/$name/package.json" ] || [ -f "$DIR/$name/mix.exs" ]; then
    echo "  [OK] $name"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name — no package.json or mix.exs"
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$name")
  fi
}

# ──────────────────────────────────────────────────────────────────
# Theme assignment — DELIBERATELY deterministic.
#
# Every SK / SPA app uses theme "corporate" so the per-app Playwright
# specs in tests/sveltekit/ can assert exact expectations (theme link,
# sidebar items, panel chrome). Each SK app varies along ONE dimension
# vs. the baseline (preset, panels, --template-path), making failures
# attributable to a single change.
#
# Phoenix apps below keep their own per-app themes — they're not yet
# covered by the spec matrix.
# ──────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────
# SvelteKit — API recipe (fetches from server)
# Uses default template "sveltekit" which has a bundled offline fallback
# so these tests work even when the API is unreachable.
# ──────────────────────────────────────────────────────────────────
create_app sk-api test-01-sk-defaults \
  --themes corporate --theme corporate

create_app sk-api test-02-sk-full \
  --themes corporate --theme corporate \
  --font-awesome --profile-panel --settings-panel

create_app sk-api test-03-sk-preset-full \
  --themes corporate --theme corporate \
  --company keenmate --preset full

create_app sk-api test-04-sk-preset-poc \
  --themes corporate --theme corporate \
  --company keenmate --preset poc

# ──────────────────────────────────────────────────────────────────
# SvelteKit — local --template-path (works offline)
# Mirrors of 01/02/03 above with --template-path; specs are shared
# (sk-defaults / sk-full / sk-preset-full each run twice via per-app
# Playwright projects in playwright.config.js).
# ──────────────────────────────────────────────────────────────────
create_app sk-local test-05-sk-tpl-defaults \
  --template svelte-sveltekit --template-path "$TPL_SK" \
  --themes corporate --theme corporate

create_app sk-local test-06-sk-tpl-full \
  --template svelte-sveltekit --template-path "$TPL_SK" \
  --themes corporate --theme corporate \
  --font-awesome --profile-panel --settings-panel

create_app sk-local test-07-sk-tpl-preset \
  --template svelte-sveltekit --template-path "$TPL_SK" \
  --themes corporate --theme corporate \
  --company keenmate --preset full

# ──────────────────────────────────────────────────────────────────
# Svelte SPA — API recipe
# Same deterministic matrix as SK: corporate theme everywhere, each app
# varies along ONE dimension (preset, panels, --template-path).
# ──────────────────────────────────────────────────────────────────
create_app spa-api test-08-spa-full \
  --template svelte-spa --themes corporate --theme corporate \
  --font-awesome --profile-panel --settings-panel

create_app spa-api test-09-spa-preset \
  --template svelte-spa --themes corporate --theme corporate \
  --company keenmate --preset full

# ──────────────────────────────────────────────────────────────────
# Svelte SPA — local --template-path
# Mirrors of 08/09 above plus a defaults-only baseline (test-10).
# ──────────────────────────────────────────────────────────────────
create_app spa-local test-10-spa-tpl-defaults \
  --template svelte-spa --template-path "$TPL_SPA" \
  --themes corporate --theme corporate

create_app spa-local test-11-spa-tpl-full \
  --template svelte-spa --template-path "$TPL_SPA" \
  --themes corporate --theme corporate \
  --font-awesome --profile-panel --settings-panel

create_app spa-local test-12-spa-tpl-preset \
  --template svelte-spa --template-path "$TPL_SPA" \
  --themes corporate --theme corporate \
  --company keenmate --preset full

# ──────────────────────────────────────────────────────────────────
# Phoenix LiveView — local --template-path only (not on API yet)
# Note: themes explicitly passed because the Phoenix template currently
# doesn't have defaultThemes in its manifest.
# ──────────────────────────────────────────────────────────────────
create_app phx-local test-13-phx-defaults \
  --template phoenix-liveview --template-path "$TPL_PHX" \
  --themes one-dark --theme one-dark

create_app phx-local test-14-phx-no-ecto \
  --template phoenix-liveview --template-path "$TPL_PHX" \
  --themes tokyo-night --theme tokyo-night --no-ecto

create_app phx-local test-15-phx-minimal \
  --template phoenix-liveview --template-path "$TPL_PHX" \
  --themes nato --theme nato \
  --no-ecto --no-mailer --no-dashboard

create_app phx-local test-16-phx-full-phx-flags \
  --template phoenix-liveview --template-path "$TPL_PHX" \
  --themes corporate --theme corporate \
  --no-mailer --no-dashboard

create_app phx-local test-17-phx-full \
  --template phoenix-liveview --template-path "$TPL_PHX" \
  --themes audi --theme audi \
  --font-awesome --profile-panel --settings-panel

# ──────────────────────────────────────────────────────────────────
# Flag validation — verify that unknown flags produce an error
# ──────────────────────────────────────────────────────────────────
if want "phx-local" || want "all"; then
  echo ""
  echo "--------------------------------------------------"
  echo "  [validation] test-18-phx-bad-flag (expect FAIL)"
  echo "--------------------------------------------------"
  rm -rf "$DIR/test-18-phx-bad-flag"
  cd "$DIR"
  output=$(npx --prefix "$CLI" pureadmin create test-18-phx-bad-flag --no-build \
    --template phoenix-liveview --template-path "$TPL_PHX" \
    --themes audi --theme audi --no-ectp \
    ${SERVER_ARGS[@]+"${SERVER_ARGS[@]}"} 2>&1 || true)

  if echo "$output" | grep -q "unknown flag"; then
    echo "  [OK] test-18-phx-bad-flag — correctly rejected --no-ectp"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] test-18-phx-bad-flag — should have shown 'unknown flag' error"
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("test-18-phx-bad-flag")
  fi
fi

echo ""
echo "=================================================="
echo "  Results: $PASS passed, $FAIL failed"
if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
  echo ""
  echo "  Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do echo "    - $t"; done
fi
echo "=================================================="
ls -d "$DIR"/test-* 2>/dev/null
