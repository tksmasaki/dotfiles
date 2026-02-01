#!/bin/bash

echo "Setting up zsh environment..."

# https://github.com/zdharma-continuum/zinit
yes "n" | bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
# https://pixi.carapace.sh
mise use -g carapace@latest

cp $(pwd)/.p10k.zsh ~/.p10k.zsh
ln -sf $(pwd)/.zshrc ~/.zshrc
zinit self-update

echo "zsh environment setup complete."
