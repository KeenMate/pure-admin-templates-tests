param(
    [Parameter(Position=0)]
    [string]$Number = "01",
    [Parameter(Position=1)]
    [string]$Target = "dev"
)

# Run `make <target>` (default: dev) in a generated test app.
#
# Apps are named test-NN-xxxx — pass just the number and the script finds
# the matching folder. If multiple folders share a number (e.g. test-17-full
# and test-17-panels), all matches are listed and you'll need to disambiguate
# by renaming one or running make manually.
#
# Usage:
#   .\run.ps1                — make dev   in test-01-*
#   .\run.ps1 03             — make dev   in test-03-*
#   .\run.ps1 03 build       — make build in test-03-*
#   .\run.ps1 14 test        — make test  in test-14-*

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$num = $Number.PadLeft(2, '0')
$apps = @(Get-ChildItem $PSScriptRoot -Directory -Filter "test-$num-*")

if ($apps.Count -eq 0) {
    Write-Host "  No test app matching test-$num-*" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Available:" -ForegroundColor DarkGray
    Get-ChildItem $PSScriptRoot -Directory -Filter "test-*" |
        Sort-Object Name |
        ForEach-Object { Write-Host "    $($_.Name)" -ForegroundColor DarkGray }
    exit 1
}

if ($apps.Count -gt 1) {
    Write-Host "  Multiple test apps match test-$num-*:" -ForegroundColor Yellow
    foreach ($m in $apps) {
        Write-Host "    $($m.Name)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  Disambiguate by `cd`-ing into the right one and running ``make $Target`` directly." -ForegroundColor DarkGray
    exit 1
}

$app = $apps[0]
Write-Host "  → $($app.Name): make $Target" -ForegroundColor Cyan
Write-Host ""

Push-Location $app.FullName
try {
    & make $Target
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $code
