#!/usr/bin/env bash

echo "Installing shell essentials"

sudo apt install zsh fzf ripgrep git btop -y
curl -sS https://starship.rs/install.sh | sh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
