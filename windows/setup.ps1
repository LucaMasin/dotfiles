<#
.SYNOPSIS
Deploy the agent skills and the tools they need on Windows (OpenCode Desktop, Codex).

.DESCRIPTION
1. Installs missing command-line tools from windows\tools.txt with Scoop.
2. Links every skill in .agents\skills into %USERPROFILE%\.agents\skills with a
   directory junction (no admin rights or Developer Mode needed).
3. Links the OpenCode slash commands into %USERPROFILE%\.config\opencode\commands.
4. Writes a managed Windows note (windows\agent-notes.md) into the global
   AGENTS.md of Codex and OpenCode.

Existing targets are moved to %USERPROFILE%\.local\state\dotfiles-backup\<timestamp>
before they are replaced. Re-run after `git pull` to pick up new skills.

.PARAMETER DryRun
Print what would change without writing anything.

.PARAMETER SkipTools
Do not install tools with Scoop.

.PARAMETER Update
Run `git pull --ff-only` in this checkout first.

.PARAMETER ExcludeSkills
Skills that are not linked. Their junctions are removed if present.

.PARAMETER HomeDir
Home directory to deploy into. Defaults to %USERPROFILE%.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File windows\setup.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipTools,
    [switch]$Update,
    [string[]]$ExcludeSkills = @('browser-control', 'diagnose-crash'),
    [string]$HomeDir = $env:USERPROFILE
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# `powershell -File` passes "a,b" as one string, so split on commas too.
$ExcludeSkills = @($ExcludeSkills | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\')
$HomeDir = [IO.Path]::GetFullPath($HomeDir).TrimEnd('\')
$BeginMarker = '<!-- dotfiles:windows begin -->'
$EndMarker = '<!-- dotfiles:windows end -->'
$script:BackupDir = $null

function Say([string]$Message) {
    if ($DryRun) { Write-Host "dry-run: $Message" } else { Write-Host $Message }
}

function Test-Reparse($Item) {
    return (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Get-LinkTarget($Item) {
    $target = @($Item.Target)[0]
    if (-not $target) { return $null }
    $target = $target -replace '^\\\\\?\\', '' -replace '^\\\?\?\\', ''
    return $target.TrimEnd('\')
}

function Backup-Path([string]$Path) {
    if (-not $script:BackupDir) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $script:BackupDir = Join-Path $HomeDir ".local\state\dotfiles-backup\$stamp"
    }
    $name = $Path.Substring($HomeDir.Length).TrimStart('\') -replace '[\\/:]', '__'
    $destination = Join-Path $script:BackupDir $name
    Say "back up $Path -> $destination"
    if ($DryRun) { return }
    New-Item -ItemType Directory -Force -Path $script:BackupDir | Out-Null
    Move-Item -LiteralPath $Path -Destination $destination
}

# Returns $true when the link was missing or wrong (and was fixed, unless -DryRun).
function Set-Junction([string]$Link, [string]$Target) {
    $item = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    $isLink = $item -and (Test-Reparse $item)
    if ($isLink -and ((Get-LinkTarget $item) -ieq $Target)) { return $false }
    if ($item -and -not $isLink) { Backup-Path $Link }
    if ($DryRun) { return $true }
    if ($isLink) { [IO.Directory]::Delete($Link, $false) }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Link) | Out-Null
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    return $true
}

# Replaces a directory link with a real directory so per-skill links can live inside it.
function Ensure-RealDirectory([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and (Test-Reparse $item)) {
        Say "replace link $Path with a real directory"
        if ($DryRun) { return }
        [IO.Directory]::Delete($Path, $false)
        $item = $null
    }
    if ($item -and -not $item.PSIsContainer) { throw "$Path is a file, expected a directory" }
    if (-not $item -and -not $DryRun) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Update-ManagedBlock([string]$Path, [string]$Text) {
    $existing = ''
    if (Test-Path -LiteralPath $Path) { $existing = [IO.File]::ReadAllText($Path) }
    $block = $BeginMarker + "`n" + $Text.Trim() + "`n" + $EndMarker
    $hasBegin = $existing.Contains($BeginMarker)
    $hasEnd = $existing.Contains($EndMarker)
    if ($hasBegin -ne $hasEnd) { throw "Unbalanced dotfiles markers in $Path; fix or remove them" }
    if ($hasBegin) {
        $pattern = '(?s)' + [regex]::Escape($BeginMarker) + '.*?' + [regex]::Escape($EndMarker)
        $updated = [regex]::Replace($existing, $pattern, $block.Replace('$', '$$'))
    } else {
        $updated = $existing.TrimEnd()
        if ($updated) { $updated += "`n`n" }
        $updated += $block + "`n"
    }
    if ($updated -ceq $existing) { Write-Host "ok: $Path is current"; return }
    if ($existing.Trim()) { Backup-Path $Path }
    Say "write Windows note to $Path"
    if ($DryRun) { return }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [IO.File]::WriteAllText($Path, $updated, (New-Object Text.UTF8Encoding($false)))
}

function Install-Tools {
    $missing = @()
    foreach ($line in Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools.txt')) {
        if (-not $line.Trim() -or $line.TrimStart().StartsWith('#')) { continue }
        $app, $command = $line.Split('|')
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { $missing += $app }
    }
    if (-not $missing) { Write-Host 'ok: all tools are on PATH'; return }
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        if ($DryRun) { Write-Warning 'Scoop is not installed; install it from https://scoop.sh before a real run' }
        else { throw 'Scoop is not installed. Install it from https://scoop.sh, then rerun.' }
    }
    foreach ($app in $missing) {
        Say "scoop install $app"
        if ($DryRun) { continue }
        scoop install $app
        if ($LASTEXITCODE) { Write-Warning "scoop install $app exited with $LASTEXITCODE" }
    }
}

if ($Update) {
    Say "git -C $RepoRoot pull --ff-only"
    if (-not $DryRun) {
        git -C $RepoRoot pull --ff-only
        if ($LASTEXITCODE) { throw 'git pull failed' }
    }
}

Say "git -C $RepoRoot config core.longpaths true"
if (-not $DryRun) { git -C $RepoRoot config core.longpaths true }

if ($SkipTools) { Write-Host 'skip: tools' } else { Install-Tools }

# Skills: a real ~\.agents\skills holding one junction per skill.
$skillsSource = Join-Path $RepoRoot '.agents\skills'
$skillsTarget = Join-Path $HomeDir '.agents\skills'
Ensure-RealDirectory (Join-Path $HomeDir '.agents')
Ensure-RealDirectory $skillsTarget

$skills = @(Get-ChildItem -LiteralPath $skillsSource -Directory |
    Where-Object { (Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')) -and ($ExcludeSkills -notcontains $_.Name) })
$wanted = @($skills | ForEach-Object { $_.Name })

$linked = @()
foreach ($skill in $skills) {
    if (Set-Junction (Join-Path $skillsTarget $skill.Name) $skill.FullName) { $linked += $skill.Name }
}
Say ("skills: {0} linked or fixed, {1} already current" -f $linked.Count, ($skills.Count - $linked.Count))
if ($linked) { Say ("  changed: " + ($linked -join ', ')) }

# Remove junctions this repo created for skills that are gone or now excluded.
if (Test-Path -LiteralPath $skillsTarget) {
    foreach ($entry in Get-ChildItem -LiteralPath $skillsTarget -Force) {
        if (-not (Test-Reparse $entry) -or ($wanted -contains $entry.Name)) { continue }
        $target = Get-LinkTarget $entry
        if ($target -and $target.StartsWith($skillsSource, [StringComparison]::OrdinalIgnoreCase)) {
            Say "remove stale skill link $($entry.FullName)"
            if (-not $DryRun) { [IO.Directory]::Delete($entry.FullName, $false) }
        }
    }
}

# OpenCode slash commands.
$commandsSource = Join-Path $RepoRoot '.config\opencode\commands'
$commandsLink = Join-Path $HomeDir '.config\opencode\commands'
if (Set-Junction $commandsLink $commandsSource) {
    Say "linked $commandsLink -> $commandsSource"
} else {
    Write-Host "ok: $commandsLink is current"
}

# Managed Windows note for both agents.
$note = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'agent-notes.md'))
Update-ManagedBlock (Join-Path $HomeDir '.codex\AGENTS.md') $note
Update-ManagedBlock (Join-Path $HomeDir '.config\opencode\AGENTS.md') $note

# Checks that explain the most likely failures.
$gitBash = 'C:\Program Files\Git\bin\bash.exe'
if (-not (Test-Path -LiteralPath $gitBash)) {
    Write-Warning "Git Bash not found at $gitBash; shell-script skills (show-me-your-work, poteto-mode) need it"
}

Write-Host ''
Write-Host 'Done. Open a new terminal for PATH changes, then restart OpenCode Desktop and Codex.'
Write-Host 'In Codex, run /skills to confirm the skills are visible.'
