# Dotfiles

Personal Linux dotfiles for zsh, Neovim, tmux, and helper scripts. One setup flow with platform-specific handling underneath.

## Quick Start

```bash
# Bootstrap a new machine
curl -Ss https://raw.githubusercontent.com/LucaMasin/dotfiles/refs/heads/main/auto_install.sh | bash

# Or, after cloning manually
~/dotfiles/setup_scripts/setup.sh
```

Running `setup.sh` without flags auto-detects the platform. Override only when needed:

```bash
~/dotfiles/setup_scripts/setup.sh --platform omarchy
~/dotfiles/setup_scripts/setup.sh --platform ubuntu
~/dotfiles/setup_scripts/setup.sh --platform raspberrypi
```

## Repository Structure

```text
~/dotfiles/
├── auto_install.sh          # Bootstrap: install git, clone repo, run setup
├── setup_scripts/setup.sh   # Platform packages + config
├── setup_scripts/update.sh  # Pull repo, re-apply config
├── scripts/dotfiles.sh      # Config-only installer
├── dotfiles-manifest.conf   # Config package declarations
├── SETUP.md                 # Full setup reference
└── .config/nvim/            # Neovim configuration
```

## Usage

```bash
# Preview changes without touching the system
~/dotfiles/setup_scripts/setup.sh --dry-run

# Apply configs only, skip packages
~/dotfiles/setup_scripts/setup.sh --skip-packages

# Pull latest and re-apply configs
~/dotfiles/setup_scripts/update.sh

# Install selected configs only
~/dotfiles/scripts/dotfiles.sh --dry-run install zsh nvim tmux
~/dotfiles/scripts/dotfiles.sh install zsh nvim tmux
```

Default configs: `zsh nvim tmux herdr scripts agents opencode starship`.

## Supported Platforms

- **Omarchy** — via `omarchy pkg add`, Neovim built from source.
- **Ubuntu** — via apt + NodeSource + Snap, Neovim built from source. Optional i3 stack with `--desktop i3`.
- **Raspberry Pi OS** (64-bit Trixie, Pi 4/5) — via apt, Neovim built from source, Yazi from upstream `.deb`.

See `SETUP.md` for package lists and platform details.

## Optional: OpenCode Web

Tailnet-only HTTPS for the OpenCode web UI, opt-in per machine:

```bash
~/dotfiles/setup_scripts/opencode_web.sh enable
```

## More Details

See `SETUP.md` for the full reference (manifest format, backups, tmux, zsh, troubleshooting).
