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
#   CLAUDE_AUTO_COMMIT=1 のとき、git commit のみ確認なしで通す。
#   ただし同じコマンドに commit 以外のリモート影響コマンド（push 等）が
#   含まれる場合は、引き続き確認を求める。
#
#   CLAUDE_SKIP_REMOTE_CONFIRM=1 のとき、この検知自体を無効化して
#   すべて通常のパーミッション判定に委ねる。ローカルでフック自体の挙動を
#   検証したいときなど、一時的な無効化のために使う
#   （toggle-remote-confirm off で立てる。立てたままにすると push やデプロイ系も
#   確認なしで通るので注意）
#
# どちらのフラグも、環境変数ではなくファイルの現在値を毎回読み直して判定する
# （解決順は lib/claude-env.sh を参照。worktree ごとの claude-env.json が最優先で、
# toggle-auto-commit / toggle-remote-confirm の書き込み先もそこ）。
# 環境変数はセッション開始時のスナップショットなので、切り替えが実行中セッションに
# 反映されないため。ファイルを読めないときだけ環境変数にフォールバックする。
#
# 検知しない場合は何も出力せず、通常のパーミッション判定に委ねる。
set -euo pipefail

# shellcheck source=lib/claude-env.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/claude-env.sh"

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[ -n "$cwd" ] || cwd="$PWD"

skip_remote_confirm="$(claude_env_current CLAUDE_SKIP_REMOTE_CONFIRM "$cwd")" \
  || skip_remote_confirm="${CLAUDE_SKIP_REMOTE_CONFIRM:-}"
auto_commit="$(claude_env_current CLAUDE_AUTO_COMMIT "$cwd")" \
  || auto_commit="${CLAUDE_AUTO_COMMIT:-}"

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

# エスケープハッチ: 検知そのものを無効化（ローカル検証用）。
# 素通しするが、有効化されていることを systemMessage でユーザーに警告する
# （permissionDecision は返さないので通常のパーミッション判定に委ねられる）
if [ "$skip_remote_confirm" = "1" ]; then
  # 表示用にコマンドを 200 文字で切る
  shown="$(printf '%s' "$cmd" | cut -c1-200)"
  [ "${#cmd}" -gt 200 ] && shown="${shown}..."
  jq -n --arg c "$shown" '
    {
      systemMessage: ("[エスケープハッチ有効] CLAUDE_SKIP_REMOTE_CONFIRM=1 のため、リモート影響コマンドの事前確認をスキップしました: " + $c + "\n検証が終わったら .claude/settings.local.json から削除してください。"),
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: ("CLAUDE_SKIP_REMOTE_CONFIRM=1 が有効なため confirm-remote-commands の検知をスキップした（対象コマンド: " + $c + "）。ユーザーに検証用の一時設定である旨を伝えること。")
      }
    }
  '
  exit 0
fi

# エスケープハッチ: CLAUDE_AUTO_COMMIT=1 かつ commit 以外の対象を含まない場合のみ素通し
if [ "$auto_commit" = "1" ] && ! printf '%s' "$cmd" | grep -qE "$pattern_other"; then
  exit 0
fi

# 検知したコマンドを列挙する（重複は除き、空白は 1 つに詰める）。
# 抽出に失敗しても確認自体は行うため、失敗時は空にして総称の文言にフォールバックする。
matched="$(
  printf '%s' "$cmd" | grep -oE "$pattern_full" \
    | sed -E 's/^[;&|[:space:]]+//' \
    | sed -E 's/^((sudo|time|bundle[[:space:]]+exec|npx|env[[:space:]]+[^[:space:]]+=[^[:space:]]*)[[:space:]]+)*//' \
    | sed -E 's/[[:space:]]+/ /g' \
    | sed -E 's/[[:space:]]+$//' \
    | awk 'NF && !seen[$0]++ {printf "%s%s", sep, $0; sep=", "}' \
    || true
)"

if [ -n "$matched" ]; then
  reason="リモートに影響するコマンドを検知しました: ${matched}。実行前に内容を確認してください。"
else
  reason="リモートに影響するコマンド（git push/commit, gh pr/release/repo/secret/workflow, npm/yarn/pnpm publish, gem/docker push, kubectl apply/delete, terraform apply/destroy, gcloud/cap deploy 等）です。実行前に内容を確認してください。"
fi

jq -n --arg r "$reason" '
  {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $r
    }
  }
'
