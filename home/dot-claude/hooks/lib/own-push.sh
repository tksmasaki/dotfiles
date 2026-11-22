#!/usr/bin/env bash
# own-push.sh - 確認なしで通してよい git push かを判定する（source して使う）
#
# 使い方:
#   . ~/.claude/hooks/lib/claude-env.sh
#   . ~/.claude/hooks/lib/own-push.sh
#   own_push_allowed "$cmd" "$cwd" && reason="$OWN_PUSH_REASON"
#
# 判定に必要な情報が取れないときは、すべて「通さない」側に倒す。

OWN_PUSH_REASON=""

# hook の timeout は確認を出さずに通すため、その前に打ち切る（https://code.claude.com/docs/en/hooks#timeouts）
OWN_PUSH_GH_TIMEOUT=8

own_push_gh() {
  perl -e '
    my $limit = shift;
    my $pid = fork // exit 1;
    if ($pid == 0) { setpgrp(0, 0); exec @ARGV or exit 127 }
    $SIG{ALRM} = sub { kill "KILL", -$pid; exit 124 };
    alarm $limit;
    waitpid $pid, 0;
    exit($? & 127 ? 1 : $? >> 8);
  ' "$OWN_PUSH_GH_TIMEOUT" gh "$@"
}

own_push_authors_are() {
  local dir="$1" range="$2" email="$3" author
  while IFS= read -r author; do
    [ "$author" = "$email" ] || return 1
  done < <(git -C "$dir" log --format=%ae "$range" 2>/dev/null)
}

own_push_allowed() {
  local cmd="$1" dir="$2"
  local -a words
  local i=1 remote="" refspec="" force_with_lease="" upstream

  case "$cmd" in
    *[\;\&\|\`\$\(\)\<\>\"\'\\]* | *$'\n'*) return 1 ;;
  esac
  read -ra words <<<"$cmd"
  [ "${words[0]:-}" = git ] || return 1
  if [ "${words[1]:-}" = -C ]; then
    [ -n "${words[2]:-}" ] || return 1
    case "${words[2]}" in
      /*) dir="${words[2]}" ;;
      *) dir="$dir/${words[2]}" ;;
    esac
    i=3
  fi
  [ "${words[$i]:-}" = push ] || return 1

  for ((i = i + 1; i < ${#words[@]}; i++)); do
    case "${words[$i]}" in
      -u | --set-upstream | -q | --quiet) ;;
      --force-with-lease) force_with_lease=1 ;;
      -*) return 1 ;;
      *)
        if [ -z "$remote" ]; then
          remote="${words[$i]}"
        elif [ -z "$refspec" ]; then
          refspec="${words[$i]}"
        else
          return 1
        fi
        ;;
    esac
  done
  [ -z "$remote" ] || [ "$remote" = origin ] || return 1

  local auto_push
  auto_push="$(claude_env_current AGENT_AUTO_PUSH "$dir")" || return 1
  [ "$auto_push" = "1" ] || return 1

  local branch
  branch="$(git -C "$dir" symbolic-ref --short -q HEAD)" || return 1
  if [ -n "$refspec" ] && [ "$refspec" != HEAD ]; then
    case "$refspec" in
      *:* | +* | refs/*) return 1 ;;
    esac
    branch="$refspec"
  fi
  git -C "$dir" rev-parse --verify -q "refs/heads/$branch" >/dev/null || return 1
  if [ -z "$refspec" ]; then
    upstream="$(git -C "$dir" for-each-ref --format='%(upstream:short)' "refs/heads/$branch")" || return 1
    [ "$upstream" = "origin/$branch" ] || return 1
    [ -z "$(git -C "$dir" config --get-all remote.origin.push)" ] || return 1
    case "$(git -C "$dir" config --get push.default)" in
      '' | simple | current | upstream) ;;
      *) return 1 ;;
    esac
  fi
  if [ -z "$remote" ]; then
    local push_remote
    push_remote="$(git -C "$dir" config --get "branch.$branch.pushRemote" || git -C "$dir" config --get remote.pushDefault || true)"
    [ -z "$push_remote" ] || [ "$push_remote" = origin ] || return 1
  fi

  local default_branch
  default_branch="$(git -C "$dir" symbolic-ref --short -q refs/remotes/origin/HEAD)" || return 1
  default_branch="${default_branch#origin/}"
  [ "$branch" != "$default_branch" ] || return 1

  local me prs count base="$default_branch" pr_number="" pr_author others
  me="$(cd "$dir" && own_push_gh api user --jq .login 2>/dev/null)" || return 1
  [ -n "$me" ] || return 1
  prs="$(cd "$dir" && own_push_gh pr list --head "$branch" --state open --json number,baseRefName,author 2>/dev/null)" || return 1
  count="$(printf '%s' "$prs" | jq length)" || return 1
  case "$count" in
    0) ;;
    1)
      pr_number="$(printf '%s' "$prs" | jq -r '.[0].number')"
      pr_author="$(printf '%s' "$prs" | jq -r '.[0].author.login')"
      base="$(printf '%s' "$prs" | jq -r '.[0].baseRefName')"
      [ "$pr_author" = "$me" ] || return 1
      others="$(cd "$dir" && own_push_gh api --paginate "repos/{owner}/{repo}/pulls/$pr_number/reviews" \
        --jq ".[] | select(.user.type != \"Bot\" and .user.login != \"$me\") | .user.login" 2>/dev/null)" || return 1
      [ -z "$others" ] || return 1
      ;;
    *) return 1 ;;
  esac

  local email
  email="$(git -C "$dir" config user.email)" || return 1
  [ -n "$email" ] || return 1
  git -C "$dir" rev-parse --verify -q "refs/remotes/origin/$base" >/dev/null || return 1
  own_push_authors_are "$dir" "refs/remotes/origin/$base..refs/heads/$branch" "$email" || return 1
  if [ -n "$force_with_lease" ] && git -C "$dir" rev-parse --verify -q "refs/remotes/origin/$branch" >/dev/null; then
    own_push_authors_are "$dir" "refs/heads/$branch..refs/remotes/origin/$branch" "$email" || return 1
  fi

  OWN_PUSH_REASON="origin/${base} から ${branch} までのコミットが自分のものだけで、bot 以外の他者のレビューが無いため、確認なしで push する"
  [ -n "$pr_number" ] && OWN_PUSH_REASON="${OWN_PUSH_REASON}（PR #${pr_number}）"
  return 0
}
