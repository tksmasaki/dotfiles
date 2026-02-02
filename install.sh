#!/bin/bash
set -e
set -o pipefail
echo "Execute install.sh"

# https://mise.jdx.dev
if ! command -v mise > /dev/null 2>&1; then
  echo "Install mise"
	curl https://mise.run | sh
fi
echo "Run mise install"
mise install

# https://github.com/zdharma-continuum/zinit
if ! command -v zinit > /dev/null 2>&1; then
	echo "Install Zinit"
	yes "n" | bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
fi

# https://github.com/github/copilot-cli
if ! command -v copilot > /dev/null 2>&1; then
	echo "Install GitHub Copilot CLI"
	curl -fsSL https://gh.io/copilot-install | bash
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ln -sf "$SCRIPT_DIR/powerlevel10k/.p10k.zsh" ~/.p10k.zsh
ln -sf "$SCRIPT_DIR/.zshrc" ~/.zshrc
ln -sf "$SCRIPT_DIR/.vimrc" ~/.vimrc
source ~/.zshrc
zinit self-update

echo "install.sh execution completed"
