#!/bin/zsh
set -e
set -o pipefail
echo "Execute setup_for_devcontainer.sh"

# Create symbolic links to dotfiles in home directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ln -sf "$SCRIPT_DIR/powerlevel10k/.p10k.zsh" ~/.p10k.zsh
ln -sf "$SCRIPT_DIR/.zshrc" ~/.zshrc
ln -sf "$SCRIPT_DIR/.vimrc" ~/.vimrc

# https://mise.jdx.dev
if ! command -v mise > /dev/null 2>&1; then
  echo "Install mise"
	curl https://mise.run | sh
else
	echo "mise is already installed"
fi

# https://github.com/zdharma-continuum/zinit
if [ ! -d "$HOME/.local/share/zinit/zinit.git" ]; then
	echo "Install Zinit"
	yes "n" | bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
else
	echo "Zinit is already installed"
fi

# Allow .zshrc errors (some tools may not be set up yet)
set +e
source ~/.zshrc
set -e

echo "Compile Zinit"
zinit self-update

echo "Run mise install"
mise install

echo "setup_for_devcontainer.sh execution completed"
