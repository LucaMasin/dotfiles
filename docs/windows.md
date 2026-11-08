# Windows: agent skills and tools

A minimal Windows deployment for OpenCode Desktop and Codex. It installs the CLI tools the skills need plus Claude Code, links `.agents/skills` where both apps look, and deploys the Windows OpenCode config. It does not apply shell, editor, or terminal configs.

## Install

Clone into the Windows home (not through `\\wsl$`) and run the script from PowerShell:

```powershell
git clone -c core.longpaths=true https://github.com/LucaMasin/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles
powershell -ExecutionPolicy Bypass -File windows\setup.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File windows\setup.ps1
```

Open a new terminal afterwards so PATH changes apply, then restart OpenCode Desktop and Codex. In Codex, run `/skills` to confirm the skills are visible. After `git pull`, rerun the script to link new skills; `-Update` pulls first.

On the first run, sign in to Claude Code if the setup warns that it is missing or logged out:

```powershell
claude auth login
```

Then connect its OpenCode integration, either in OpenCode Desktop under Settings → Providers → **Claude Agent**, or from a terminal when the OpenCode CLI is on PATH:

```powershell
opencode auth login claude-agent --standalone
```

The setup also registers `dot` for PowerShell and Command Prompt. After opening a new terminal, use `dot init` to redeploy, `dot update` to pull and redeploy, or `dot upgrade` to update Scoop-managed tools listed in `windows/tools.txt`. Upgrade skips tools not installed with Scoop and does not update other Scoop apps or refresh buckets; run `scoop update` separately to refresh manifests. All three accept `--dry-run`; init and update also accept `--skip-tools`. `dot help` lists Windows commands. Linux-specific commands such as `dot apply` are not supported on Windows. Registration leaves an existing `dot` command or unmanaged shim alone and prints a warning instead. The shim points to this checkout; rerun setup if it moves.

| Option | Effect |
| --- | --- |
| `-DryRun` | Print changes without writing |
| `-SkipTools` | Do not install anything (Scoop tools, Claude Code) |
| `-Update` | `git pull --ff-only` before linking |
| `-ExcludeSkills a,b` | Skills to leave out (default `browser-control,diagnose-crash`) |
| `-HomeDir <path>` | Deploy into another home, for testing |

## What it does

- **Tools:** reads `windows/tools.txt` and runs `scoop install` for each app whose command is not already on PATH. Scoop installs per user and needs no admin prompt. Install Scoop from https://scoop.sh first; the script stops with a message if it is missing. Tools that exist from another installer (Git, GitHub CLI, uv) are left alone.
- **Claude Code:** runs Anthropic's official installer when `claude` is missing, which places `claude.exe` in `%USERPROFILE%\.local\bin`. The CLI updates itself. Login stays manual. This step is skipped by `-SkipTools` and by `-HomeDir` (the installer only targets the real home).
- **Skills:** makes `%USERPROFILE%\.agents\skills` a real folder and adds one directory junction per skill that points into the clone. Junctions need neither admin rights nor Developer Mode. Both OpenCode and Codex read this folder. Stale junctions for removed or excluded skills are deleted; real folders and skills installed by other tools are left alone, and a real folder with a colliding name is moved to the backup first.
- **Commands:** junctions `%USERPROFILE%\.config\opencode\commands` to the repo's OpenCode commands (the `/impeccable` wrapper).
- **OpenCode config:** writes `windows\opencode.jsonc` to `%USERPROFILE%\.config\opencode\opencode.jsonc`, backing up a different existing file first. The Windows config uses the native `claude-agent` provider; the Linux config in `.config\opencode\opencode.jsonc` keeps the plugin.
- **dot:** writes managed `dot.cmd` and `dot-launch.ps1` shims to `%USERPROFILE%\.local\bin`, and adds that directory to the user PATH if needed. With `-HomeDir`, shims are written there but the real user PATH is not changed.
- **Agent notes:** adds a marked block from `windows/agent-notes.md` to `%USERPROFILE%\.codex\AGENTS.md` and `%USERPROFILE%\.config\opencode\AGENTS.md`. It tells the agents how to run the Linux-style skill scripts on Windows. Your own text in those files is kept; the block is replaced on rerun.
- **Backups:** anything replaced goes to `%USERPROFILE%\.local\state\dotfiles-backup\<timestamp>\`.

## Not deployed

- `browser-control` and `diagnose-crash`. `browser-control` needs its CLI built from source (`bun link`) and a dedicated automation Chromium, neither of which this setup provides, and `diagnose-crash` is an Omarchy symlink.
- `~/.agents/pstack-models.md`. It names Linux-side model IDs. Run the `setup-pstack` skill on Windows to create one; the pstack skills fall back to defaults without it.

## Claude Code and models

Windows uses OpenCode's native Claude Agent provider, the same as Linux. Setup installs Claude Code when `claude` is missing, and `claude` updates itself afterwards.

One-time setup per machine:

1. `claude auth login` signs in with a Claude plan. Credentials stay under `%USERPROFILE%\.claude`; they are never copied into this repo.
2. Connect the integration in OpenCode Desktop under Settings → Providers → **Claude Agent**, or run `opencode auth login claude-agent --standalone` when the OpenCode CLI is on PATH.
3. Restart OpenCode Desktop after the first setup so the process inherits the updated PATH. A running app keeps the PATH it started with, and the Claude provider lists no models when it cannot find `claude.exe`.

`windows/opencode.jsonc` points the Claude agents at `claude-agent/sonnet#high` and `claude-agent/opus#medium`, the same aliases as the Linux config; they follow the latest Sonnet and Opus that the local `claude` offers. The model list is discovered from the local Claude Code CLI and depends on the Claude plan; check it with the model picker or `opencode models`.

The Sonnet alias has a 200,000-token context limit for automatic compaction. With the default 15% buffer, compaction starts around 170,000 tokens. It applies to every agent using `claude-agent/sonnet`, including `poteto` and `ui`; Opus and other model IDs are unchanged. The configured Sonnet alias may appear in the picker before connection, but still requires it to work.

## Starship in PowerShell

Windows setup installs Starship through Scoop if it is missing, and adds a guarded initialization block to the current user's all-hosts profiles for Windows PowerShell and PowerShell 7. Existing profile content is preserved, and an existing Starship initialization is left alone. It copies the repo's `.config\starship.toml` to `$HOME\.config\starship.toml` only if no config exists; subsequent edits and existing configs are left untouched. `-SkipTools` skips installing Starship but still sets up the profiles and config. Open a new PowerShell session to see the prompt; `STARSHIP_CONFIG`, if set, still takes precedence.

## Line endings

`.gitattributes` forces LF so shebang scripts keep working in a Windows checkout, and CRLF for `.cmd` and `.bat` files. Clone with the default `core.autocrlf`; the attributes win either way.

## Troubleshooting

- **Skill scripts:** shebangs and `/bin/sh` launchers do not run on Windows. The agent note lists the interpreter command for each (`node`, `bun`, `uv run python`, `impeccable.cmd`).
- **`bash` runs WSL:** `bash` on PATH is the WSL launcher. Shell-script skills need Git Bash at `C:\Program Files\Git\bin\bash.exe`; the setup warns if it is missing.
- **statechart:** installs Java and TLC through `mise` on first run and needs the network. This path has not been run on Windows.
- **Claude Agent shows no models:** the running OpenCode process cannot see `claude.exe`, usually because Claude Code was installed while the app was open. Restart OpenCode Desktop, then confirm `claude auth status` and `opencode auth list` (or Settings → Providers).
- **Skills missing in Codex:** run `/skills`. Some Codex builds have not discovered `~/.agents/skills`. If yours does not, add per-skill junctions under `%USERPROFILE%\.codex\skills`, but do not replace that folder because it holds Codex's built-in skills.
- **Execution policy:** use `-ExecutionPolicy Bypass` as shown, or `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
