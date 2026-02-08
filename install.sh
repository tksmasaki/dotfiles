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

echo "Trust mise configuration"
mise trust ~/dotfiles/mise.toml
echo "Source .zshrc"
# Allow .zshrc errors (some tools may not be set up yet)
set +e
source ~/.zshrc
set -e

echo "Run mise install"
mise install

# https://github.com/zdharma-continuum/zinit
if [ ! -d "$HOME/.local/share/zinit/zinit.git" ]; then
	echo "Install Zinit"
	yes "n" | bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
else
	echo "Zinit is already installed"
fi

echo "Source .zshrc"
# Allow .zshrc errors (some tools may not be set up yet)
set +e
source ~/.zshrc
set -e

echo "Compile Zinit"
zinit self-update

# Run local setup if --local option was specified
if [ "$LOCAL_SETUP" = true ]; then
  echo "Running local setup..."
  "$SCRIPT_DIR/setup_for_local.sh"
fi

echo "install.sh execution completed"
