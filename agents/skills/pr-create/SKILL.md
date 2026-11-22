---
name: pr-create
description: GitHub の PR を新しく作るときの手順。作る前の本文の草案・自己レビュー・動作確認、draft の扱い、ready に上げる条件、既定ブランチ以外を base にした PR の issue の紐付けを決める。「PR を作って」と言われたとき、PR を作る前、ユーザーに PR の作成を促す前に使う。
---

# PR を作る

本文の書き方と書き出し方は pr-description skill に従う。この skill は、作成のコマンドと作成の前後に行うことを決める。

## 1. 本文の草案を書く

pr-description skill の書き方で、概要・方針・関連する issue（`close` の行）を先にファイルへ書き出す。置き場所は作業ツリーの外（scratchpad など）にする。作業ツリーに置くと、自己レビューの差分や commit に混ざる。

## 2. 自己レビューする

review-code skill の手順でブランチ全体をレビューする。起点の資料（issue・US の URL、会話で決まった要件や方針）と、草案のファイルの絶対パスを渡す。差分のファイルがすべて、ドキュメント・テスト・CI の設定・型定義のどれかなら飛ばす。

返った指摘は区分ごとに扱う。

- must と should: 直してから次へ進む。直した変更の commit は commit-workflow skill に従い、草案の記述と食い違ったら草案も直す。直さないものは理由を残す。PR 全体にかかる理由は草案の備考の節に、diff の行にかかる理由は作成後にその行の行コメントに書く
- question: ユーザーに確かめる
- follow-up: ユーザーへの報告に書く

## 3. 変更を動かす

画面や挙動を変える PR は、変更を実際に動かして確かめる。作業ツリーの `.claude/skills/verify/SKILL.md` か `.agents/skills/verify/SKILL.md` を読んで従う。どちらも無ければ、メインの作業ツリー（`git worktree list` の先頭）のものを読む。確かめた事実は、pr-description skill の書き方で草案の動作確認の節に書く。skill が無いときや途中で確かめられなかったときは、確かめられなかったことをユーザーへの報告に書く。

## 4. draft で作る

`gh pr create --title <タイトル> --body-file <ファイル> --draft` で作る。草案にキャプチャがあれば、`~/.claude/references/github-attachments.md` に従って添付する。**`--draft` を既定にする。** ユーザーが draft にしないと指示したときだけ外す。**ready に上げるのもユーザーの指示を受けてから。** スコープ外の起票や行コメントは、作成の後に足すことが多い。draft なら、レビュワーに通知が飛ぶ前に足せる。

## 5. 既定ブランチ以外を base にしたら issue を紐付ける

base が既定ブランチ（`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`）でない PR では、本文の `close` キーワードで issue が Development に紐付かない。作成した直後に、閉じる issue ごとに GraphQL の `addCloseIssueReferences` で紐付け、最後のコマンドで issue 番号が返ることを確かめる。紐付けても、既定ブランチ以外へのマージでは issue は自動で閉じない。

```bash
ISSUE_ID=$(gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){issue(number:$n){id}}}' -f o=<owner> -f r=<repo> -F n=<issue 番号> --jq .data.repository.issue.id)
PR_ID=$(gh pr view <PR 番号> --json id -q .id)
gh api graphql -f query='mutation($i:ID!,$p:[ID!]!){addCloseIssueReferences(input:{issueId:$i,pullRequestIds:$p}){clientMutationId}}' -f i="$ISSUE_ID" -f p[]="$PR_ID"
gh pr view <PR 番号> --json closingIssuesReferences -q '[.closingIssuesReferences[].number]'
```
