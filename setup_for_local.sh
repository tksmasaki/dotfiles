#!/bin/zsh
set -e
set -o pipefail
echo "Execute setup_for_local.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.config/ghostty
ln -sf "$SCRIPT_DIR/ghostty/config" ~/.config/ghostty/config
ln -sf "$SCRIPT_DIR/mise/mise.local.toml" ~/mise.local.toml

# https://github.com/github/copilot-cli
if ! command -v copilot > /dev/null 2>&1; then
	echo "Install GitHub Copilot CLI"
	curl -fsSL https://gh.io/copilot-install | bash
else
	echo "GitHub Copilot CLI is already installed"
fi

# https://code.claude.com/docs/en/overview
if ! command -v claude > /dev/null 2>&1; then
	echo "Install Claude Code"
	curl -fsSL https://claude.ai/install.sh | bash
else
	echo "Claude Code is already installed"
fi

echo "setup_for_local.sh execution completed"
