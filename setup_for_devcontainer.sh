#!/bin/zsh

echo "Setup zsh environment for devcontainer"

# https://mise.jdx.dev
if ! command -v mise > /dev/null 2>&1; then
  echo "Install mise"
	curl https://mise.run | sh
fi

# https://github.com/zdharma-continuum/zinit
yes "n" | bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
# https://pixi.carapace.sh
mise use -g carapace@latest

cp $(pwd)/.p10k.zsh ~/.p10k.zsh
ln -sf $(pwd)/.zshrc ~/.zshrc
source ~/.zshrc
zinit self-update

echo "zsh environment setup completed"
