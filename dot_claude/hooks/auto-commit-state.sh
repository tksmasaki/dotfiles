#!/usr/bin/env bash
# auto-commit-state.sh - CLAUDE_AUTO_COMMIT の現在値をセッション途中でも伝える
#
# toggle-auto-commit の書き込み先は worktree ごとの claude-env.json で、Claude Code の
# settings ではないため環境変数には載らない。settings.local.json に置いた場合も、env が
# 読まれるのはセッション開始時の一度だけで、書き換えても実行中セッションには反映されない。
# そこで UserPromptSubmit のたびにファイルの現在値を読み直し、環境変数と食い違うときだけ
# additionalContext で正しい状態を注入する。このフックを外すと、Claude 側からは
# claude-env.json の値が見えなくなる。
#
# CLAUDE_AUTO_COMMIT は「Claude が自発的に commit してよいか」という判断材料
# なので、フックで強制するのではなく Claude に現在値を伝える形をとる。
# （CLAUDE_SKIP_REMOTE_CONFIRM のようにフック自身が使う値は、
#   confirm-remote-commands.sh 側で直接読み直している）
#
# 食い違いがないときは何も出力しない（毎プロンプトのノイズを避ける）。
# 設定ファイルを読めないときも何も注入しない（環境変数の値が使われるだけで、
# フック導入前と同じ挙動に戻る）。

set -uo pipefail

KEY=CLAUDE_AUTO_COMMIT

# shellcheck source=lib/claude-env.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/claude-env.sh" || exit 0

input="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)" || exit 0
[ -n "$cwd" ] || exit 0

file_val="$(claude_env_current "$KEY" "$cwd")" || exit 0
env_val="${CLAUDE_AUTO_COMMIT-}"

# 有効/無効が一致していれば、セッション開始時の値がそのまま正しい。
# 値そのものではなく意味で比べる（"0" と未設定はどちらも無効なので注入しない）
enabled() { [ "$1" = "1" ]; }
if enabled "$file_val"; then file_state=on; else file_state=off; fi
if enabled "$env_val"; then env_state=on; else env_state=off; fi
[ "$file_state" = "$env_state" ] && exit 0

if [ "$file_val" = "1" ]; then
  state='"1"（自動コミット有効）'
else
  state='未設定または無効値（自動コミット無効）'
fi

ctx="$KEY の現在値は ${state}。\
環境変数 $KEY の値は古い（セッション開始時のスナップショット、または未設定）。\
自動コミットの可否（commit-workflow スキル）はこの現在値を正として判断すること。"

jq -n --arg ctx "$ctx" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$ctx}}'
