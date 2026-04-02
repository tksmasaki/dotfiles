#!/bin/zsh
set -e
set -o pipefail
echo "Execution: install.sh"

# Parse command line options
LOCAL_SETUP=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    "--local")
			LOCAL_SETUP=true ;;
    *)
			echo "Unknown option: $1";
			exit 1 ;;
  esac
  shift
done

# Create symbolic links to dotfiles in home directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ln -sf "$SCRIPT_DIR/zsh/.zshrc" ~/.zshrc
ln -sf "$SCRIPT_DIR/vim/.vimrc" ~/.vimrc
ln -sf "$SCRIPT_DIR/powerlevel10k/.p10k.zsh" ~/.p10k.zsh
mkdir -p ~/.config
mkdir -p ~/.config/git
ln -sf "$SCRIPT_DIR/git/config" ~/.config/git/config
ln -sf "$SCRIPT_DIR/git/ignore" ~/.config/git/ignore
ln -sf "$SCRIPT_DIR/git/.gitmessage.txt" ~/.config/git/.gitmessage.txt
mkdir -p ~/.config/nvim
ln -sf "$SCRIPT_DIR/nvim/init.vim" ~/.config/nvim/init.vim
mkdir -p ~/.config/mise
ln -sf "$SCRIPT_DIR/mise/config.toml" ~/.config/mise/config.toml
mkdir -p ~/.config/sheldon
ln -sf "$SCRIPT_DIR/sheldon/plugins.toml" ~/.config/sheldon/plugins.toml

# https://brew.sh
if ! command -v brew > /dev/null 2>&1; then
	echo "Install Homebrew"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
	echo "Homebrew is already installed"
fi

if ! command -v nvim > /dev/null 2>&1; then
	echo "Install neovim"
	brew install neovim
else
	echo "Neovim is already installed"
fi

# https://sheldon.cli.rs
if ! command -v sheldon > /dev/null 2>&1; then
	echo "Install sheldon"
	brew install sheldon
else
	echo "sheldon is already installed"
fi

# https://mise.jdx.dev
if ! command -v mise > /dev/null 2>&1; then
  echo "Install mise"
	brew install mise
else
	echo "mise is already installed"
fi

echo "Source .zshrc"
# Allow .zshrc errors (some tools may not be set up yet)
set +e
# shellcheck disable=SC1090
source ~/.zshrc
set -e

echo "Trust mise configuration"
mise trust ~/.config/mise/config.toml
echo "Run mise install"
mise install --cd ~

# Run local setup if --local option was specified
if [[ "$LOCAL_SETUP" = true ]]; then
  echo "Running local setup..."
  "$SCRIPT_DIR/setup_for_local.sh"
fi

echo "Completion: install.sh"
