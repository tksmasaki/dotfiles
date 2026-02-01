#!/bin/bash

echo "Setting up zsh environment..."

chsh -s /bin/zsh
export SHELL="/bin/zsh"

# https://github.com/zsh-users/zsh-autosuggestions
mkdir -p ~/.zsh
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
# https://pixi.carapace.sh
mise use -g carapace@latest

echo "" >> ~/.zshrc
echo "# Load dotfiles configuration" >> ~/.zshrc
cat ~/dotfiles/.zshrc >> ~/.zshrc
source ~/.zshrc

echo "zsh environment setup complete."
