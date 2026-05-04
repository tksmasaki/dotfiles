#!/bin/bash
IFS=$'\t' read -r MODEL PCT DIR FIVE_H WEEK < <(jq -r '[
    .model.display_name,
    (.context_window.used_percentage // 0 | floor),
    (.workspace.current_dir // ""),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.seven_day.used_percentage // "")
] | @tsv')

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

# Build progress bar: printf -v creates a run of spaces, then
# ${var// /▓} replaces each space with a block character
BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
EMPTY=$((BAR_WIDTH - FILLED))
if [ "$PCT" -ge 80 ]; then
	BAR_COLOR=$RED
elif [ "$PCT" -ge 50 ]; then
	BAR_COLOR=$YELLOW
else
	BAR_COLOR=$GREEN
fi
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${BAR_COLOR}${FILL// /▓}${RESET}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

LIMITS=""
[ -n "$FIVE_H" ] && LIMITS="5h: $(printf '%.0f' "$FIVE_H")%"
[ -n "$WEEK" ] && LIMITS="${LIMITS:+$LIMITS }7d: $(printf '%.0f' "$WEEK")%"

if git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
	[ -z "$BRANCH" ] && BRANCH=$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)
	read -r STAGED MODIFIED UNTRACKED < <(
		git -C "$DIR" status --porcelain --no-renames -uall 2>/dev/null | awk '
			/^\?\?/  { u++; next }
			/^[^ ?]/ { s++ }
			/^.[^ ]/ { m++ }
			END      { print s+0, m+0, u+0 }')

	GIT_STATUS=""
	[ "$STAGED" -gt 0 ] && GIT_STATUS="${GREEN}+${STAGED}${RESET}"
	[ "$MODIFIED" -gt 0 ] && GIT_STATUS="${GIT_STATUS}${YELLOW}~${MODIFIED}${RESET}"
	[ "$UNTRACKED" -gt 0 ] && GIT_STATUS="${GIT_STATUS}${RED}?${UNTRACKED}${RESET}"

	LOCATION="${DIR##*/} | $BRANCH${GIT_STATUS:+ $GIT_STATUS}"
else
	LOCATION="${DIR##*/}"
fi

STATUSLINE="[$MODEL] $LOCATION | $BAR $PCT%"
[ -n "$LIMITS" ] && STATUSLINE="$STATUSLINE | $LIMITS"
printf "%s\n" "$STATUSLINE"
