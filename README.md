# Dotfiles

Personal Linux dotfiles for shells, Neovim, tmux, scripts, agent skills, and optional desktop configs.

The setup is intentionally split into two layers:

```text
setup_scripts/setup.sh   platform setup: packages, tools, then config
scripts/dotfiles.sh      config only: links/sources entries from dotfiles-manifest.conf
```

## Supported Systems

- Omarchy: installs packages through `omarchy pkg add`, including Neovim.
- Ubuntu: installs package dependencies with apt, but builds Neovim from source because apt Neovim is usually outdated.
- Ubuntu i3: optional desktop stack, not installed by default.

## Quick Start

Clone the repository, then run the platform setup:

```bash
~/dotfiles/setup_scripts/setup.sh --platform omarchy
~/dotfiles/setup_scripts/setup.sh --platform ubuntu
```

If the platform can be detected, `--platform` can be omitted.

Preview first:

```bash
~/dotfiles/setup_scripts/setup.sh --platform ubuntu --dry-run
~/dotfiles/setup_scripts/setup.sh --platform omarchy --dry-run
```

Apply config only:

```bash
~/dotfiles/setup_scripts/setup.sh --platform ubuntu --skip-packages
~/dotfiles/setup_scripts/setup.sh --platform omarchy --skip-packages
```

## Ubuntu Bootstrap

For a fresh Ubuntu machine:

```bash
curl -Ss https://raw.githubusercontent.com/LucaMasin/dotfiles/refs/heads/main/auto_install.sh | bash
```

This installs GitHub CLI if needed, clones the repo, and runs:

```bash
~/dotfiles/setup_scripts/setup.sh --platform ubuntu
```

Ubuntu setup installs Neovim build dependencies, then clones or updates Neovim in `~/repos/neovim` and runs:

```bash
make -C ~/repos/neovim CMAKE_BUILD_TYPE=Release
sudo make -C ~/repos/neovim install
```

## Optional Ubuntu i3 Desktop

The i3 desktop stack is opt-in:

```bash
~/dotfiles/setup_scripts/setup.sh --platform ubuntu --desktop i3
```

This installs and applies configs for:

- i3
- polybar
- alacritty
- rofi
- picom

These config packages remain disabled by default in `dotfiles-manifest.conf` so they are not applied on Omarchy or config-only installs unless explicitly requested.

## Config Installer

Use the config installer directly when packages are already handled:

```bash
~/dotfiles/scripts/dotfiles.sh list
~/dotfiles/scripts/dotfiles.sh --dry-run install zsh nvim tmux
~/dotfiles/scripts/dotfiles.sh install zsh nvim tmux scripts agents
~/dotfiles/scripts/dotfiles.sh install all
```

Config packages are declared in `dotfiles-manifest.conf`:

```text
name|type|source|target|enabled|description
```

Supported types:

```text
link    symlink source to target, backing up an existing target first
source  insert a managed source block into an existing shell rc file
```

Backups go to:

```text
~/.local/state/dotfiles-backup/<timestamp>/
```

## Default Configs

The top-level setup applies these configs by default:

- `zsh`: sources `zsh_config` and `shell_config` from `~/.zshrc`.
- `nvim`: links `.config/nvim` to `~/.config/nvim`.
- `tmux`: links `.tmux.conf` and installs tmux plugins with TPM.
- `scripts`: links repo helper scripts to `~/scripts`.
- `agents`: links agent skills to `~/.agents`.

## Omarchy Notes

Omarchy setup also applies a few desktop-specific preferences:

- Configures Ghostty as the preferred `xdg-terminal-exec` terminal.
- Keeps Alacritty as a terminal fallback.
- Enables Hyprland scrolling layout when `~/.config/hypr/looknfeel.conf` exists.
- Sets UWSM shell to zsh when `~/.config/uwsm/env` exists.

Old desktop configs such as i3, polybar, rofi, picom, and alacritty are not applied by default on Omarchy.

## More Details

See `SETUP.md` for additional examples and manifest details.
