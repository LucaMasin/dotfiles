#!/usr/bin/env bash
set -euo pipefail

echo "Installing gh"
if ! command -v gh >/dev/null 2>&1; then
  type -p wget >/dev/null || { sudo apt update && sudo apt-get install wget -y; }
  sudo mkdir -p -m 755 /etc/apt/keyrings
  out="$(mktemp)"
  wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
  cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  rm -f "$out"
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt update
  sudo apt install gh -y
fi

gh auth login

echo "Clone dotfiles"
cd "$HOME"
if [[ ! -d $HOME/dotfiles ]]; then
  gh repo clone LucaMasin/dotfiles
fi

echo "Starting auto install"
cd "$HOME/dotfiles"

./setup_scripts/setup.sh --platform ubuntu
