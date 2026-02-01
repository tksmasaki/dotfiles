#!/bin/bash

# https://github.com/zsh-users/zsh-autosuggestions
mkdir -p ~/.zsh
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
# https://pixi.carapace.sh
mise use -g carapace@latest

ln -fs ~/dotfiles/.zshrc ~/.zshrc
source ~/.zshrc
