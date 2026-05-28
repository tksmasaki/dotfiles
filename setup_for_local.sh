#!/bin/zsh
set -e
set -o pipefail
echo "Execution: setup_for_local.sh"

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

echo "Completion: setup_for_local.sh"
