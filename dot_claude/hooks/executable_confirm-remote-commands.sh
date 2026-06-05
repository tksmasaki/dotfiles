#!/usr/bin/env bash
# PreToolUse(Bash) フック:
# リモートに影響する（外部に公開・反映される / 取り消しが難しい）コマンドを
# 検知したら permissionDecision="ask" を返し、実行前に必ず確認させる。
#
# 検知対象:
#   Git/GitHub:
#     - git push / git commit
#     - gh pr ... / gh release ...
#     - gh repo create|delete / gh secret|variable set / gh workflow run
#   パッケージ公開:
#     - npm|yarn|pnpm publish / gem push / docker push
#   デプロイ・インフラ:
#     - kubectl apply|delete / terraform apply|destroy
#     - gcloud ... deploy / cap ... deploy
#
# 例外（エスケープハッチ）:
#   環境変数 CLAUDE_AUTO_COMMIT=1 のとき、git commit のみ確認なしで通す。
#   ただし同じコマンドに commit 以外のリモート影響コマンド（push 等）が
#   含まれる場合は、引き続き確認を求める。
#
# 検知しない場合は何も出力せず、通常のパーミッション判定に委ねる。
set -euo pipefail

cmd="$(jq -r '.tool_input.command // ""')"

# 行頭またはコマンド区切り(; & | && ||)の直後。
# ラッパー(sudo / time / bundle exec / npx / env VAR=...)の前置きも許容する。
lead='(^|[;&|]|&&|\|\|)[[:space:]]*((sudo|time|bundle[[:space:]]+exec|npx|env[[:space:]]+[^[:space:]]+=[^[:space:]]*)[[:space:]]+)*'

# git commit（エスケープハッチで個別に扱うため分離）
commit_kw='git[[:space:]]+commit'

# commit 以外の検知対象（リモート影響 / 取り消し困難）
other_kw='git[[:space:]]+push'
other_kw+='|gh[[:space:]]+pr[[:space:]]+(create|merge|close|edit|review|comment|reopen)([[:space:]]|$)'
other_kw+='|gh[[:space:]]+release[[:space:]]+(create|delete|upload|edit)([[:space:]]|$)'
other_kw+='|gh[[:space:]]+repo[[:space:]]+(create|delete)'
other_kw+='|gh[[:space:]]+(secret|variable)[[:space:]]+set'
other_kw+='|gh[[:space:]]+workflow[[:space:]]+run'
other_kw+='|(npm|yarn|pnpm)[[:space:]]+publish'
other_kw+='|gem[[:space:]]+push'
other_kw+='|docker[[:space:]]+push'
other_kw+='|kubectl[[:space:]]+(apply|delete)'
other_kw+='|terraform[[:space:]]+(apply|destroy)'
other_kw+='|gcloud[[:space:]]+([^[:space:]]+[[:space:]]+)*deploy'
other_kw+='|cap[[:space:]]+([^[:space:]]+[[:space:]]+)*deploy'

pattern_full="${lead}(${commit_kw}|${other_kw})"
pattern_other="${lead}(${other_kw})"

# リモート影響コマンドでなければ通常判定に委ねる
if ! printf '%s' "$cmd" | grep -qE "$pattern_full"; then
  exit 0
fi

# エスケープハッチ: CLAUDE_AUTO_COMMIT=1 かつ commit 以外の対象を含まない場合のみ素通し
if [ "${CLAUDE_AUTO_COMMIT:-}" = "1" ] && ! printf '%s' "$cmd" | grep -qE "$pattern_other"; then
  exit 0
fi

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "リモートに影響するコマンド（git push/commit, gh pr/release/repo/secret/workflow, npm/yarn/pnpm publish, gem/docker push, kubectl apply/delete, terraform apply/destroy, gcloud/cap deploy 等）です。実行前に内容を確認してください。"
  }
}
JSON
