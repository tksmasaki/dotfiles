#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
peers="$here/peers.sh"

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

usage() {
  cat >&2 <<'USAGE'
usage:
  role.sh set <役割>    自セッション名を役割ファイルに書く
  role.sh get <役割>    役割を `名前 [ref]` に解決する
  role.sh list          同じ作業ツリーの役割割り当てを出す
USAGE
  exit 2
}

role_dir() {
  local gitdir
  gitdir="$(git rev-parse --absolute-git-dir 2>/dev/null)" ||
    die "git リポジトリの中で実行してください"
  printf '%s/claude-roles' "$gitdir"
}

check_role_name() {
  case "$1" in
    *[!A-Za-z0-9_-]* | '') die "役割名に使えるのは英数字・ハイフン・アンダースコアだけです: $1" ;;
  esac
}

# scope name ref status cwd
local_rows() {
  "$peers" | awk -F'\t' '$1=="self" || $1=="same"'
}

self_name() {
  "$peers" | awk -F'\t' '$1=="self" {print $2; exit}'
}

cmd_set() {
  local role="$1" name dir
  check_role_name "$role"
  name="$(self_name)"
  [ -n "$name" ] ||
    die "自セッションを特定できません。CLAUDE_CODE_MESSAGING_SOCKET が設定された環境で実行してください"
  dir="$(role_dir)" || exit 1
  mkdir -p "$dir" || die "役割ディレクトリを作れません: $dir"
  printf '%s\n' "$name" >"$dir/$role" || die "役割ファイルを書けません: $dir/$role"
  printf '%s\t%s\n' "$role" "$name"
}

cmd_get() {
  local role="$1" dir file name matches count
  check_role_name "$role"
  dir="$(role_dir)" || exit 1
  file="$dir/$role"
  [ -f "$file" ] || die "役割ファイルがありません: $file（相手がまだ役割を書いていません）"
  name="$(head -1 "$file" | tr -d '\r\n')"
  [ -n "$name" ] || die "役割ファイルが空です: $file"

  matches="$(local_rows | awk -F'\t' -v n="$name" '$2==n {print $1"\t"$3"\t"$4}')"
  count="$(printf '%s' "$matches" | grep -c . || true)"

  if [ "$count" -eq 0 ]; then
    die "$role として記録されている「$name」は、同じ作業ツリーで動いていません（終了したか別の作業ツリーにいます）"
  fi
  if [ "$count" -gt 1 ]; then
    printf '%s に「%s」が %s 件あります。ref で選んでください:\n' "$role" "$name" "$count" >&2
    printf '%s\n' "$matches" | while IFS=$'\t' read -r _ ref status; do
      printf '  %s [%s]\t%s\n' "$name" "$ref" "$status" >&2
    done
    exit 1
  fi

  [ "$(printf '%s' "$matches" | cut -f1)" = self ] &&
    die "$role は自分自身（$name）です。宛先にはなりません"

  printf '%s [%s]\n' "$name" "$(printf '%s' "$matches" | cut -f2)"
}

cmd_list() {
  local dir
  dir="$(role_dir)" || exit 1
  [ -d "$dir" ] || exit 0
  local rows
  rows="$(local_rows)"
  for file in "$dir"/*; do
    [ -f "$file" ] || continue
    local role name line
    role="$(basename "$file")"
    name="$(head -1 "$file" | tr -d '\r\n')"
    line="$(printf '%s\n' "$rows" | awk -F'\t' -v n="$name" '$2==n {print $3"\t"$1"\t"$4; exit}')"
    if [ -n "$line" ]; then
      printf '%s\t%s\t%s\n' "$role" "$name" "$line"
    else
      printf '%s\t%s\t-\tnot-in-worktree\t-\n' "$role" "$name"
    fi
  done
}

[ -x "$peers" ] || die "peers.sh が見つかりません: $peers"

case "${1:-}" in
  set) [ $# -eq 2 ] || usage; cmd_set "$2" ;;
  get) [ $# -eq 2 ] || usage; cmd_get "$2" ;;
  list) [ $# -eq 1 ] || usage; cmd_list ;;
  *) usage ;;
esac
