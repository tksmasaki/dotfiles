#!/bin/sh
# PostToolUse hook (Write|Edit)。md を書いたら markdownlint-cli2 で自動修正し、
# 残ったエラーだけを additionalContext として返す。
#
# 対象ファイルはパスではなく stdin で渡し、cwd を $HOME に固定する。
# markdownlint-cli2 は cwd と対象ファイルの各ディレクトリから
# .markdownlint-cli2.{cjs,mjs} や customRules を探して JS として実行するため、
# 作業中のリポジトリの設定を読ませると、その repo のコードが hook 経由で走る。
set -eu

file=$(jq -r '.tool_input.file_path // ""')

case "$file" in
  *.md) ;;
  *) exit 0 ;;
esac
case "$file" in
  /*) ;;
  *) file="$PWD/$file" ;;
esac
[ -f "$file" ] || exit 0

cd "$HOME"
lint="npx --yes markdownlint-cli2@0.23.2"

if fixed=$($lint --format < "$file" 2>/dev/null) && [ -n "$fixed" ]; then
  printf '%s\n' "$fixed" > "$file"
fi

if result=$($lint - < "$file" 2>&1); then
  exit 0
fi

jq -n --arg ctx "markdownlint-cli2 (auto-fix 適用後の残エラー) $file:
$result" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
