<#
.SYNOPSIS
Deploy the agent skills and the tools they need on Windows (OpenCode Desktop, Codex).

.DESCRIPTION
1. Installs missing command-line tools from windows\tools.txt with Scoop.
2. Installs Claude Code when `claude` is missing.
3. Links every skill in .agents\skills into %USERPROFILE%\.agents\skills with a
   directory junction (no admin rights or Developer Mode needed).
4. Links the OpenCode slash commands into %USERPROFILE%\.config\opencode\commands.
5. Writes the Windows OpenCode config (windows\opencode.jsonc) with the native
   Claude Agent provider to %USERPROFILE%\.config\opencode\opencode.jsonc.
6. Writes a managed Windows note (windows\agent-notes.md) into the global
   AGENTS.md of Codex and OpenCode.

Existing targets are moved to %USERPROFILE%\.local\state\dotfiles-backup\<timestamp>
before they are replaced. Re-run after `git pull` to pick up new skills.

.PARAMETER DryRun
Print what would change without writing anything.

.PARAMETER SkipTools
Do not install tools with Scoop or install Claude Code.

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

function Install-ClaudeCode {
    $command = Get-Command claude -ErrorAction SilentlyContinue
    if ($command) {
        Write-Host "ok: claude is on PATH ($($command.Source))"
        return
    }
    $bin = Join-Path $HomeDir '.local\bin'
    if (Test-Path -LiteralPath (Join-Path $bin 'claude.exe')) {
        Write-Host "ok: found $(Join-Path $bin 'claude.exe')"
        if (($env:PATH -split ';') -notcontains $bin) { $env:PATH = "$env:PATH;$bin" }
        return
    }
    $realHome = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
    if ($HomeDir -ine $realHome) {
        Write-Warning 'Claude Code is missing; the official installer only targets the real home, so it is skipped with -HomeDir'
        return
    }
    Say 'install Claude Code with the official installer'
    if ($DryRun) { return }
    $installer = Join-Path ([IO.Path]::GetTempPath()) 'claude-install.ps1'
    Invoke-RestMethod 'https://claude.ai/install.ps1' -OutFile $installer
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
    if ($LASTEXITCODE) { throw "Claude Code installer exited with $LASTEXITCODE" }
    $bin = Join-Path $HomeDir '.local\bin'
    if (Test-Path -LiteralPath (Join-Path $bin 'claude.exe')) {
        if (($env:PATH -split ';') -notcontains $bin) { $env:PATH = "$env:PATH;$bin" }
    }
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        throw 'Claude Code was installed, but claude is not on PATH yet. Open a new terminal and rerun setup.'
    }
}

function Install-OpenCodeConfig {
    $source = Join-Path $PSScriptRoot 'opencode.jsonc'
    $target = Join-Path $HomeDir '.config\opencode\opencode.jsonc'
    $plain = Join-Path $HomeDir '.config\opencode\opencode.json'
    if (Test-Path -LiteralPath $plain) {
        Write-Warning "Found $plain; OpenCode may prefer it over the deployed opencode.jsonc"
    }
    $content = [IO.File]::ReadAllText($source)
    if (Test-Path -LiteralPath $target) {
        if ([IO.File]::ReadAllText($target) -ceq $content) {
            Write-Host "ok: $target is current"
            return
        }
        Backup-Path $target
    }
    Say "write OpenCode config to $target"
    if ($DryRun) { return }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    [IO.File]::WriteAllText($target, $content, (New-Object Text.UTF8Encoding($false)))
}

function Get-OpenCodeCli {
    $command = Get-Command opencode -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $desktop = Join-Path $env:LOCALAPPDATA 'Programs\@opencode-aidesktop\resources\opencode-cli.exe'
    if (Test-Path -LiteralPath $desktop) { return $desktop }
    return $null
}

function Test-ClaudeAgent {
    $realHome = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
    if ($HomeDir -ine $realHome) { return }
    $check = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $check) {
        Write-Warning 'Claude Code is not on PATH; the Claude agents will not work until it is installed and OpenCode is restarted.'
        return
    }
    try {
        $status = & $check.Source auth status 2>$null | ConvertFrom-Json
        if (-not $status.loggedIn) { Write-Warning 'Claude Code is not logged in. Run: claude auth login' }
    } catch {
        Write-Warning "Could not read Claude Code auth status: $($_.Exception.Message)"
    }
    $cli = Get-OpenCodeCli
    if (-not $cli) { return }
    $auth = & $cli auth list 2>$null | Out-String
    if ($auth -notmatch 'Claude Agent') {
        Write-Warning 'OpenCode has no Claude Agent connection. Connect Claude Agent in Settings > Providers, or run: opencode auth login claude-agent --standalone'
    }
}

function Install-DotCommand {
    $bin = Join-Path $HomeDir '.local\bin'
    $shim = Join-Path $bin 'dot.cmd'
    $launcher = Join-Path $bin 'dot-launch.ps1'
    $script = Join-Path $PSScriptRoot 'dot.ps1'
    $marker = '@rem Managed by dotfiles Windows setup'
    $launcherMarker = '# Managed by dotfiles Windows setup'
    $encodedPath = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))
    $launcherContent = "$launcherMarker`r`n`$script = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedPath'))`r`n& `$script @args`r`nexit `$LASTEXITCODE`r`n"
    $content = "@echo off`r`n$marker`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0dot-launch.ps1`" %*`r`nexit /b %errorlevel%`r`n"

    if (Test-Path -LiteralPath $shim) {
        $existing = [IO.File]::ReadAllText($shim)
        if (-not $existing.Contains($marker)) {
            Write-Warning "Not registering dot: $shim already exists and is not managed by dotfiles"
            return
        }
    }
    if ((Test-Path -LiteralPath $launcher) -and -not ([IO.File]::ReadAllText($launcher).Contains($launcherMarker))) {
        Write-Warning "Not registering dot: $launcher already exists and is not managed by dotfiles"
        return
    }
    foreach ($extension in @('.exe', '.com', '.bat', '.ps1')) {
        if (Test-Path -LiteralPath (Join-Path $bin "dot$extension")) {
            Write-Warning "Not registering dot: another dot command exists in $bin"
            return
        }
    }
    # Do not change the real user's PATH while testing against an alternate home.
    $realHome = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
    if ($HomeDir -ieq $realHome) {
        $found = Get-Command dot -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -ine $shim }
        if ($found) {
            Write-Warning "Not registering dot: another command is already available ($($found[0].Source))"
            return
        }
    }
    if ((Test-Path -LiteralPath $shim) -and $existing -ceq $content) {
        Write-Host "ok: $shim is current"
    } else {
        Say "write $shim"
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path $bin | Out-Null
            [IO.File]::WriteAllText($shim, $content, [Text.Encoding]::ASCII)
        }
    }
    if ((Test-Path -LiteralPath $launcher) -and [IO.File]::ReadAllText($launcher) -ceq $launcherContent) {
        Write-Host "ok: $launcher is current"
    } else {
        Say "write $launcher"
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path $bin | Out-Null
            [IO.File]::WriteAllText($launcher, $launcherContent, [Text.Encoding]::ASCII)
        }
    }
    if ($HomeDir -ine $realHome) { return }
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $paths = @($userPath -split ';' | Where-Object { $_ })
    $onPath = @($paths | Where-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') -ieq $bin.TrimEnd('\') }).Count -gt 0
    if (-not $onPath) {
        Say "add $bin to user PATH"
        if (-not $DryRun) {
            [Environment]::SetEnvironmentVariable('Path', (($paths + $bin) -join ';'), 'User')
        }
    }
}

function Install-StarshipConfig {
    $config = Join-Path $HomeDir '.config\starship.toml'
    $source = Join-Path $RepoRoot '.config\starship.toml'
    if (Test-Path -LiteralPath $config) {
        Write-Host "keep: existing Starship config $config"
    } else {
        Say "copy Starship config to $config"
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $config) | Out-Null
            Copy-Item -LiteralPath $source -Destination $config
        }
    }

    $realHome = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
    $documents = if ($HomeDir -ieq $realHome) {
        [Environment]::GetFolderPath('MyDocuments')
    } else { Join-Path $HomeDir 'Documents' }
    $begin = '# >>> dotfiles starship >>>'
    $end = '# <<< dotfiles starship <<<'
    $block = "$begin`r`nif (Get-Command starship -ErrorAction SilentlyContinue) { Invoke-Expression (&starship init powershell) }`r`n$end`r`n"
    foreach ($folder in @('WindowsPowerShell', 'PowerShell')) {
        $profilePath = Join-Path (Join-Path $documents $folder) 'profile.ps1'
        $existing = ''
        if (Test-Path -LiteralPath $profilePath) {
            $item = Get-Item -LiteralPath $profilePath -Force
            if (Test-Reparse $item) { Write-Warning "Skipping linked profile $profilePath"; continue }
            $existing = [IO.File]::ReadAllText($profilePath)
        }
        if ($existing.Contains($begin) -or $existing.Contains($end)) {
            if (-not ($existing.Contains($begin) -and $existing.Contains($end))) { throw "Unbalanced Starship markers in $profilePath" }
            Write-Host "ok: Starship block exists in $profilePath"
            continue
        }
        if ($existing -match '(?im)^\s*[^#\r\n]*\bstarship\s+init\s+powershell\b') {
            Write-Warning "Skipping ${profilePath}: Starship initialization already exists"
            continue
        }
        Say "add Starship initialization to $profilePath"
        if ($DryRun) { continue }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $profilePath) | Out-Null
        if (Test-Path -LiteralPath $profilePath) {
            # Append bytes without changing the profile's existing encoding or content.
            $bytes = [IO.File]::ReadAllBytes($profilePath)
            $encoding = if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) { [Text.Encoding]::Unicode }
                elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 254 -and $bytes[1] -eq 255) { [Text.Encoding]::BigEndianUnicode }
                else { [Text.Encoding]::UTF8 }
            $append = $encoding.GetBytes("`r`n$block")
            $stream = [IO.File]::Open($profilePath, [IO.FileMode]::Append, [IO.FileAccess]::Write)
            try { $stream.Write($append, 0, $append.Length) } finally { $stream.Dispose() }
        } else {
            [IO.File]::WriteAllText($profilePath, $block, (New-Object Text.UTF8Encoding($false)))
        }
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

if ($SkipTools) { Write-Host 'skip: tools' } else { Install-Tools; Install-ClaudeCode }

Install-DotCommand
Install-StarshipConfig
Install-OpenCodeConfig

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
Test-ClaudeAgent
$gitBash = 'C:\Program Files\Git\bin\bash.exe'
if (-not (Test-Path -LiteralPath $gitBash)) {
    Write-Warning "Git Bash not found at $gitBash; shell-script skills (show-me-your-work, poteto-mode) need it"
}

Write-Host ''
Write-Host 'Done. Open a new terminal for PATH changes, then restart OpenCode Desktop and Codex.'
Write-Host 'In Codex, run /skills to confirm the skills are visible.'
