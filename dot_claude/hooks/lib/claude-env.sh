#!/usr/bin/env bash
# claude-env.sh - settings の env の「現在値」を解決する共通ヘルパー（source して使う）
#
# Claude Code は settings の env をセッション開始時に一度だけ環境変数へ読み込む。
# そのため toggle-auto-commit / toggle-remote-confirm で設定を書き換えても、
# 実行中セッションの環境変数は古いままになる。
# フックはコマンドとして毎回起動されるので、ファイルを読み直せば現在値が得られる。
#
# 最優先で読むのは git ディレクトリ直下の claude-env.json（worktree ごとの上書き）。
# .claude/settings.local.json はメイン作業ツリーへの symlink になっていることがあり、
# そこに置いた値は全 worktree で共有される。worktree ごとに変えたい値は、共有されない
# git ディレクトリ（メインは <repo>/.git、worktree は <repo>/.git/worktrees/<名前>）に置く。
# 残りは Claude Code の設定マージ順に合わせ、最初に定義されたものを採用する。
#
# どのファイルにも無ければ「未設定」とみなす（環境変数へはフォールバックしない。
# フォールバックすると、キーを削除して無効化した操作が古い環境変数で打ち消されて
# しまい、off が効かなくなるため）。
# したがって、シェルで export しただけの値は解決対象外になる。フックの対象キーは
# settings の env か claude-env.json に置くこと。
#
# 使い方:
#   . ~/.claude/hooks/lib/claude-env.sh
#   val="$(claude_env_current CLAUDE_AUTO_COMMIT "$cwd")" || val="${CLAUDE_AUTO_COMMIT-}"
#
# 戻り値: 0 = 解決できた（未設定なら空文字を出力） / 1 = 設定ファイルを読めない
#         （JSON が不正など）。呼び出し側で環境変数へ委ねるなどの判断をする。

claude_env_current() {
  local key="$1" dir="${2:-$PWD}"
  local root git_dir file val
  local files=()

  command -v jq >/dev/null 2>&1 || return 1

  root="$(cd "$dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || root=""
  git_dir="$(cd "$dir" 2>/dev/null && git rev-parse --absolute-git-dir 2>/dev/null)" || git_dir=""
  [ -n "$root" ] || root="$dir"

  if [ -n "$git_dir" ]; then
    files+=("$git_dir/claude-env.json")
  fi
  files+=(
    "$root/.claude/settings.local.json"
    "$root/.claude/settings.json"
    "$HOME/.claude/settings.local.json"
    "$HOME/.claude/settings.json"
  )

  for file in "${files[@]}"; do
    [ -f "$file" ] || continue
    # 読めない（JSON 不正・env がオブジェクトでない）ときは「未設定」と誤判定しない
    val="$(jq -r --arg k "$key" '.env[$k] // empty' "$file" 2>/dev/null)" || return 1
    if [ -n "$val" ]; then
      printf '%s' "$val"
      return 0
    fi
  done

  return 0
}
