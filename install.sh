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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Install Homebrew packages"
brew bundle --file "$SCRIPT_DIR/Brewfile"

# https://github.com/alacritty/alacritty/releases
if [[ ! -d "/Applications/Alacritty.app" ]]; then
	echo "Alacritty is not installed. Please install it from: https://github.com/alacritty/alacritty/releases"
else
	echo "Alacritty is already installed"
fi

# mise は symlink の適用先にある実ファイルを上書きせず、適用全体を止めるため
backup_conflicting_files() {
	local suffix=".bak.$(date +%Y%m%d%H%M%S)"
	local target
	for _ in {1..100}; do
		target="$(mise -E mac -C "$SCRIPT_DIR" dotfiles status --json 2>/dev/null | jq -r '
			[.files[]
				| select(.state == "differs" and (.reason | endswith("exists but is not a symlink")))
				| ((.reason | capture("^(?<path>.+): exists").path) // .target)]
			| first // empty')"
		[[ -z "$target" ]] && return 0
		target="${target/#\~/$HOME}"
		echo "Back up $target to $target$suffix"
		mv "$target" "$target$suffix"
	done
	echo "Too many conflicting files" >&2
	return 1
}

echo "Apply dotfiles with mise"
git -C "$SCRIPT_DIR" config core.hooksPath .githooks
mise trust "$SCRIPT_DIR/mise.toml"
mise trust "$SCRIPT_DIR/mise.mac.toml"
backup_conflicting_files
mise -E mac -C "$SCRIPT_DIR" dotfiles apply --yes

eval "$(mise activate zsh)"
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
