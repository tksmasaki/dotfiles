#!/bin/zsh
set -e
set -o pipefail
echo "Execute install.sh"

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
ln -sf "$SCRIPT_DIR/git/.gitmessage.txt" ~/.gitmessage.txt
mkdir -p ~/.config
ln -sf "$SCRIPT_DIR/starship/starship.toml" ~/.config/starship.toml
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

# https://sheldon.cli.rs
echo "Install sheldon"
brew install sheldon

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

echo "install.sh execution completed"
