#!/usr/bin/env bash
set -euo pipefail

echo "Installing stow"

sudo apt install stow -y

cd "$HOME/dotfiles"
./scripts/omarchy-dotfiles.sh install all
