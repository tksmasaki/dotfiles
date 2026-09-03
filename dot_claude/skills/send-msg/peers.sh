#!/usr/bin/env bash
set -uo pipefail

sessions="$HOME/.claude/sessions"
[ -d "$sessions" ] || exit 0

show_all=0
[ "${1:-}" = "--all" ] && show_all=1

here="$(git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")"
roots=""

root_of() {
  local cached
  cached="$(printf '%s\n' "$roots" | awk -F'\t' -v c="$1" '$1==c {print $2; exit}')"
  if [ -z "$cached" ]; then
    cached="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$1")"
    roots="$(printf '%s\n%s\t%s' "$roots" "$1" "$cached")"
  fi
  printf '%s' "$cached"
}

jq -r 'select(.messagingSocketPath and .name and .cwd)
       | [.pid, .messagingSocketPath, .name, (.status // "-"), .cwd] | @tsv' \
  "$sessions"/*.json 2>/dev/null |
while IFS=$'\t' read -r pid sock name status cwd; do
  kill -0 "$pid" 2>/dev/null || continue
  ref="$(printf 'session:%s' "$sock" | shasum -a 256 | cut -c1-6)"
  if [ "$sock" = "${CLAUDE_CODE_MESSAGING_SOCKET:-}" ]; then
    scope=self
  elif [ "$(root_of "$cwd")" = "$here" ]; then
    scope=same
  else
    scope=other
  fi
  [ "$scope" = other ] && [ "$show_all" -eq 0 ] && continue
  case "$scope" in
    self) order=0 ;;
    same) order=1 ;;
    *) order=2 ;;
  esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$order" "$scope" "$name" "$ref" "$status" "$cwd"
done | sort -t$'\t' -k1,1n -k3,3 -k4,4 | cut -f2-
