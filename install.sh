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

if ! command -v chezmoi > /dev/null 2>&1; then
	echo "Install chezmoi"
	brew install chezmoi
else
	echo "chezmoi is already installed"
fi

# https://github.com/alacritty/alacritty/releases
if [[ ! -d "/Applications/Alacritty.app" ]]; then
	echo "Alacritty is not installed. Please install it from: https://github.com/alacritty/alacritty/releases"
else
	echo "Alacritty is already installed"
fi

# https://github.com/yuru7/HackGen
if [[ ! -f "$HOME/Library/Fonts/HackGenConsoleNF-Regular.ttf" ]]; then
	echo "Install HackGen Console NF"
	brew install --cask font-hackgen-nerd
else
	echo "HackGen Console NF is already installed"
fi

if ! command -v herdr > /dev/null 2>&1; then
	echo "Install herdr"
  brew install herdr
else
	echo "herdr is already installed"
fi

echo "Apply dotfiles with chezmoi"
chezmoi init --apply tksmasaki

unsynced="$(chezmoi managed --include=files --path-style=absolute)"
if [[ -n "$unsynced" ]]; then
	echo "Warning: not symlinked, so edits in $HOME will not sync back:"
	echo "$unsynced" | sed 's/^/  /'
fi

eval "$(mise activate zsh)"
echo "Trust mise configuration"
mise trust ~/.config/mise/config.toml
echo "Run mise install"
mise install --cd ~

# Run local setup if --local option was specified
if [[ "$LOCAL_SETUP" = true ]]; then
  echo "Running local setup..."
	SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  "$SCRIPT_DIR/setup_for_local.sh"
fi

echo "Completion: install.sh"
