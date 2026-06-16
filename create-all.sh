#!/usr/bin/env bash
# Thin shim around create-all.js — the manifest (apps.json) and iteration
# logic live there. This script exists so the bash-flavored invocation
# (`bash create-all.sh sk --server http://localhost:8888`) keeps working.
#
# Usage:
#   bash create-all.sh                   — all apps (default server)
#   bash create-all.sh sk                — SvelteKit only
#   bash create-all.sh spa               — Svelte SPA only
#   bash create-all.sh phx               — Phoenix LiveView only
#   bash create-all.sh api               — API recipe only
#   bash create-all.sh local             — --template-path only
#   bash create-all.sh --test 9          — only test-09-*
#   bash create-all.sh --server URL
#
# See node create-all.js --help for the full list.

DIR="$(cd "$(dirname "$0")" && pwd)"
exec node "$DIR/create-all.js" "$@"
