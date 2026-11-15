<#
.SYNOPSIS
Install or upgrade the Heimdall agent as a Windows service.

.DESCRIPTION
Clones or pulls LucaMasin/heimdall into <home>\repos\heimdall with gh (the repo
is private), then runs its scripts\install-windows.ps1, which builds the agent
and installs the heimdall-agent service. Installing the service asks for
administrator rights through UAC.

.PARAMETER DryRun
Print what would change. Nothing is cloned, built or installed.

.PARAMETER IfChanged
Skip the install, and the UAC prompt, when the installed version is current.

.PARAMETER HomeDir
Home directory that holds repos\heimdall. Defaults to %USERPROFILE%.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$IfChanged,
    [string]$HomeDir = $env:USERPROFILE
)

$ErrorActionPreference = 'Stop'
$HomeDir = [IO.Path]::GetFullPath($HomeDir).TrimEnd('\')
$Slug = 'LucaMasin/heimdall'
$Checkout = Join-Path $HomeDir 'repos\heimdall'

function Say([string]$Message) {
    if ($DryRun) { Write-Host "dry-run: $Message" } else { Write-Host $Message }
}

$realHome = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
if (-not $DryRun -and $HomeDir -ine $realHome) {
    Write-Warning 'skip: heimdall installs a machine-wide service, so it only runs against the real home'
    exit 0
}

foreach ($tool in @('git', 'go', 'gh')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Warning "skip: heimdall needs $tool on PATH"
        exit 0
    }
}

if (Test-Path -LiteralPath (Join-Path $Checkout '.git')) {
    Say "git -C $Checkout pull --ff-only"
    if (-not $DryRun) {
        git -C $Checkout pull --ff-only
        if ($LASTEXITCODE) { throw "git pull in $Checkout failed" }
    }
} else {
    if (-not $DryRun) {
        gh auth status *> $null
        if ($LASTEXITCODE) {
            Write-Warning 'skip: heimdall is a private repo. Run `gh auth login`, then rerun `dot init --heimdall`'
            exit 0
        }
    }
    Say "gh repo clone $Slug $Checkout"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Checkout) | Out-Null
        gh repo clone $Slug $Checkout
        if ($LASTEXITCODE) { throw "gh repo clone $Slug failed" }
    }
}

$installer = Join-Path $Checkout 'scripts\install-windows.ps1'
if (-not (Test-Path -LiteralPath $installer)) {
    if ($DryRun) { Say "powershell -File $installer"; exit 0 }
    throw "missing $installer"
}
$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer)
if ($DryRun) { $arguments += '-DryRun' }
if ($IfChanged) { $arguments += '-IfChanged' }
& powershell.exe @arguments
if ($LASTEXITCODE) { throw "install-windows.ps1 exited with $LASTEXITCODE" }
