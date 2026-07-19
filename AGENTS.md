# AGENTS.md

Personal Linux dotfiles repo. There is no repo-wide build system, package manifest, CI, pre-commit config, or formal test suite; verify changes with focused syntax/sanity checks.

## High-Value Files

- `README.md` and `SETUP.md`: user-facing setup flow and supported platforms.
- `auto_install.sh`: bootstrap entrypoint for `curl | bash`; installs git, clones/updates `~/dotfiles`, then runs setup.
- `setup_scripts/setup.sh`: platform package install plus config application; supports `--platform ubuntu|omarchy|raspberrypi`, `--dry-run`, `--skip-packages`, `--desktop i3`, and `--configs <comma-list>|all`.
- `setup_scripts/update.sh`: pulls with `git pull --ff-only`, then reruns setup with `--skip-packages`; passes remaining args through to setup.
- `scripts/dotfiles.sh`: config-only installer driven by `dotfiles-manifest.conf`.
- `.config/nvim/init.lua`: Neovim entrypoint; bootstraps `lazy.nvim`, then loads `lua/vim-options.lua` and `lua/plugins/**`.

## Safe Commands

- Preview setup without changing the system: `setup_scripts/setup.sh --dry-run`.
- Preview config-only install: `scripts/dotfiles.sh --dry-run install zsh nvim tmux`.
- List manifest packages: `scripts/dotfiles.sh list`.
- Check shell syntax after editing scripts: `bash -n path/to/script.sh`.
- If available, lint shell scripts with `shellcheck path/to/script.sh`.
- Neovim sanity check after config edits: `nvim --headless "+qa"`.

## Do Not Run Without Explicit User Approval

- `auto_install.sh`, `setup_scripts/setup.sh` without `--dry-run`, or `setup_scripts/update.sh` without `--dry-run`; they can install packages, pull the repo, modify home-directory config, or run `sudo`.
- `scripts/dotfiles.sh install ...` without `--dry-run`; it creates symlinks, edits shell rc files, backs up targets, and installs tmux plugins.
- `setup_scripts/generate_github_ssh.sh`; it touches SSH/GitHub credentials.

## Config Installer Facts

- `dotfiles-manifest.conf` is the source of truth for installable config packages: `name|type|source|target|enabled|description`.
- Supported manifest types are `link` for symlinks and `source` for managed source blocks.
- Default setup applies `zsh nvim tmux scripts agents opencode`; `--configs all` installs enabled packages only.
- Existing targets are backed up under `${XDG_STATE_HOME:-~/.local/state}/dotfiles-backup/<timestamp>/` before replacement or source-block rewrite.
- Disabled desktop configs (`alacritty`, `i3`, `polybar`, `picom`, `rofi`, `zathura`) are documented in the manifest; enable there or use `--force-disabled` only intentionally.
- Ubuntu i3 setup is opt-in via `setup_scripts/setup.sh --platform ubuntu --desktop i3`, which force-installs the disabled legacy desktop configs.

## Platform Gotchas

- Platform detection is executable, not doc-only: Omarchy is detected by `command -v omarchy`; Ubuntu by `/etc/os-release` `ID=ubuntu`; Raspberry Pi by `/proc/device-tree/model` matching Pi 4 or Pi 5, `uname -m` equal to `aarch64`, and `/etc/os-release` codename `trixie`.
- Ubuntu setup installs apt packages, configures the GitHub CLI and NodeSource apt repos, builds Neovim from source in `~/repos/neovim`, installs Yazi via Snap, installs opencode2 via npm (switching to a user-owned `~/.npm-global` prefix if the default points outside `$HOME`, so the install does not need sudo), installs other user tools via curl/cargo/pipx, then applies configs.
- Raspberry Pi OS setup (64-bit Trixie only, Pi 4 or Pi 5) installs apt packages including `starship`, `zoxide`, `tokei`, and `fd-find`, configures the GitHub CLI and NodeSource apt repos, builds Neovim from source in `~/repos/neovim`, installs Yazi from the upstream `aarch64` `.deb` release asset through apt so dependencies resolve, installs opencode2 via npm (switching to a user-owned `~/.npm-global` prefix if the default points outside `$HOME`, so the install does not need sudo), and installs `uv` via the Astral installer script.
- Omarchy setup uses `omarchy pkg add` (including `nodejs`/`npm`), installs opencode2 via npm (switching to a user-owned `~/.npm-global` prefix if the default points outside `$HOME`, so the install does not need sudo), then may update `~/.config/uwsm/env`, write `~/.config/xdg-terminals.list`, edit `~/.config/hypr/looknfeel.conf`, and run `hyprctl reload`.
- Omarchy intentionally leaves legacy Alacritty/i3/polybar/rofi/picom configs disabled because Omarchy/Hyprland manages those defaults.

## Editing Conventions

- Keep diffs small and avoid mass-formatting personal config files.
- Keep `README.md`, `SETUP.md`, and `AGENTS.md` updated when setup flow, commands, platforms, or agent-relevant constraints change.
- For new bash scripts, match existing style: `#!/usr/bin/env bash`, `set -euo pipefail`, `snake_case` functions, quoted expansions, `[[ ... ]]` tests.
- For Neovim changes, keep plugin specs under `.config/nvim/lua/plugins/**`; respect `.config/nvim/lua/.luarc.json` (`vim` global).
- If adding a new config package, prefer one manifest line in `dotfiles-manifest.conf` over hard-coding installer logic.
