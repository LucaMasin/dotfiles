#!/usr/bin/env bash

echo "Installing shell essentials"

touch $HOME/.zshrc

sudo apt install zsh fzf ripgrep git btop net-tools pipx -y
curl -sS https://starship.rs/install.sh | sh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

# Install rust and yazi
curl --proto '=https' --tlsv1.3 https://sh.rustup.rs -sSf | sh
. "$HOME/.cargo/env"

cargo install --locked yazi-fm yazi-cli
cargo install tokei

# install development tools
echo "Installing uv"
curl -LsSf https://astral.sh/uv/install.sh | sh
echo 'eval "$(uv generate-shell-completion zsh)"' >> ~/.zshrc
echo 'eval "$(uvx --generate-shell-completion zsh)"' >> ~/.zshrc

echo 'eval "$(uv generate-shell-completion bash)"' >> ~/.bashrc
echo 'eval "$(uvx --generate-shell-completion bash)"' >> ~/.bashrc

echo "Installing poetry"
pipx install poetry
