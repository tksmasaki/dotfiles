#!/usr/bin/env bash
set -euo pipefail

: "${HOME:?HOME must be set}"
dotfiles_dir="$HOME/.local/share/dotfiles"

if ! command -v mise >/dev/null 2>&1; then
  mise_version=2026.11.8
  mkdir -p "$HOME/.local/bin"
  curl -fsSL --retry 3 -o "$HOME/.local/bin/mise" "https://github.com/jdx/mise/releases/download/v${mise_version}/mise-v${mise_version}-linux-x64"
  chmod +x "$HOME/.local/bin/mise"
  export PATH="$HOME/.local/bin:$PATH"
fi

mkdir -p "$HOME/.local/share"
git clone --depth 1 --branch main https://github.com/tksmasaki/dotfiles.git "$dotfiles_dir"

for config in "$dotfiles_dir/mise.toml" "$dotfiles_dir/mise.mac.toml"; do
  mise trust "$config"
done

targets=("$HOME/.codex/AGENTS.md")
for skill in "$dotfiles_dir"/agents/skills/*; do
  [[ -d "$skill" && -f "$skill/SKILL.md" ]] || continue
  targets+=("$HOME/.agents/skills/${skill##*/}")
done

mise -E mac -C "$dotfiles_dir" dotfiles apply --yes --force "${targets[@]}"
