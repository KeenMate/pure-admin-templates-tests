param(
    [Parameter(Position=0)]
    [string]$Target = "01",
    [Parameter(Position=1)]
    [int]$Port = 0
)

# Build + preview + Playwright smoke for one or many generated test apps.
#
# $Target can be:
#   - a number ("01", "03") or full name ("test-01") → run just that app
#   - a category — same set as create-all.{sh,ps1}:
#       all     — every SK + SPA app (Phoenix skipped — needs DB for some apps)
#       sk      — every SvelteKit app
#       spa     — every Svelte SPA app
#       api     — only API-recipe tests (no --template-path in create-all)
#       local   — only --template-path tests (the "tpl" ones)
#       phx     — Phoenix LiveView apps WITHOUT database (test-14 + test-15 only).
#                 With-DB apps (test-13/16/17) are excluded; run them by NN explicitly.
#
# Each app picks its own port: 4200 + NN (e.g. test-01 → 4201, test-12 → 4212).
# That keeps multi-app runs collision-free and lets you run several instances
# of this script in parallel terminals without overlap.
#
# Usage:
#   .\test.ps1                — test-01-*, port 4201
#   .\test.ps1 03             — test-03-*, port 4203
#   .\test.ps1 03 5000        — test-03-* on a custom port (single-app only)
#   .\test.ps1 all            — every SK + SPA app, sequentially
#   .\test.ps1 sk             — every SK app
#   .\test.ps1 spa            — every SPA app
#   .\test.ps1 api            — sk-api + spa-api (no tpl)
#   .\test.ps1 local          — sk-tpl + spa-tpl

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

# ── Resolve $Target → list of app DirectoryInfo ────────────────────────────
# Filter matches only test-NN-* directories — Playwright's `test-results/`
# also starts with "test-" and would otherwise be treated as an app.
$allApps = @(Get-ChildItem $PSScriptRoot -Directory -Filter 'test-*' |
    Where-Object { $_.Name -match '^test-\d{2}-' } |
    Sort-Object Name)
$selectedApps = @()
$mode = 'single'

# Single-app: bare number ("01") or full name prefix ("test-01")
$num = $null
if ($Target -match '^(\d+)$')          { $num = $matches[1].PadLeft(2, '0') }
elseif ($Target -match '^test-(\d+)')  { $num = $matches[1].PadLeft(2, '0') }

if ($num) {
    $selectedApps = @($allApps | Where-Object { $_.Name -match "^test-$num-" })
    if ($selectedApps.Count -eq 0) {
        Write-Host "  No test app matching test-$num-*" -ForegroundColor Red
        Write-Host ''
        Write-Host '  Available:' -ForegroundColor DarkGray
        $allApps | ForEach-Object { Write-Host "    $($_.Name)" -ForegroundColor DarkGray }
        exit 1
    }
    if ($selectedApps.Count -gt 1) {
        Write-Host "  Multiple test apps match test-$num-*:" -ForegroundColor Yellow
        foreach ($m in $selectedApps) { Write-Host "    $($m.Name)" -ForegroundColor Yellow }
        Write-Host '  Disambiguate by renaming one.' -ForegroundColor DarkGray
        exit 1
    }
} else {
    # Category-based selection. Naming conventions mirror create-all.{sh,ps1}:
    #   test-NN-sk-...        — sk-api  (no "tpl")
    #   test-NN-sk-tpl-...    — sk-local
    #   test-NN-spa-...       — spa-api
    #   test-NN-spa-tpl-...   — spa-local
    #   test-NN-phx-...       — phx-local
    $mode = 'multi'
    switch ($Target) {
        'all'   { $selectedApps = @($allApps | Where-Object { $_.Name -notmatch '^test-\d+-phx-' }) }
        'sk'    { $selectedApps = @($allApps | Where-Object { $_.Name -match    '^test-\d+-sk-' }) }
        'spa'   { $selectedApps = @($allApps | Where-Object { $_.Name -match    '^test-\d+-spa-' }) }
        'api'   { $selectedApps = @($allApps | Where-Object { $_.Name -match    '^test-\d+-(sk|spa)-(?!tpl-)' }) }
        'local' { $selectedApps = @($allApps | Where-Object { $_.Name -match    '^test-\d+-(sk|spa)-tpl-' }) }
        'phx'   {
            # Only no-DB Phoenix apps. With-DB apps (13/16/17) require a running
            # Postgres + ecto.create; run them by NN if you've set that up.
            $selectedApps = @($allApps | Where-Object { $_.Name -match '^test-(14|15|21)-phx-' })
        }
        default {
            Write-Host "  Unknown target '$Target'. Expected: NN | test-NN | all | sk | spa | api | local | phx" -ForegroundColor Red
            exit 1
        }
    }
    if ($selectedApps.Count -eq 0) {
        Write-Host "  No apps matched category '$Target'." -ForegroundColor Red
        exit 1
    }
}

# ── Phoenix runner ─────────────────────────────────────────────────────────
# Phoenix has a different lifecycle than the Vite preview used by SK/SPA:
#   - mix phx.server is the dev server (no separate build step — Phoenix
#     compiles + serves in one); first start may take 30-60s on cold cache
#   - all apps bind to port 4000 (config/dev.exs is compile-time, so
#     overriding per-app would mean patching each app's dev.exs); runs are
#     sequential so a fixed port is fine
#   - mix.bat → cmd → erl process tree on Windows is awkward to kill by
#     parent PID; we look up the LISTENING owner and taskkill that instead
function Invoke-PhoenixTest {
    param([System.IO.DirectoryInfo]$App)

    $appPath = $App.FullName
    $name    = $App.Name
    $port    = 4000
    $url     = "http://127.0.0.1:$port/"

    Write-Host ''
    Write-Host '================================================================' -ForegroundColor Cyan
    Write-Host " $name  →  $url  [phoenix]" -ForegroundColor Cyan
    Write-Host '================================================================' -ForegroundColor Cyan

    # Refuse to start if 4000 is already busy — otherwise the request would
    # be served by whoever's already there (we hit this exact trap during
    # development; HTTP 200 came from a leftover server, not the one we
    # just started).
    $busy = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($busy) {
        Write-Host "  Port $port already in use (PID $($busy[0].OwningProcess)). Free it and retry." -ForegroundColor Red
        return 'preview-failed'
    }

    Write-Host '> mix deps.get'
    Push-Location $appPath
    # mix is a .bat — invoke via cmd /c so PowerShell finds it via PATHEXT.
    try { & cmd.exe /c mix deps.get | Out-Host } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { return 'build-failed' }

    Write-Host '> phx.server'
    $logBase = Join-Path $env:TEMP "$name-phx"
    # Start-Process can't invoke mix directly (it's a .bat, not a .exe), so
    # we dispatch via cmd.exe. $proc.Id is the cmd shell — the actual erl VM
    # is its grandchild. /T flag plus port-based fallback handle the
    # tree-kill problem.
    $proc = Start-Process -FilePath 'cmd.exe' `
        -ArgumentList @('/c', 'mix', 'phx.server') `
        -WorkingDirectory $appPath `
        -RedirectStandardOutput "$logBase.out.log" `
        -RedirectStandardError "$logBase.err.log" `
        -NoNewWindow -PassThru

    try {
        Write-Host '> waiting for server'
        $ready = $false
        # 60s budget — first compile after deps.get can take a while.
        for ($i = 0; $i -lt 60; $i++) {
            try {
                $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                if ($r.StatusCode -eq 200) { $ready = $true; break }
            } catch { }
            Start-Sleep -Seconds 1
        }
        if (-not $ready) {
            Write-Host "  Server didn't come up. See $logBase.out.log / .err.log" -ForegroundColor Red
            return 'preview-failed'
        }

        Write-Host '> playwright'
        Push-Location $PSScriptRoot
        try { npx playwright test --project=$name | Out-Host } finally { Pop-Location }
        if ($LASTEXITCODE -eq 0) {
            Write-Host '> OK' -ForegroundColor Green
            return 'ok'
        } else {
            Write-Host '> FAILED' -ForegroundColor Red
            return 'browser-failed'
        }
    }
    finally {
        # Kill by port owner — the erl VM holds 4000 and is what matters.
        $listening = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        foreach ($conn in $listening) {
            taskkill /F /PID $conn.OwningProcess 2>$null | Out-Null
        }
        if ($proc -and $proc.Id) {
            taskkill /F /T /PID $proc.Id 2>$null | Out-Null
        }
    }
}

# ── Per-app runner ─────────────────────────────────────────────────────────
function Invoke-Test {
    param([System.IO.DirectoryInfo]$App, [int]$OverridePort)

    $appPath = $App.FullName
    $name    = $App.Name

    if (Test-Path (Join-Path $appPath 'mix.exs')) {
        return (Invoke-PhoenixTest -App $App)
    }

    # Derive port from the NN in the app name unless caller overrode it.
    $port = $OverridePort
    if ($port -eq 0) {
        if ($name -match '^test-(\d+)') {
            $port = 4200 + [int]$matches[1]
        } else {
            $port = 4200
        }
    }
    $url = "http://127.0.0.1:$port/"

    Write-Host ''
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host " $name  →  $url" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan

    $proc = $null
    try {
        Write-Host '> build'
        Push-Location $appPath
        # Pipe to Out-Host so build output prints to the console but doesn't
        # bleed into this function's return value (PowerShell captures any
        # uncaptured pipeline output as the function result).
        try { pnpm run build | Out-Host } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) {
            Write-Host '  build FAILED' -ForegroundColor Red
            return 'build-failed'
        }

        Write-Host "> preview"
        $logBase = Join-Path $env:TEMP "$name-preview"
        # pnpm exec runs the vite binary directly — bypasses npm-script wrapping
        # and the `--` passthrough that Start-Process's argv handling mangles
        # on Windows. --strictPort makes Vite fail loudly if the port is busy.
        $proc = Start-Process -FilePath 'pnpm' `
            -ArgumentList @('exec', 'vite', 'preview', '--host', '127.0.0.1', '--port', $port, '--strictPort') `
            -WorkingDirectory $appPath `
            -RedirectStandardOutput "$logBase.out.log" `
            -RedirectStandardError "$logBase.err.log" `
            -NoNewWindow -PassThru

        Write-Host '> waiting for server'
        $ready = $false
        for ($i = 0; $i -lt 30; $i++) {
            try {
                $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                if ($r.StatusCode -eq 200) { $ready = $true; break }
            } catch { }
            Start-Sleep -Seconds 1
        }
        if (-not $ready) {
            Write-Host "  Server didn't come up. See $logBase.out.log / .err.log" -ForegroundColor Red
            return 'preview-failed'
        }

        Write-Host '> playwright'
        # Per-app Playwright project — see playwright.config.js. Each project
        # has its own baseURL (matching $url) and testMatch pointing at the
        # matrix-row spec for this app's flavor. Out-Host keeps output visible
        # without polluting this function's return value.
        Push-Location $PSScriptRoot
        try { npx playwright test --project=$name | Out-Host } finally { Pop-Location }
        if ($LASTEXITCODE -eq 0) {
            Write-Host '> OK' -ForegroundColor Green
            return 'ok'
        } else {
            Write-Host '> FAILED' -ForegroundColor Red
            return 'browser-failed'
        }
    }
    finally {
        if ($proc) {
            taskkill /F /T /PID $proc.Id 2>$null | Out-Null
        }
    }
}

# ── Main loop ──────────────────────────────────────────────────────────────
if ($mode -eq 'single') {
    $result = Invoke-Test -App $selectedApps[0] -OverridePort $Port
    if ($result -eq 'ok') { exit 0 } else { exit 1 }
}

# Multi-app mode: sequential, record results, summary at end.
# $Port is ignored — each app uses its derived port.
$results = New-Object System.Collections.ArrayList
foreach ($app in $selectedApps) {
    $r = Invoke-Test -App $app -OverridePort 0
    [void]$results.Add([pscustomobject]@{ Name = $app.Name; Result = $r })
}

# ── Summary ────────────────────────────────────────────────────────────────
$passed   = @($results | Where-Object { $_.Result -eq 'ok' })
$failed   = @($results | Where-Object { $_.Result -notin @('ok', 'skipped') })
$skipped  = @($results | Where-Object { $_.Result -eq 'skipped' })

Write-Host ''
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host '  Summary' -ForegroundColor Cyan
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host "  Passed:  $($passed.Count)" -ForegroundColor Green
Write-Host "  Failed:  $($failed.Count)" -ForegroundColor $(if ($failed.Count) {'Red'} else {'DarkGray'})
Write-Host "  Skipped: $($skipped.Count)" -ForegroundColor DarkGray

if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host '  Failures:' -ForegroundColor Red
    foreach ($f in $failed) { Write-Host "    - $($f.Name) ($($f.Result))" -ForegroundColor Red }
    exit 1
}

exit 0
