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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.config/mise
cp "$SCRIPT_DIR/dot_config/mise/config.toml" ~/.config/mise/config.toml

eval "$(mise activate zsh)"
echo "Trust mise configuration"
mise trust ~/.config/mise/config.toml
echo "Run mise install"
mise install --cd ~

echo "Apply dotfiles with chezmoi"
chezmoi init --apply

# Run local setup if --local option was specified
if [[ "$LOCAL_SETUP" = true ]]; then
  echo "Running local setup..."
  "$SCRIPT_DIR/setup_for_local.sh"
fi

echo "Completion: install.sh"
