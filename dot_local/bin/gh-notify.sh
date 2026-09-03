#!/bin/bash
#
# gh-notify.sh
#
# GitHub の未読通知を gh CLI でポーリングし、前回チェックから新しくなった
# スレッドだけを macOS のデスクトップ通知で知らせる
#
# - 状態: 通知 ID -> updated_at の対応表を STATE_FILE に保存し、ID の新規出現と
#          updated_at の更新の両方を新着とみなす
# - 認証: gh CLI の既存ログインセッション(keyring)をそのまま利用する
#          (トークン等はこのスクリプトに一切ハードコードしない)
# - ログ: 正常・エラーいずれも LOG_FILE に追記する(エラーは握り潰さない)
# - 失敗: 連続失敗が続いたらデスクトップ通知を出し、沈黙したまま止まらないようにする
# - 除外: CI(CheckSuite / ci_activity)は PR 側の通知と重複するので取り込まない
# - 冪等: 何度呼ばれても状態ファイルとの差分だけを通知するので副作用が重複しない

set -u

# ---- 設定 ---------------------------------------------------------------
CACHE_DIR="${GH_NOTIFY_CACHE_DIR:-${HOME}/.cache/gh-notify}"
STATE_FILE="${CACHE_DIR}/last_seen.json"    # 通知 ID -> updated_at
FAIL_FILE="${CACHE_DIR}/fail_count"         # 連続失敗回数
LOG_FILE="${CACHE_DIR}/gh-notify.log"
MAX_LOG_BYTES=1048576                       # 1MB を超えたらローテート
FAIL_NOTIFY_AT=2                            # この回数の連続失敗で通知
FAIL_NOTIFY_EVERY=8                         # 以降はこの回数ごとに再通知
NOTIFICATIONS_URL="https://github.com/notifications"

# launchd から起動されると PATH が最小限(/usr/bin:/bin 等)になるため、
# gh(mise 管理)と osascript を確実に解決できるよう PATH を補う
export PATH="${HOME}/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

# ---- ユーティリティ -----------------------------------------------------
log() {
  # ログを追記。日時付き。ISO 8601 のローカル時刻
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

# gh の実体を解決する。mise shim は mise 本体が要るので、まず PATH 上の gh を
# 使い、無ければ mise の直接インストールパスをフォールバックで探す
resolve_gh() {
  if command -v gh >/dev/null 2>&1; then
    command -v gh
    return 0
  fi
  local candidate
  candidate=$(ls -d "${HOME}"/.local/share/mise/installs/gh/*/gh_*/bin/gh 2>/dev/null | sort | tail -n 1)
  if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
    printf '%s\n' "${candidate}"
    return 0
  fi
  return 1
}

# AppleScript の文字列リテラルとして解釈されるので、
# バックスラッシュをダブルクォートより先にエスケープする
escape_applescript() {
  local escaped="${1//\\/\\\\}"
  printf '%s\n' "${escaped//\"/\\\"}"
}

# デスクトップ通知を出す。terminal-notifier があれば優先、無ければ osascript。
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

# 通知の見出し。API の reason をそのまま出しても何を求められているか読めないため
reason_label() {
  case "$1" in
    review_requested) printf 'レビュー依頼\n' ;;
    assign) printf 'アサイン\n' ;;
    mention) printf 'メンション\n' ;;
    team_mention) printf 'チームへのメンション\n' ;;
    author) printf '自分のスレッドに動き\n' ;;
    comment) printf 'コメント\n' ;;
    state_change) printf '状態変更\n' ;;
    approval_requested) printf '承認依頼\n' ;;
    security_alert) printf 'セキュリティアラート\n' ;;
    subscribed) printf '購読リポジトリの更新\n' ;;
    manual) printf '購読中のスレッド\n' ;;
    invitation) printf '招待\n' ;;
    *) printf '%s\n' "${1:-通知}" ;;
  esac
}

type_label() {
  case "$1" in
    PullRequest) printf 'PR\n' ;;
    Issue) printf 'Issue\n' ;;
    Discussion) printf 'ディスカッション\n' ;;
    Release) printf 'リリース\n' ;;
    Commit) printf 'コミット\n' ;;
    RepositoryVulnerabilityAlert) printf '脆弱性アラート\n' ;;
    *) printf '%s\n' "$1" ;;
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

read_fail_count() {
  local count=0
  [ -f "${FAIL_FILE}" ] && count=$(cat "${FAIL_FILE}" 2>/dev/null || echo 0)
  case "${count}" in
    '' | *[!0-9]*) count=0 ;;
  esac
  printf '%s\n' "${count}"
}

# 失敗を記録して終了する。1 回きりのネットワーク断で通知しないよう、
# FAIL_NOTIFY_AT 回目で初めて通知し、以降は FAIL_NOTIFY_EVERY 回ごとに再通知する
fail() {
  local reason="$1" count
  count=$(($(read_fail_count) + 1))
  printf '%s' "${count}" >"${FAIL_FILE}" 2>/dev/null || true
  log "ERROR ${reason} (連続失敗 ${count} 回目)"
  if [ "${count}" -eq "${FAIL_NOTIFY_AT}" ] ||
     { [ "${count}" -gt "${FAIL_NOTIFY_AT}" ] && [ $((count % FAIL_NOTIFY_EVERY)) -eq 0 ]; }; then
    notify "gh-notify が失敗しています" "GitHub の通知を取得できていません" \
      "${reason} (連続 ${count} 回)" "" "gh-notify-status"
  fi
  exit 1
}

clear_failure() {
  local count
  count=$(read_fail_count)
  rm -f "${FAIL_FILE}"
  if [ "${count}" -ge "${FAIL_NOTIFY_AT}" ]; then
    log "INFO 連続失敗 ${count} 回の後に復旧"
    notify "gh-notify が復旧しました" "" \
      "連続 ${count} 回の失敗の後に成功しました" "" "gh-notify-status"
  fi
}

# 状態は通知を送り終えてから保存する。途中で中断した場合は保存しないことで、
# 取りこぼすより重複して通知する側に倒す
save_state() {
  printf '%s' "$1" >"${STATE_FILE}" 2>/dev/null ||
    fail "状態ファイルの書き込みに失敗: ${STATE_FILE}"
}

# ---- メイン -------------------------------------------------------------
main() {
  mkdir -p "${CACHE_DIR}"
  rotate_log_if_needed

  local GH
  GH=$(resolve_gh) || fail "gh コマンドが見つからない (PATH=${PATH})"

  command -v jq >/dev/null 2>&1 || fail "jq コマンドが見つからない"

  # 認証状態を確認(トークンは出力しない)
  "${GH}" auth status >/dev/null 2>&1 ||
    fail "gh 未認証、または認証切れ。'gh auth login' を実行してください"

  # 未読通知を取得。gh api の失敗(ネットワーク等)は握り潰さずログに残す
  local raw stderr_file
  stderr_file=$(mktemp "${TMPDIR:-/tmp}/gh-notify.err.XXXXXX")
  if ! raw=$("${GH}" api notifications \
        --jq '[.[] | select(.subject.type != "CheckSuite" and .reason != "ci_activity") | {id: .id, title: .subject.title, type: .subject.type, repo: .repository.full_name, reason: .reason, updated_at: .updated_at, url: .subject.url}]' \
        2>"${stderr_file}"); then
    local err
    err=$(tr '\n' ' ' <"${stderr_file}")
    rm -f "${stderr_file}"
    fail "gh api notifications 失敗: ${err}"
  fi
  rm -f "${stderr_file}"

  # 空(未読なし)の場合は [] が返る
  [ -z "${raw}" ] && raw="[]"

  local current
  current=$(printf '%s' "${raw}" |
    jq 'map({key: .id, value: (.updated_at // "")}) | from_entries' 2>/dev/null) ||
    fail "通知 JSON のパースに失敗"

  # 前回の状態を読む。旧形式(ID の配列)は現在の updated_at で埋めて移行し、
  # 移行時に既存の通知が新着として再通知されないようにする
  local prev="{}" first_run=0
  if [ -f "${STATE_FILE}" ]; then
    prev=$(jq --argjson current "${current}" \
      'if type == "array" then (map({key: ., value: ($current[.] // "")}) | from_entries) else . end' \
      "${STATE_FILE}" 2>/dev/null) || {
      log "WARN 状態ファイルを読めないので初回扱いにする: ${STATE_FILE}"
      prev="{}"
      first_run=1
    }
  else
    first_run=1
  fi

  # 新着 = ID が前回に無い、または updated_at が前回と違うもの
  local changed_ids
  changed_ids=$(printf '%s' "${current}" | jq -r --argjson prev "${prev}" \
    'to_entries | map(select($prev[.key] != .value)) | .[].key') ||
    fail "通知の差分計算に失敗"

  clear_failure

  if [ "${first_run}" -eq 1 ]; then
    local count
    count=$(printf '%s' "${current}" | jq -r 'length')
    save_state "${current}"
    log "INFO 初回実行。既存の未読通知 ${count} 件を基準として記録(通知は出さない)"
    exit 0
  fi

  # 新着が無ければ静かに終了(ログのみ)。既読になったスレッドを落とすため状態は更新する
  if [ -z "${changed_ids}" ]; then
    save_state "${current}"
    log "INFO 新規通知なし"
    exit 0
  fi

  local notified=0
  while IFS= read -r id; do
    [ -z "${id}" ] && continue
    local item repo title type reason api_url state heading subtitle number
    item=$(printf '%s' "${raw}" | jq -c --arg id "${id}" '.[] | select(.id==$id)')
    repo=$(printf '%s' "${item}" | jq -r '.repo // "unknown"')
    title=$(printf '%s' "${item}" | jq -r '.title // "(no title)"')
    type=$(printf '%s' "${item}" | jq -r '.type // ""')
    reason=$(printf '%s' "${item}" | jq -r '.reason // ""')
    api_url=$(printf '%s' "${item}" | jq -r '.url // ""')

    if printf '%s' "${prev}" | jq -e --arg id "${id}" 'has($id)' >/dev/null 2>&1; then
      state=updated
    else
      state=new
    fi

    heading=$(reason_label "${reason}")
    if [ "${state}" = updated ]; then
      heading="${heading}(更新)"
    fi
    number=$(subject_number "${api_url}")
    subtitle="$(type_label "${type}")"
    if [ -n "${number}" ]; then
      subtitle="${subtitle} #${number}"
    fi
    subtitle="$(printf '%s %s' "${subtitle}" "${repo}" | sed -E 's/^ +//')"

    notify "${heading}" "${subtitle}" "${title}" "$(to_html_url "${api_url}")" "gh-notify-${id}"
    log "NOTIFY id=${id} state=${state} repo=${repo} type=${type} reason=${reason} title=${title}"
    notified=$((notified + 1))
  done <<<"${changed_ids}"

  save_state "${current}"
  log "INFO 新規通知 ${notified} 件を通知しました"
  exit 0
}

main "$@"
