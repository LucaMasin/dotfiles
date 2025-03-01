#!/usr/bin/env bash

echo "Installing stow"

sudo apt install stow -y

cd $HOME/dotfiles
stow -t $HOME .