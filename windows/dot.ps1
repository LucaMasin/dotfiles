param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

$ErrorActionPreference = 'Stop'
$command = if ($Arguments.Count) { $Arguments[0] } else { 'help' }
$options = @($Arguments | Select-Object -Skip 1)

function Show-Usage {
    Write-Host @'
Usage: dot <command> [options]

Windows commands:
  init       Install tools, Claude Code, and deploy Windows agent configuration.
  update     Pull this checkout and deploy Windows agent configuration.
  upgrade    Upgrade installed Scoop-managed tools from windows/tools.txt.
  help       Show this help.

Options:
  --dry-run     Preview changes without writing.
  --skip-tools  Do not install Scoop tools (init and update only).

Linux-specific dot commands are not supported on Windows.
'@
}

if ($command -in @('help', '--help', '-h')) { Show-Usage; exit 0 }
if ($command -notin @('init', 'update', 'upgrade')) {
    [Console]::Error.WriteLine("dot: '$command' is not supported on Windows. Run 'dot help'.")
    exit 1
}
if ($options.Count -eq 1 -and $options[0] -in @('--help', '-h')) { Show-Usage; exit 0 }
$setupOptions = @{}
if ($command -eq 'update') { $setupOptions.Update = $true }
foreach ($option in $options) {
    switch ($option) {
        '--dry-run' { $setupOptions.DryRun = $true }
        '--skip-tools' {
            if ($command -eq 'upgrade') { [Console]::Error.WriteLine('dot: --skip-tools is not valid for upgrade.'); exit 1 }
            $setupOptions.SkipTools = $true
        }
        default { [Console]::Error.WriteLine("dot: unknown option '$option'. Run 'dot help'."); exit 1 }
    }
}
if ($command -eq 'upgrade') {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine('dot: Scoop is not installed or not on PATH.')
        exit 1
    }
    $failed = $false
    foreach ($line in Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools.txt')) {
        if (-not $line.Trim() -or $line.TrimStart().StartsWith('#')) { continue }
        $app = $line.Split('|')[0]
        $null = & scoop prefix $app 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Host "skip: $app is not installed by Scoop"; continue }
        if ($setupOptions.DryRun) { Write-Host "dry-run: scoop update $app"; continue }
        Write-Host "scoop update $app"
        & scoop update $app
        if ($LASTEXITCODE -ne 0) { $failed = $true; Write-Warning "scoop update $app failed" }
    }
    if ($failed) { exit 1 }
    exit 0
}
try {
    & (Join-Path $PSScriptRoot 'setup.ps1') @setupOptions
} catch {
    [Console]::Error.WriteLine("dot: $($_.Exception.Message)")
    exit 1
}
