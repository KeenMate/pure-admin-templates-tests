param(
    [ValidateSet("output", "apps", "all")]
    [Parameter(Position=0)]
    [string]$Target = "output"
)

# Remove temporary artifacts from this directory.
#
# Targets:
#   output (default) — Playwright output (playwright-report/, test-results/)
#                      and the per-app preview/phx logs written under $env:TEMP.
#   apps             — every generated test-NN-* app folder. Regenerate with
#                      create-all.{sh,ps1}.
#   all              — output + apps.
#
# Usage:
#   .\clean.ps1              — output only (safe; regenerated on next run)
#   .\clean.ps1 apps         — wipe all generated test apps
#   .\clean.ps1 all          — both
#
# Harness files (test.ps1, create-all.*, playwright.config.js, package*.json,
# node_modules/, tests/, run.ps1) are NEVER touched.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$removed = New-Object System.Collections.ArrayList

function Remove-IfExists {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $Path)) {
            Write-Host "  - $Label" -ForegroundColor DarkGray
            [void]$removed.Add($Label)
        } else {
            Write-Host "  ! $Label (in use, skipped)" -ForegroundColor Yellow
        }
    }
}

# ── output ──────────────────────────────────────────────────────────────────
if ($Target -in @('output', 'all')) {
    Write-Host "Cleaning Playwright output..." -ForegroundColor Cyan
    Remove-IfExists (Join-Path $PSScriptRoot 'playwright-report') 'playwright-report/'
    Remove-IfExists (Join-Path $PSScriptRoot 'test-results')      'test-results/'

    Write-Host "Cleaning per-app preview logs from `$env:TEMP..." -ForegroundColor Cyan
    # test.ps1 writes <name>-preview.out.log / .err.log (Vite) and
    # <name>-phx.out.log / .err.log (Phoenix). Match both shapes.
    Get-ChildItem $env:TEMP -File -Filter 'test-*-preview.*.log' -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-IfExists $_.FullName $_.Name }
    Get-ChildItem $env:TEMP -File -Filter 'test-*-phx.*.log' -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-IfExists $_.FullName $_.Name }
}

# ── apps ────────────────────────────────────────────────────────────────────
if ($Target -in @('apps', 'all')) {
    Write-Host "Cleaning generated test apps..." -ForegroundColor Cyan
    # Match test-NN-* (zero-padded). Anchors on "test-<digit><digit>-" so we
    # don't accidentally hit test.ps1 / tests/ (file vs. directory filter
    # already protects, but the regex is defense in depth).
    Get-ChildItem $PSScriptRoot -Directory |
        Where-Object { $_.Name -match '^test-\d{2}-' } |
        ForEach-Object { Remove-IfExists $_.FullName "$($_.Name)/" }
}

# ── summary ─────────────────────────────────────────────────────────────────
Write-Host ''
if ($removed.Count -eq 0) {
    Write-Host "  Nothing to clean." -ForegroundColor DarkGray
} else {
    Write-Host "  Removed $($removed.Count) item(s)." -ForegroundColor Green
}
