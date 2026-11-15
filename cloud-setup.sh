#!/bin/bash
# クラウド環境のセットアップスクリプトに貼って使う。リポジトリの複製より前に動くので、このファイル単体で完結させる。
set -uo pipefail

# api.github.com はネットワークポリシーで 403 になるため、GitHub Releases のバイナリを直接取得する（バージョンは手動で更新する）。
MISE_VERSION=2026.11.8
MISE_URL="https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64"

export HOME="${HOME:-/root}"
DOTFILES_DIR="${HOME}/.local/share/dotfiles"

if ! curl -fsSL --retry 3 -o /usr/local/bin/mise "$MISE_URL"; then
  echo "mise install failed; skipping dotfiles" >&2
  exit 0
fi
chmod +x /usr/local/bin/mise

if ! git clone --depth 1 https://github.com/tksmasaki/dotfiles.git "$DOTFILES_DIR"; then
  echo "dotfiles clone failed; skipping dotfiles" >&2
  exit 0
fi

mise trust "$DOTFILES_DIR/mise.toml"
mise -C "$DOTFILES_DIR" dotfiles apply --yes --force || true
