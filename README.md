# Dotfiles

Personal Linux configs for zsh, Neovim, tmux, Herdr, and helper scripts.

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/LucaMasin/dotfiles/main/auto_install.sh | bash

# Or, from a manual clone
./dot init
```

Setup detects Ubuntu, Omarchy, or Raspberry Pi OS automatically. Raspberry Pi support requires a Pi 4 or Pi 5 with 64-bit Trixie. Restart your shell after setup to use `dot` globally.

## Everyday commands

```bash
dot update                 # Pull latest configs and apply them
dot apply                  # Apply local default configs
dot apply nvim tmux         # Apply selected configs
dot apply --dry-run         # Preview without changes
dot list                   # List available configs
dot doctor                 # Diagnose setup problems
dot edit                   # Open this repo in your editor
```

See [docs](docs/README.md) for setup options, command reference, backups, and troubleshooting. Package installation still uses the existing platform installers. Brew migration is optional and not implemented.
