#!/bin/bash
#
# gh-notify.sh
#
# GitHub の未読通知を gh CLI でポーリングし、メンション・レビュー依頼・自分の PR への
# レビューだけを macOS のデスクトップ通知で知らせる
#
# - 自分の PR の通知は reason が assign や author になり、コミットや CI の度にも届くため、
#   reason ではなくレビュー一覧(インラインコメントとその返信を含む)で判定する
# - 既読にしたスレッドも STATE_RETENTION_SECONDS のあいだ状態に残す。残さないと、
#   既読後に別の動きで未読へ戻ったスレッドを新着と誤認して再通知する

set -u

# ---- 設定 ---------------------------------------------------------------
CACHE_DIR="${GH_NOTIFY_CACHE_DIR:-${HOME}/.cache/gh-notify}"
STATE_FILE="${CACHE_DIR}/state.json"
FAIL_FILE="${CACHE_DIR}/fail_count"
LOG_FILE="${CACHE_DIR}/gh-notify.log"
MAX_LOG_BYTES=1048576
FAIL_NOTIFY_AT=2
FAIL_NOTIFY_EVERY=8
STATE_RETENTION_SECONDS=$((30 * 24 * 60 * 60))
NOTIFICATIONS_URL="https://github.com/notifications"
NOTIFY_REASONS='["mention","team_mention","review_requested"]'

# launchd から起動されると PATH が最小限(/usr/bin:/bin 等)になるため、
# gh(mise 管理)と terminal-notifier(Homebrew)を解決できるよう PATH を補う
export PATH="${HOME}/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

# ---- ユーティリティ -----------------------------------------------------
log() {
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >>"${LOG_FILE}"
}

rotate_log_if_needed() {
  [ -f "${LOG_FILE}" ] || return 0
  local size
  size=$(stat -f%z "${LOG_FILE}" 2>/dev/null || echo 0)
  if [ "${size}" -gt "${MAX_LOG_BYTES}" ]; then
    mv -f "${LOG_FILE}" "${LOG_FILE}.1" 2>/dev/null || true
  fi
}

# AppleScript の文字列リテラルとして解釈されるので、
# バックスラッシュをダブルクォートより先にエスケープする
escape_applescript() {
  local escaped="${1//\\/\\\\}"
  printf '%s\n' "${escaped//\"/\\\"}"
}

# group は同じ値の通知を上書きするので、スレッドごとに別の値を渡すこと
notify() {
  local title="$1" subtitle="$2" message="$3"
  local url="${4:-${NOTIFICATIONS_URL}}" group="${5:-gh-notify}"

  if command -v terminal-notifier >/dev/null 2>&1; then
    # terminal-notifier は先頭の [ をオプションと誤認するためエスケープが要る。
    # osascript ではこのエスケープが構文エラーになるのでここでだけ施す
    local tn_message="${message}"
    case "${tn_message}" in
      '['*) tn_message="\\${tn_message}" ;;
    esac
    terminal-notifier -title "${title}" -subtitle "${subtitle}" -message "${tn_message}" \
      -group "${group}" -open "${url}" >/dev/null 2>&1
    return
  fi
  local esc_title esc_subtitle esc_message
  esc_title=$(escape_applescript "${title}")
  esc_subtitle=$(escape_applescript "${subtitle}")
  esc_message=$(escape_applescript "${message}")
  if [ -n "${esc_subtitle}" ]; then
    osascript -e "display notification \"${esc_message}\" with title \"${esc_title}\" subtitle \"${esc_subtitle}\"" >/dev/null 2>&1
  else
    osascript -e "display notification \"${esc_message}\" with title \"${esc_title}\"" >/dev/null 2>&1
  fi
}

reason_label() {
  case "$1" in
    review_requested) printf 'Review request\n' ;;
    mention) printf 'Mention\n' ;;
    team_mention) printf 'Team mention\n' ;;
    *) printf '%s\n' "${1:-Notification}" ;;
  esac
}

subject_number() {
  case "$1" in
    https://api.github.com/repos/*/pulls/[0-9]* | https://api.github.com/repos/*/issues/[0-9]*)
      printf '%s\n' "${1##*/}"
      ;;
    *) printf '\n' ;;
  esac
}

# subject.url は API のエンドポイント。CheckSuite や Discussion では null になり、
# Release では番号と tag 名がずれて Web 側の URL にならないため、
# PullRequest と Issue だけを変換して残りは通知一覧に送る
to_html_url() {
  local api_url="$1" path
  case "${api_url}" in
    https://api.github.com/repos/*/pulls/[0-9]*)
      path=${api_url#https://api.github.com/repos/}
      printf 'https://github.com/%s/pull/%s\n' "${path%%/pulls/*}" "${path##*/pulls/}"
      ;;
    https://api.github.com/repos/*/issues/[0-9]*)
      printf 'https://github.com/%s\n' "${api_url#https://api.github.com/repos/}"
      ;;
    *)
      printf '%s\n' "${NOTIFICATIONS_URL}"
      ;;
  esac
}

notification_subtitle() {
  local api_url="$1" repo="$2" number
  number=$(subject_number "${api_url}")
  if [ -n "${number}" ]; then
    printf '%s#%s\n' "${repo#*/}" "${number}"
  else
    printf '%s\n' "${repo#*/}"
  fi
}

# PR の作成者が me なら、me 以外のレビューを古い順に「ID<TAB>submitted_at<TAB>login<TAB>state」で出力する
reviews_by_others() {
  local api_url="$1" me="$2" path author reviews
  path=${api_url#https://api.github.com/}
  author=$("${GH}" api "${path}" --jq '.user.login') || return 1
  [ "${author}" = "${me}" ] || return 0
  reviews=$("${GH}" api --paginate "${path}/reviews?per_page=100" \
    --jq '.[] | [.id, .submitted_at, .user.login, .state] | @tsv') || return 1
  printf '%s\n' "${reviews}" | awk -F '\t' -v me="${me}" '$3 != me && $2 != ""'
}

# prev_review_id より後で、かつ既読より後のレビューを「login state, ...」にまとめる。
# 既読より前のものは Web で確認済みとみなす
summarize_new_reviews() {
  local reviews="$1" prev_review_id="$2" last_read_at="$3"
  printf '%s\n' "${reviews}" | awk -F '\t' -v prev="${prev_review_id}" -v read_at="${last_read_at}" '
    NF { n++; id[n] = $1; at[n] = $2; who[n] = $3; st[n] = $4; if ($1 == prev) start = n }
    END {
      for (i = start + 1; i <= n; i++) {
        if (at[i] "" <= read_at "") continue
        if (!(who[i] in latest)) order[++m] = who[i]
        s = tolower(st[i]); gsub(/_/, " ", s); latest[who[i]] = s
      }
      for (j = 1; j <= m; j++) printf "%s%s %s", (j > 1 ? ", " : ""), order[j], latest[order[j]]
    }'
}

issue_api_path() {
  local path=${1#https://api.github.com/}
  case "${path}" in
    */pulls/*) printf '%s/issues/%s\n' "${path%/pulls/*}" "${path##*/pulls/}" ;;
    *) printf '%s\n' "${path}" ;;
  esac
}

# 戻り値: 0 = since より後に me へのレビュー依頼がある / 1 = 無い / 2 = 取得に失敗。
# チームへの依頼は、自分が所属するかを確かめずに対象とみなす
has_review_request_since() {
  local api_url="$1" me="$2" since="$3" events
  events=$("${GH}" api --paginate "$(issue_api_path "${api_url}")/timeline?per_page=100" \
    --jq '.[] | select(.event == "review_requested") | [.created_at, (.requested_reviewer.login // "@team")] | @tsv') ||
    return 2
  printf '%s\n' "${events}" | awk -F '\t' -v me="${me}" -v since="${since}" '
    $1 "" > since "" && ($2 == me || $2 == "@team") { found = 1 }
    END { exit !found }'
}

# 戻り値: 0 = since より後に更新されたコメントにメンションがある / 1 = 無い / 2 = 取得に失敗。
# PR・Issue 本文やレビュー本文の編集によるメンションは見ない
has_mention_since() {
  local api_url="$1" me="$2" since="$3" reason="$4" pattern endpoints hits endpoint
  if [ "${reason}" = team_mention ]; then
    pattern='@[A-Za-z0-9-]+/[A-Za-z0-9_.-]+'
  else
    pattern="@${me}([^A-Za-z0-9-]|$)"
  fi
  endpoints="$(issue_api_path "${api_url}")/comments"
  case "${api_url}" in
    */pulls/*) endpoints="${endpoints} ${api_url#https://api.github.com/}/comments" ;;
  esac
  for endpoint in ${endpoints}; do
    hits=$("${GH}" api --paginate "${endpoint}?since=${since}&per_page=100" \
      --jq ".[] | select((.body // \"\") | test(\"${pattern}\"; \"i\")) | .id") || return 2
    [ -n "${hits}" ] && return 0
  done
  return 1
}

read_fail_count() {
  local count=0
  [ -f "${FAIL_FILE}" ] && count=$(cat "${FAIL_FILE}" 2>/dev/null || echo 0)
  case "${count}" in
    '' | *[!0-9]*) count=0 ;;
  esac
  printf '%s\n' "${count}"
}

# 1 回きりのネットワーク断で通知しないよう、FAIL_NOTIFY_AT 回目で初めて通知し、
# 以降は FAIL_NOTIFY_EVERY 回ごとに再通知する
fail() {
  local reason="$1" count
  count=$(($(read_fail_count) + 1))
  printf '%s' "${count}" >"${FAIL_FILE}" 2>/dev/null || true
  log "ERROR ${reason} (連続失敗 ${count} 回目)"
  if [ "${count}" -eq "${FAIL_NOTIFY_AT}" ] ||
     { [ "${count}" -gt "${FAIL_NOTIFY_AT}" ] && [ $((count % FAIL_NOTIFY_EVERY)) -eq 0 ]; }; then
    notify "gh-notify failing" "Cannot fetch notifications" \
      "${reason} (${count} in a row)" "" "gh-notify-status"
  fi
  exit 1
}

clear_failure() {
  local count
  count=$(read_fail_count)
  rm -f "${FAIL_FILE}"
  if [ "${count}" -ge "${FAIL_NOTIFY_AT}" ]; then
    log "INFO 連続失敗 ${count} 回の後に復旧"
    notify "gh-notify recovered" "" \
      "After ${count} failures" "" "gh-notify-status"
  fi
}

# 状態は通知を送り終えてから保存する。途中で中断した場合は保存しないことで、
# 取りこぼすより重複して通知する側に倒す。
# 書き込み途中で止まると JSON が壊れて次回が初回扱いになるため、置き換えで書く
save_state() {
  local tmp
  tmp=$(mktemp "${STATE_FILE}.XXXXXX") || fail "状態ファイルの一時ファイルを作れない: ${STATE_FILE}"
  if ! printf '%s' "$1" >"${tmp}" || ! mv -f "${tmp}" "${STATE_FILE}"; then
    rm -f "${tmp}"
    fail "状態ファイルの書き込みに失敗: ${STATE_FILE}"
  fi
}

# ---- メイン -------------------------------------------------------------
main() {
  mkdir -p "${CACHE_DIR}"
  rotate_log_if_needed

  local GH
  GH=$(command -v gh) || fail "gh コマンドが見つからない (PATH=${PATH})"

  command -v jq >/dev/null 2>&1 || fail "jq コマンドが見つからない"

  local now
  now=$(date +%s)

  local pages stderr_file
  stderr_file=$(mktemp "${TMPDIR:-/tmp}/gh-notify.err.XXXXXX")
  if ! pages=$("${GH}" api --paginate --slurp 'notifications?per_page=50' 2>"${stderr_file}"); then
    local err
    err=$(tr '\n' ' ' <"${stderr_file}")
    rm -f "${stderr_file}"
    fail "gh api notifications 失敗: ${err}"
  fi
  rm -f "${stderr_file}"

  local all raw prs
  all=$(printf '%s' "${pages}" | jq -c 'add // [] | map({id, title: .subject.title, type: .subject.type, repo: .repository.full_name, reason, url: .subject.url, updated_at, last_read_at})') ||
    fail "通知 JSON のパースに失敗"
  raw=$(printf '%s' "${all}" | jq -c --argjson reasons "${NOTIFY_REASONS}" \
    'map(select(.reason as $reason | $reasons | index($reason)))') ||
    fail "通知の絞り込みに失敗"
  prs=$(printf '%s' "${all}" | jq -c 'map(select(.type == "PullRequest"))') ||
    fail "通知の絞り込みに失敗"

  # 状態は「reason:<ID>」と「review:<ID>」をキーに {v: 値, read: last_read_at, seen: 最後に未読で見た時刻}
  # を持つ。自分の PR がメンションされたときは両方のキーを持つ
  local prev="{}" first_run=0 state_unreadable=0
  if [ -f "${STATE_FILE}" ]; then
    prev=$(jq -ce 'select(type == "object")' "${STATE_FILE}" 2>/dev/null) || {
      log "WARN 状態ファイルを読めないので初回扱いにする: ${STATE_FILE}"
      prev="{}"
      first_run=1
      state_unreadable=1
    }
  else
    first_run=1
  fi

  local current
  current=$(printf '%s' "${raw}" |
    jq 'map({key: ("reason:" + .id), value: {v: (.reason // ""), read: .last_read_at}}) | from_entries') ||
    fail "通知 JSON のパースに失敗"

  local changed_ids
  changed_ids=$(printf '%s' "${current}" | jq -r --argjson prev "${prev}" \
    'to_entries | map(select($prev[.key].v != .value.v)) | .[].key | ltrimstr("reason:")') ||
    fail "通知の差分計算に失敗"

  # 既読にした後で未読に戻ったスレッドは、コミットなど無関係な動きでも戻るため、
  # 既読より後に再依頼やメンションがあったときだけ通知する
  local me="" returned_ids
  returned_ids=$(printf '%s' "${current}" | jq -r --argjson prev "${prev}" \
    'to_entries
     | map(select(.value.read != null and ($prev[.key] | has("read")?) and $prev[.key].v == .value.v
                  and $prev[.key].read != .value.read))
     | .[].key | ltrimstr("reason:")') ||
    fail "通知の差分計算に失敗"
  while IFS= read -r id; do
    [ -z "${id}" ] && continue
    local item reason api_url since found
    item=$(printf '%s' "${raw}" | jq -c --arg id "${id}" '.[] | select(.id==$id)')
    reason=$(printf '%s' "${item}" | jq -r '.reason // ""')
    api_url=$(printf '%s' "${item}" | jq -r '.url // ""')
    since=$(printf '%s' "${item}" | jq -r '.last_read_at // ""')
    [ -n "${api_url}" ] || continue
    if [ -z "${me}" ]; then
      me=$("${GH}" api user --jq '.login') || fail "gh api user 失敗"
    fi
    if [ "${reason}" = review_requested ]; then
      has_review_request_since "${api_url}" "${me}" "${since}"
    else
      has_mention_since "${api_url}" "${me}" "${since}" "${reason}"
    fi
    found=$?
    case "${found}" in
      0) changed_ids+=$'\n'"${id}" ;;
      1) ;;
      *)
        log "WARN 再依頼・メンションの確認に失敗したので次回に再試行する: ${api_url}"
        current=$(printf '%s' "${current}" | jq --arg key "reason:${id}" --argjson prev "${prev}" \
          '.[$key].read = $prev[$key].read') || fail "状態の組み立てに失敗"
        ;;
    esac
  done <<<"${returned_ids}"

  # タブは IFS の空白扱いで空欄が詰まるため、一度も読んでいない(null の) last_read_at には "0" を入れる
  local review_notices=""
  while IFS=$'\t' read -r id updated_at last_read_at api_url; do
    [ -z "${id}" ] && continue
    local prev_val val reviews latest_review_id prev_review_id summary
    prev_val=$(printf '%s' "${prev}" | jq -r --arg key "review:${id}" '.[$key].v // ""')
    case "${prev_val}" in
      "${updated_at}|"*) val="${prev_val}" ;;
      *)
        reviews=""
        if [ -n "${api_url}" ]; then
          if [ -z "${me}" ]; then
            me=$("${GH}" api user --jq '.login') || fail "gh api user 失敗"
          fi
          # 1 件の PR で失敗し続けても他の通知を止めないよう、この PR だけ次回に再試行する
          if ! reviews=$(reviews_by_others "${api_url}" "${me}"); then
            log "WARN PR のレビュー取得に失敗したので次回に再試行する: ${api_url}"
            current=$(printf '%s' "${current}" | jq --arg key "review:${id}" --arg v "${prev_val}" '.[$key] = {v: $v}') ||
              fail "状態の組み立てに失敗"
            continue
          fi
        fi
        latest_review_id=$(printf '%s\n' "${reviews}" | awk -F '\t' 'NF { last = $1 } END { print last }')
        val="${updated_at}|${latest_review_id}"
        prev_review_id="${prev_val#*|}"
        summary=$(summarize_new_reviews "${reviews}" "${prev_review_id}" "${last_read_at}")
        if [ -n "${summary}" ]; then
          review_notices+="${id}"$'\t'"${summary}"$'\n'
        fi
        ;;
    esac
    current=$(printf '%s' "${current}" | jq --arg key "review:${id}" --arg v "${val}" '.[$key] = {v: $v}') ||
      fail "状態の組み立てに失敗"
  done < <(printf '%s' "${prs}" |
    jq -r '.[] | [.id, .updated_at, (.last_read_at // "0"), (.url // "")] | @tsv')

  local next_state
  next_state=$(jq -n --argjson prev "${prev}" --argjson cur "${current}" \
    --argjson now "${now}" --argjson keep "${STATE_RETENTION_SECONDS}" \
    '($prev | with_entries(select((.value.seen // 0) >= $now - $keep)))
     + ($cur | map_values(. + {seen: $now}))') ||
    fail "状態の組み立てに失敗"

  clear_failure

  if [ "${first_run}" -eq 1 ]; then
    save_state "${next_state}"
    log "INFO 初回実行。既存の未読通知 $(printf '%s' "${all}" | jq -r 'length') 件を基準として記録(通知は出さない)"
    # 保存より前に出すと、保存に失敗し続けたとき毎分通知が出る
    if [ "${state_unreadable}" -eq 1 ]; then
      notify "gh-notify reset" "" "State file was unreadable; current notifications set as baseline" \
        "" "gh-notify-status"
    fi
    exit 0
  fi

  if [ -z "${changed_ids}" ] && [ -z "${review_notices}" ]; then
    save_state "${next_state}"
    log "INFO 新規通知なし"
    exit 0
  fi

  local notified=0
  while IFS= read -r id; do
    [ -z "${id}" ] && continue
    local item repo title type reason api_url state heading
    item=$(printf '%s' "${raw}" | jq -c --arg id "${id}" '.[] | select(.id==$id)')
    repo=$(printf '%s' "${item}" | jq -r '.repo // "unknown"')
    title=$(printf '%s' "${item}" | jq -r '.title // "(no title)"')
    type=$(printf '%s' "${item}" | jq -r '.type // ""')
    reason=$(printf '%s' "${item}" | jq -r '.reason // ""')
    api_url=$(printf '%s' "${item}" | jq -r '.url // ""')

    heading=$(reason_label "${reason}")
    if printf '%s' "${prev}" | jq -e --arg key "reason:${id}" 'has($key)' >/dev/null; then
      state=updated
      heading="${heading} (re)"
    else
      state=new
    fi

    notify "${heading}" "$(notification_subtitle "${api_url}" "${repo}")" "${title}" \
      "$(to_html_url "${api_url}")" "gh-notify-${id}"
    log "NOTIFY id=${id} state=${state} repo=${repo} type=${type} reason=${reason} title=${title}"
    notified=$((notified + 1))
  done <<<"${changed_ids}"

  while IFS=$'\t' read -r id summary; do
    [ -z "${id}" ] && continue
    local item repo title api_url
    item=$(printf '%s' "${prs}" | jq -c --arg id "${id}" '.[] | select(.id==$id)')
    repo=$(printf '%s' "${item}" | jq -r '.repo // "unknown"')
    title=$(printf '%s' "${item}" | jq -r '.title // "(no title)"')
    api_url=$(printf '%s' "${item}" | jq -r '.url // ""')

    notify "Review" "$(notification_subtitle "${api_url}" "${repo}")" "${summary}: ${title}" \
      "$(to_html_url "${api_url}")" "gh-notify-review-${id}"
    log "NOTIFY id=${id} state=review repo=${repo} reviews=${summary} title=${title}"
    notified=$((notified + 1))
  done <<<"${review_notices}"

  save_state "${next_state}"
  log "INFO 新規通知 ${notified} 件を通知しました"
  exit 0
}

main "$@"
