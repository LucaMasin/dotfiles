#!/usr/bin/env bash

echo "Installing neovim"

sudo apt-get install ninja-build gettext cmake curl build-essential unzip -y

mkdir -p $HOME/repos
cd $HOME/repos

git clone https://github.com/neovim/neovim
cd neovim

make CMAKE_BUILD_TYPE=Release
sudo make install