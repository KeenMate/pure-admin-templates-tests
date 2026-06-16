# pure-admin-test-apps — Makefile
#
# Thin wrapper around create-all.js, test.ps1, and clean.ps1. The Makefile is
# mainly for muscle memory (`make test`, `make clean`) and CI; the underlying
# scripts are the source of truth and can still be invoked directly.

.PHONY: help install create test clean clean-apps clean-all phx sk spa

# Filter to a single app number, e.g. `make test TEST=09` or `make create TEST=14`
TEST ?=
TEST_ARG_NODE = $(if $(TEST),--test $(TEST),)
TEST_ARG_PS   = $(if $(TEST),$(TEST),)

# Filter to a category (all / sk / spa / phx / api / local). Default: all.
ONLY ?= all

# Override the API server when generating apps.
SERVER ?=
SERVER_ARG = $(if $(SERVER),--server $(SERVER),)

# Pick the PowerShell binary. pwsh (PS 7+) handles UTF-8 correctly out of the
# box; powershell.exe (Windows PowerShell 5.1) chokes on the em-dashes in
# create-all.ps1. Override via `make test PWSH=powershell` if you must.
PWSH ?= pwsh

help:
	@echo "pure-admin-test-apps - Available targets:"
	@echo ""
	@echo "  make install              - npm install + playwright install chromium"
	@echo "  make create               - Generate the full test app matrix"
	@echo "  make create ONLY=sk       - Only SvelteKit apps (also: spa, phx, api, local)"
	@echo "  make create TEST=09       - Only test-09-*"
	@echo "  make create SERVER=http://localhost:8888"
	@echo "  make test                 - Run Playwright for every SK + SPA app"
	@echo "  make test ONLY=sk         - Only SK (also: spa, phx, api, local)"
	@echo "  make test TEST=09         - Only test-09-*"
	@echo "  make sk / spa / phx       - Shortcuts for 'make test ONLY=...'"
	@echo "  make clean                - Playwright output + per-app temp logs"
	@echo "  make clean-apps           - Wipe every generated test-NN-* dir"
	@echo "  make clean-all            - clean + clean-apps"
	@echo ""

install:
	npm install
	npx playwright install chromium

# Honor ONLY only when it isn't the default — keeps `make create` clean.
create:
	node create-all.js $(if $(filter-out all,$(ONLY)),$(ONLY),) $(TEST_ARG_NODE) $(SERVER_ARG)

# test.ps1 takes a positional Target (category or NN) and that's it.
# `make test TEST=09` → test.ps1 09; `make test ONLY=phx` → test.ps1 phx;
# bare `make test` → test.ps1 all.
test:
	$(PWSH) -NoProfile -ExecutionPolicy Bypass -File test.ps1 $(if $(TEST),$(TEST),$(if $(filter-out all,$(ONLY)),$(ONLY),all))

sk:
	$(PWSH) -NoProfile -ExecutionPolicy Bypass -File test.ps1 sk

spa:
	$(PWSH) -NoProfile -ExecutionPolicy Bypass -File test.ps1 spa

phx:
	$(PWSH) -NoProfile -ExecutionPolicy Bypass -File test.ps1 phx

clean:
	$(PWSH) -NoProfile -ExecutionPolicy Bypass -File clean.ps1 output

clean-apps:
	$(PWSH) -NoProfile -ExecutionPolicy Bypass -File clean.ps1 apps

clean-all:
	$(PWSH) -NoProfile -ExecutionPolicy Bypass -File clean.ps1 all
