# Windows: agent skills and tools

A minimal Windows deployment for OpenCode Desktop and Codex. It installs the CLI tools the skills need and links `.agents/skills` where both apps look. It does not apply shell, editor, or terminal configs.

## Install

Clone into the Windows home (not through `\\wsl$`) and run the script from PowerShell:

```powershell
git clone -c core.longpaths=true https://github.com/LucaMasin/dotfiles.git $HOME\dotfiles
cd $HOME\dotfiles
powershell -ExecutionPolicy Bypass -File windows\setup.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File windows\setup.ps1
```

Open a new terminal afterwards so PATH changes apply, then restart OpenCode Desktop and Codex. In Codex, run `/skills` to confirm the skills are visible. After `git pull`, rerun the script to link new skills; `-Update` pulls first.

| Option | Effect |
| --- | --- |
| `-DryRun` | Print changes without writing |
| `-SkipTools` | Do not install anything with Scoop |
| `-Update` | `git pull --ff-only` before linking |
| `-ExcludeSkills a,b` | Skills to leave out (default `browser-control,diagnose-crash`) |
| `-HomeDir <path>` | Deploy into another home, for testing |

## What it does

- **Tools:** reads `windows/tools.txt` and runs `scoop install` for each app whose command is not already on PATH. Scoop installs per user and needs no admin prompt. Install Scoop from https://scoop.sh first; the script stops with a message if it is missing. Tools that exist from another installer (Git, GitHub CLI, uv) are left alone.
- **Skills:** makes `%USERPROFILE%\.agents\skills` a real folder and adds one directory junction per skill that points into the clone. Junctions need neither admin rights nor Developer Mode. Both OpenCode and Codex read this folder. Stale junctions for removed or excluded skills are deleted; real folders and skills installed by other tools are left alone, and a real folder with a colliding name is moved to the backup first.
- **Commands:** junctions `%USERPROFILE%\.config\opencode\commands` to the repo's OpenCode commands (the `/impeccable` wrapper).
- **Agent notes:** adds a marked block from `windows/agent-notes.md` to `%USERPROFILE%\.codex\AGENTS.md` and `%USERPROFILE%\.config\opencode\AGENTS.md`. It tells the agents how to run the Linux-style skill scripts on Windows. Your own text in those files is kept; the block is replaced on rerun.
- **Backups:** anything replaced goes to `%USERPROFILE%\.local\state\dotfiles-backup\<timestamp>\`.

## Not deployed

- `browser-control` and `diagnose-crash`. Browser control drives the WSL-local Chromium only, and `diagnose-crash` is an Omarchy symlink.
- `~/.agents/pstack-models.md`. It names Linux-side model IDs. Run the `setup-pstack` skill on Windows to create one; the pstack skills fall back to defaults without it.
- The OpenCode config (`opencode.jsonc`). It pins a Claude plugin and per-agent models for the Linux machines.

## Line endings

`.gitattributes` forces LF so shebang scripts keep working in a Windows checkout, and CRLF for `.cmd` and `.bat` files. Clone with the default `core.autocrlf`; the attributes win either way.

## Troubleshooting

- **Skill scripts:** shebangs and `/bin/sh` launchers do not run on Windows. The agent note lists the interpreter command for each (`node`, `bun`, `uv run python`, `impeccable.cmd`).
- **`bash` runs WSL:** `bash` on PATH is the WSL launcher. Shell-script skills need Git Bash at `C:\Program Files\Git\bin\bash.exe`; the setup warns if it is missing.
- **statechart:** installs Java and TLC through `mise` on first run and needs the network. This path has not been run on Windows.
- **Skills missing in Codex:** run `/skills`. Some Codex builds have not discovered `~/.agents/skills`. If yours does not, add per-skill junctions under `%USERPROFILE%\.codex\skills`, but do not replace that folder because it holds Codex's built-in skills.
- **Execution policy:** use `-ExecutionPolicy Bypass` as shown, or `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
