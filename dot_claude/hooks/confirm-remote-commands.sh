#!/usr/bin/env bash
# PreToolUse(Bash) フック:
# 取り消せない、または外部に直接届くコマンドを検知したら permissionDecision="ask" を
# 返し、実行前に必ず確認させる。ローカルで完結する操作（git commit）と、GitHub 上で
# 後から直せる操作（gh pr / gh release / gh api の書き込み）は対象にしない。
#
# 検知対象:
#   - git push（-C / -c / --no-pager 等のグローバルオプション挟みも含む）
#   - git の任意ファイル書き出し・任意コマンド起動オプション
#     (--output / --upload-pack / --receive-pack / --exec)
#   - gh repo delete / gh secret|variable set / gh workflow run
#   - npm|yarn|pnpm publish / gem push / docker push
#   - kubectl apply|delete / terraform apply|destroy / gcloud ... deploy / cap ... deploy
#
# CLAUDE_SKIP_REMOTE_CONFIRM=1 のとき、この検知自体を無効化して通常のパーミッション
# 判定に委ねる（toggle-remote-confirm off で立てる。ローカルでフックの挙動を検証する
# ための一時的な無効化で、立てたままにすると push やデプロイ系も確認なしで通る）。
# 値は環境変数ではなくファイルの現在値を毎回読み直す（解決順は lib/claude-env.sh）。
# 環境変数はセッション開始時のスナップショットで、切り替えが実行中セッションに
# 反映されないため。ファイルを読めないときだけ環境変数にフォールバックする。
set -euo pipefail

# shellcheck source=lib/claude-env.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/claude-env.sh"

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[ -n "$cwd" ] || cwd="$PWD"

skip_remote_confirm="$(claude_env_current CLAUDE_SKIP_REMOTE_CONFIRM "$cwd")" \
  || skip_remote_confirm="${CLAUDE_SKIP_REMOTE_CONFIRM:-}"

# コマンド名の直前が行頭か、識別子・パスの一部にならない 1 文字であればよい。
# 区切り(; & |)だけでなく、$( ( { 引用符 バックスラッシュ や、
# sudo / xargs / eval / command / then / do などの前置きの後ろも対象になる。
lead='(^|[^[:alnum:]_.-])'

# git のサブコマンドの前に置けるグローバルオプション（-C <dir> / -c k=v / --no-pager 等）
git_gopt='((-[cC]|--git-dir|--work-tree|--namespace|--exec-path|--config-env)[[:space:]]+[^[:space:]]+|--?[[:alnum:]][^[:space:]]*)[[:space:]]+'
git_cmd="git[[:space:]]+(${git_gopt})*"

# gh のサブコマンドの前後に置けるフラグ（--repo o/r / -R o/r / --repo=o/r 等）
gh_flag='(-[[:alnum:]]|--[[:alnum:]-]+)(=[^[:space:]]*|[[:space:]]+[^-[:space:]][^[:space:]]*)?[[:space:]]+'
gh_cmd="gh[[:space:]]+(${gh_flag})*"

git_exec_kw='git[[:space:]]+([^;&|]*[[:space:]])?--(output|upload-pack|receive-pack|exec)([[:space:]=]|$)'

kw="${git_cmd}push([^[:alnum:]_-]|$)"
kw+="|${git_exec_kw}"
kw+="|${gh_cmd}repo[[:space:]]+(${gh_flag})*delete"
kw+="|${gh_cmd}(secret|variable)[[:space:]]+(${gh_flag})*set"
kw+="|${gh_cmd}workflow[[:space:]]+(${gh_flag})*run"
kw+='|(npm|yarn|pnpm)[[:space:]]+publish'
kw+='|gem[[:space:]]+push'
kw+='|docker[[:space:]]+push'
kw+='|kubectl[[:space:]]+(apply|delete)'
kw+='|terraform[[:space:]]+(apply|destroy)'
kw+='|gcloud[[:space:]]+([^[:space:]]+[[:space:]]+)*deploy'
kw+='|cap[[:space:]]+([^[:space:]]+[[:space:]]+)*deploy'

pattern="${lead}(${kw})"

if ! printf '%s' "$cmd" | grep -qE "$pattern"; then
  exit 0
fi

# 素通しするが、有効化されていることを systemMessage でユーザーに警告する
# （permissionDecision は返さないので通常のパーミッション判定に委ねられる）
if [ "$skip_remote_confirm" = "1" ]; then
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

# 検知したコマンドを、区切り（; && || |）で切ったセグメント単位で取り出す。
# キーワードだけを出すと git push と git push --force-with-lease が同じ文言になり、
# 危険度を読み取れない。フラグまで含めるためにセグメントごと出す。
# シェルの構文解析ではないので、引用符の中の区切りでも切る。コマンド全文は
# パーミッションダイアログに出るため、表示用の抽出としてはこれで足りる。
# 2>&1 のような >& は区切りではないので、切る前に退避する。
ph="$(printf '\001')"
segments="$(
  printf '%s' "$cmd" \
    | sed "s/>&/${ph}/g" \
    | tr ';&|' '\n\n\n' \
    | sed "s/${ph}/>\&/g" \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g' \
    | grep -E "$pattern" \
    | awk 'NF && !seen[$0]++' \
    || true
)"

# 危険度の分類。検知そのものには使わない（何を確認させるかは pattern が決める）。
force_kw='(--force([^[:alnum:]_-]|$)|--force-with-lease|[[:space:]]-[[:alnum:]]*f[[:alnum:]]*([[:space:]]|$))'
destroy_kw="${gh_cmd}repo[[:space:]]+(${gh_flag})*delete"
destroy_kw+='|kubectl[[:space:]]+delete|terraform[[:space:]]+destroy'
destroy_kw+="|${git_exec_kw}"

irreversible=""
publish=""

if [ -n "$segments" ]; then
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    if printf '%s' "$seg" | grep -qE "${lead}${git_cmd}push" \
      && printf '%s' "$seg" | grep -qE "$force_kw"; then
      irreversible="${irreversible}${irreversible:+, }${seg}"
    elif printf '%s' "$seg" | grep -qE "${lead}(${destroy_kw})"; then
      irreversible="${irreversible}${irreversible:+, }${seg}"
    else
      publish="${publish}${publish:+, }${seg}"
    fi
  done <<< "$segments"
fi

if [ -n "$irreversible" ] || [ -n "$publish" ]; then
  reason=""
  [ -n "$irreversible" ] && reason+="取り消せません。リモートの履歴やリソースを上書き・削除します: ${irreversible}"$'\n'
  [ -n "$publish" ] && reason+="外部に公開・反映されます: ${publish}"$'\n'
  reason+="実行前に内容を確認してください。"
else
  # セグメントに切れなかった場合の退避。確認自体は行うので、拾えた語だけ出す。
  matched="$(
    printf '%s' "$cmd" | grep -oE "$pattern" \
      | sed -E 's/^[^[:alnum:]_.-]//' \
      | sed -E 's/[[:space:]]+/ /g' \
      | sed -E 's/[[:space:]]+$//' \
      | awk 'NF && !seen[$0]++ {printf "%s%s", sep, $0; sep=", "}' \
      || true
  )"

  if [ -n "$matched" ]; then
    reason="リモートに影響するコマンドを検知しました: ${matched}。実行前に内容を確認してください。"
  else
    reason="リモートに影響するコマンド（git push, git --output/--upload-pack/--receive-pack/--exec, gh repo delete, gh secret/variable set, gh workflow run, npm/yarn/pnpm publish, gem/docker push, kubectl apply/delete, terraform apply/destroy, gcloud/cap deploy）です。実行前に内容を確認してください。"
  fi
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
