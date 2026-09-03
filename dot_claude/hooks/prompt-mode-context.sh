#!/bin/sh
# UserPromptSubmit hook。md 出力を求めるプロンプトのときだけ、現在の permission_mode を
# additionalContext として渡す。md-output skill が出力先を決めるのに使う。
set -eu

input=$(cat)
mode=$(printf '%s' "$input" | jq -r '.permission_mode // ""')

if [ -z "$mode" ] || [ "$mode" = "default" ]; then
  exit 0
fi

if ! printf '%s' "$input" | jq -r '.prompt // ""' |
  grep -qiE 'md|markdown|マークダウン|ファイル|保存|まとめ|出力'; then
  exit 0
fi

jq -n --arg m "$mode" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: ("Claude Code permission_mode: " + $m)}}'
