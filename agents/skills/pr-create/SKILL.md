---
name: pr-create
description: GitHub の PR を新しく作るときの手順。draft の扱い、ready に上げる条件、既定ブランチ以外を base にした PR の issue の紐付けを決める。「PR を作って」と言われたとき、`gh pr create` を実行する前、ユーザーに PR の作成を促す前に使う。
---

# PR を作る

本文の書き方と書き出し方は pr-description skill に従う。この skill は、作成のコマンドと作成の前後に行うことを決める。

## draft で作る

`gh pr create --title <タイトル> --body-file <ファイル> --draft` で作る。**`--draft` を既定にする。** ユーザーが draft にしないと指示したときだけ外す。**ready に上げるのもユーザーの指示を受けてから。** 作成の時点では動作確認やスコープ外の起票が済んでいないことが多い。draft なら、レビュワーに通知が飛ぶ前に足せる。
## 既定ブランチ以外を base にしたら issue を紐付ける

base が既定ブランチ（`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`）でない PR では、本文の `close` キーワードで issue が Development に紐付かない。作成した直後に、閉じる issue ごとに GraphQL の `addCloseIssueReferences` で紐付け、最後のコマンドで issue 番号が返ることを確かめる。紐付けても、既定ブランチ以外へのマージでは issue は自動で閉じない。

```bash
ISSUE_ID=$(gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){issue(number:$n){id}}}' -f o=<owner> -f r=<repo> -F n=<issue 番号> --jq .data.repository.issue.id)
PR_ID=$(gh pr view <PR 番号> --json id -q .id)
gh api graphql -f query='mutation($i:ID!,$p:[ID!]!){addCloseIssueReferences(input:{issueId:$i,pullRequestIds:$p}){clientMutationId}}' -f i="$ISSUE_ID" -f p[]="$PR_ID"
gh pr view <PR 番号> --json closingIssuesReferences -q '[.closingIssuesReferences[].number]'
```
