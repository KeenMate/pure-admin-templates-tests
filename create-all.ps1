param(
    [ValidateSet("all", "sk", "spa", "phx", "api", "local")]
    [string]$Only = "all",
    [int]$Test = 0,
    [string]$Server = "https://pureadmin.io"
)

# Thin shim around create-all.js — the manifest (apps.json) and iteration
# logic live there. This script exists so the PowerShell-flavored invocation
# (`.\create-all.ps1 sk -Test 9`) keeps working.
#
# Usage:
#   .\create-all.ps1                                — all apps (default server)
#   .\create-all.ps1 sk                             — SvelteKit only
#   .\create-all.ps1 spa                            — Svelte SPA only
#   .\create-all.ps1 phx                            — Phoenix LiveView only
#   .\create-all.ps1 api                            — API recipe only
#   .\create-all.ps1 local                          — --template-path only
#   .\create-all.ps1 -Test 9                        — only test-09-*
#   .\create-all.ps1 -Server http://localhost:8888  — use local server

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$args = @($Only, '--server', $Server)
if ($Test -gt 0) { $args += @('--test', "$Test") }

& node "$PSScriptRoot\create-all.js" @args
exit $LASTEXITCODE
