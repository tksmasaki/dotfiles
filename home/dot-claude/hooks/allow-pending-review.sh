#!/usr/bin/env bash
# PreToolUse(GitHub MCP) フック:
# PR の pending レビューを作る・pending レビューにコメントを足す操作を、確認なしで通す。
# pending の間は自分にしか見えず、submit しない限り作者に届かないため。
# submit（event 付きの create、submit_pending）や pending レビューの削除は対象にせず、
# 通常のパーミッション判定に委ねる。
set -euo pipefail

input="$(cat)"
tool="$(printf '%s' "$input" | jq -r '.tool_name // ""')"
method="$(printf '%s' "$input" | jq -r '.tool_input.method // ""')"
event="$(printf '%s' "$input" | jq -r '.tool_input.event // ""')"

case "$tool" in
  *__add_comment_to_pending_review)
    reason="pending レビューへのコメントの追加（submit するまで作者には見えない）"
    ;;
  *__pull_request_review_write)
    [ "$method" = "create" ] && [ -z "$event" ] || exit 0
    reason="pending レビューの作成（event なしの create。submit はしない）"
    ;;
  *)
    exit 0
    ;;
esac

jq -n --arg r "$reason" '
  {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: $r
    }
  }
'
