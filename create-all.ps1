param(
    [ValidateSet("all", "sk", "spa", "phx", "api", "local")]
    [string]$Only = "all",
    [int]$Test = 0,
    [string]$Server = "https://pureadmin.io"
)

# Generate a series of pure-admin test apps with different configurations.
#
# Usage:
#   .\create-all.ps1                                — run all (production server)
#   .\create-all.ps1 sk                             — SvelteKit only
#   .\create-all.ps1 spa                            — Svelte SPA only
#   .\create-all.ps1 phx                            — Phoenix LiveView only
#   .\create-all.ps1 api                            — API-based only
#   .\create-all.ps1 local                          — --template-path only
#   .\create-all.ps1 -Test 14                       — just test-14-* (overrides -Only)
#   .\create-all.ps1 -Server http://localhost:8888  — use local server
#
# Mirror of create-all.sh — the two must stay in sync.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$CLI     = "C:\Git\KM\pure-admin-cli"
$TPL_SK  = "C:\Git\KM\pure-admin-templates\svelte-sveltekit"
$TPL_SPA = "C:\Git\KM\pure-admin-templates\svelte-spa"
$TPL_PHX = "C:\Git\KM\pure-admin-templates\elixir-phoenix-liveview"
$DIR     = $PSScriptRoot

$script:PassCount = 0
$script:FailCount = 0
$script:FailedTests = @()
$script:RanApps = @()

function Should-Run {
    param([string]$Category, [string]$Name)
    # -Test filter wins over -Only when set. Matches "test-NN-..." prefix
    # (zero-padded), so -Test 14 picks test-14-phx-no-ecto and nothing else.
    if ($script:Test -gt 0) {
        $expected = "test-{0:00}-" -f $script:Test
        return $Name.StartsWith($expected)
    }
    switch ($script:Only) {
        "all"   { return $true }
        $Category { return $true }
        "sk"    { return $Category -in @("sk-api","sk-local") }
        "spa"   { return $Category -in @("spa-api","spa-local") }
        "phx"   { return $Category -in @("phx-local") }
        "api"   { return $Category -in @("sk-api","spa-api") }
        "local" { return $Category -in @("sk-local","spa-local","phx-local") }
    }
    return $false
}

function Create-App {
    param(
        [string]$Category,
        [string]$Name,
        [string[]]$Flags = @()
    )

    if (-not (Should-Run $Category $Name)) { return }
    $script:RanApps += $Name

    Write-Host ""
    Write-Host ("-" * 50) -ForegroundColor DarkGray
    Write-Host "  [$Category] $Name" -ForegroundColor Cyan
    if ($Flags.Count -gt 0) {
        Write-Host "  Flags: $($Flags -join ' ')" -ForegroundColor DarkGray
    }
    Write-Host ("-" * 50) -ForegroundColor DarkGray

    $appPath = Join-Path $DIR $Name
    if (Test-Path $appPath) { Remove-Item $appPath -Recurse -Force }

    Push-Location $DIR
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    & npx --prefix $CLI pureadmin create $Name --no-build --server $script:Server @Flags

    $sw.Stop()
    $elapsed = $sw.Elapsed.ToString("mm\:ss")

    $pkg = Join-Path $appPath "package.json"
    $mix = Join-Path $appPath "mix.exs"
    if ((Test-Path $pkg) -or (Test-Path $mix)) {
        Write-Host "  [OK] $Name ($elapsed)" -ForegroundColor Green
        $script:PassCount++
    } else {
        Write-Host "  [FAIL] $Name — no package.json or mix.exs ($elapsed)" -ForegroundColor Red
        $script:FailCount++
        $script:FailedTests += $Name
    }

    Pop-Location
}

$script:Only = $Only
$script:Test = $Test
$script:Server = $Server

# ────────────────────────────────────────────────────────────────
# Theme assignment — DELIBERATELY deterministic.
#
# Every SK / SPA app uses theme "corporate" so the per-app Playwright
# specs in tests/sveltekit/ can assert exact expectations. Each SK app
# varies along ONE dimension vs. the baseline (preset, panels,
# --template-path), making failures attributable to a single change.
#
# Phoenix apps keep their own per-app themes — they're not yet covered
# by the spec matrix.
# ────────────────────────────────────────────────────────────────

# ────────────────────────────────────────────────────────────────
# SvelteKit — API recipe (default template "sveltekit" has bundled fallback)
# ────────────────────────────────────────────────────────────────
Create-App sk-api "test-01-sk-defaults" `
    @("--themes","corporate","--theme","corporate")

Create-App sk-api "test-02-sk-full" `
    @("--themes","corporate","--theme","corporate",
      "--font-awesome","--profile-panel","--settings-panel")

Create-App sk-api "test-03-sk-preset-full" `
    @("--themes","corporate","--theme","corporate",
      "--company","keenmate","--preset","full")

Create-App sk-api "test-04-sk-preset-poc" `
    @("--themes","corporate","--theme","corporate",
      "--company","keenmate","--preset","poc")

# ────────────────────────────────────────────────────────────────
# SvelteKit — local --template-path
# Mirrors of 01/02/03 with --template-path; specs are shared via
# per-app Playwright projects in playwright.config.js.
# ────────────────────────────────────────────────────────────────
Create-App sk-local "test-05-sk-tpl-defaults" `
    @("--template","svelte-sveltekit","--template-path",$TPL_SK,
      "--themes","corporate","--theme","corporate")

Create-App sk-local "test-06-sk-tpl-full" `
    @("--template","svelte-sveltekit","--template-path",$TPL_SK,
      "--themes","corporate","--theme","corporate",
      "--font-awesome","--profile-panel","--settings-panel")

Create-App sk-local "test-07-sk-tpl-preset" `
    @("--template","svelte-sveltekit","--template-path",$TPL_SK,
      "--themes","corporate","--theme","corporate",
      "--company","keenmate","--preset","full")

# ────────────────────────────────────────────────────────────────
# Svelte SPA — API recipe (deterministic matrix, corporate theme)
# ────────────────────────────────────────────────────────────────
Create-App spa-api "test-08-spa-full" `
    @("--template","svelte-spa","--themes","corporate","--theme","corporate",
      "--font-awesome","--profile-panel","--settings-panel")

Create-App spa-api "test-09-spa-preset" `
    @("--template","svelte-spa","--themes","corporate","--theme","corporate",
      "--company","keenmate","--preset","full")

# ────────────────────────────────────────────────────────────────
# Svelte SPA — local --template-path
# Mirrors of 08/09 plus a defaults-only baseline (test-10).
# ────────────────────────────────────────────────────────────────
Create-App spa-local "test-10-spa-tpl-defaults" `
    @("--template","svelte-spa","--template-path",$TPL_SPA,
      "--themes","corporate","--theme","corporate")

Create-App spa-local "test-11-spa-tpl-full" `
    @("--template","svelte-spa","--template-path",$TPL_SPA,
      "--themes","corporate","--theme","corporate",
      "--font-awesome","--profile-panel","--settings-panel")

Create-App spa-local "test-12-spa-tpl-preset" `
    @("--template","svelte-spa","--template-path",$TPL_SPA,
      "--themes","corporate","--theme","corporate",
      "--company","keenmate","--preset","full")

# ────────────────────────────────────────────────────────────────
# Phoenix LiveView — local --template-path only (not on API yet)
# ────────────────────────────────────────────────────────────────
Create-App phx-local "test-13-phx-defaults" `
    @("--template","phoenix-liveview","--template-path",$TPL_PHX,
      "--themes","one-dark","--theme","one-dark","--font-awesome")

Create-App phx-local "test-14-phx-no-ecto" `
    @("--template","phoenix-liveview","--template-path",$TPL_PHX,
      "--themes","tokyo-night","--theme","tokyo-night","--no-ecto","--heroicons")

Create-App phx-local "test-15-phx-minimal" `
    @("--template","phoenix-liveview","--template-path",$TPL_PHX,
      "--themes","nato","--theme","nato","--heroicons",
      "--no-ecto","--no-mailer","--no-dashboard")

Create-App phx-local "test-16-phx-full-phx-flags" `
    @("--template","phoenix-liveview","--template-path",$TPL_PHX,
      "--themes","corporate","--theme","corporate","--font-awesome",
      "--no-mailer","--no-dashboard")

Create-App phx-local "test-17-phx-full" `
    @("--template","phoenix-liveview","--template-path",$TPL_PHX,
      "--themes","audi","--theme","audi",
      "--font-awesome","--profile-panel","--settings-panel")

# ────────────────────────────────────────────────────────────────
# Flag validation — verify that unknown flags produce an error
# ────────────────────────────────────────────────────────────────
if (Should-Run "phx-local" "test-18-phx-bad-flag") {
    $script:RanApps += "test-18-phx-bad-flag"
    Write-Host ""
    Write-Host ("-" * 50) -ForegroundColor DarkGray
    Write-Host "  [validation] test-18-phx-bad-flag (expect FAIL)" -ForegroundColor Cyan
    Write-Host ("-" * 50) -ForegroundColor DarkGray

    $badPath = Join-Path $DIR "test-18-phx-bad-flag"
    if (Test-Path $badPath) { Remove-Item $badPath -Recurse -Force }

    $output = & npx --prefix $CLI pureadmin create test-18-phx-bad-flag --no-build `
        --template phoenix-liveview --template-path $TPL_PHX `
        --themes audi --theme audi --no-ectp `
        --server $script:Server 2>&1 | Out-String

    if ($output -match "unknown flag") {
        Write-Host "  [OK] test-18-phx-bad-flag — correctly rejected --no-ectp" -ForegroundColor Green
        $script:PassCount++
    } else {
        Write-Host "  [FAIL] test-18-phx-bad-flag — should have shown 'unknown flag' error" -ForegroundColor Red
        $script:FailCount++
        $script:FailedTests += "test-18-phx-bad-flag"
    }
}

Write-Host ""
Write-Host ("=" * 50) -ForegroundColor DarkGray
Write-Host "  Results: $($script:PassCount) passed, $($script:FailCount) failed" -ForegroundColor $(if ($script:FailCount -eq 0) { "Green" } else { "Yellow" })
if ($script:FailedTests.Count -gt 0) {
    Write-Host ""
    Write-Host "  Failed tests:" -ForegroundColor Red
    foreach ($t in $script:FailedTests) {
        Write-Host "    - $t" -ForegroundColor Red
    }
}
Write-Host ("=" * 50) -ForegroundColor DarkGray
if ($script:RanApps.Count -gt 0) {
    Write-Host ""
    Write-Host "  Apps run this session:" -ForegroundColor DarkGray
    foreach ($a in $script:RanApps) {
        Write-Host "    $a" -ForegroundColor DarkGray
    }
}
