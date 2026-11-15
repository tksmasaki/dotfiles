#!/usr/bin/env bash
set -euo pipefail

: "${HOME:?HOME must be set}"
dotfiles_dir="$HOME/.local/share/dotfiles"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v mise >/dev/null 2>&1; then
  mise_version=2026.11.8
  mise_asset="mise-v${mise_version}-linux-x64"
  mise_release_url="https://github.com/jdx/mise/releases/download/v${mise_version}"
  mise_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$mise_tmp"' EXIT
  curl -fsSL --retry 3 -o "$mise_tmp/$mise_asset" "$mise_release_url/$mise_asset"
  curl -fsSL --retry 3 -o "$mise_tmp/SHASUMS256.txt" "$mise_release_url/SHASUMS256.txt"
  (
    cd "$mise_tmp"
    awk -v asset="./$mise_asset" '$2 == asset' SHASUMS256.txt | sha256sum --check --strict -
  )
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$mise_tmp/$mise_asset" "$HOME/.local/bin/mise"
fi

if [[ ! -e "$dotfiles_dir" && ! -L "$dotfiles_dir" ]]; then
  mkdir -p "$HOME/.local/share"
  git clone --depth 1 --branch main https://github.com/tksmasaki/dotfiles.git "$dotfiles_dir"
else
  [[ -e "$dotfiles_dir/.git" ]] || { echo "Not a dotfiles checkout: $dotfiles_dir" >&2; exit 1; }
fi

for config in "$dotfiles_dir/mise.toml" "$dotfiles_dir/mise.mac.toml"; do
  mise trust "$config"
done

targets=("$HOME/.codex/AGENTS.md")
for skill in "$dotfiles_dir"/agents/skills/*; do
  [[ -d "$skill" && -f "$skill/SKILL.md" ]] || continue
  targets+=("$HOME/.agents/skills/${skill##*/}")
done

mise -E mac -C "$dotfiles_dir" dotfiles apply --yes --force "${targets[@]}"
