---
name: copilot-resolve
description: PR に付いた Copilot のレビューコメントに 1〜2 文で返信し、スレッドを resolve する。「Copilot のコメントに返信して resolve」「Copilot の指摘を resolve して」と言われたとき、/copilot-resolve で使う。人のレビューコメントは対象外。
argument-hint: "[PR 番号 or URL]（省略時は現在のブランチの PR）"
---

# Copilot のコメントに返信して resolve する

## 返信は 1〜2 文

1 文目に対応した結果か、対応しない判断を書く。理由が要るときだけ 2 文目に足す。前置き、謝辞、締めは書かない。直したなら該当コミットのハッシュを添える。

- 直した: `<hash> で <何を> <どう変えた>。`
- 直さない: `<理由> のため現状のままとする。`
- 別 issue: `この PR の範囲外なので #<番号> に切り出した。`

## 対象を取る

未 resolve のスレッドのうち、先頭コメントの `author.login` が `copilot` を含み、人の返信が付いていないものだけを対象にする。人が起こしたスレッドは触らない。

```bash
gh api graphql -F o=<owner> -F r=<repo> -F n=<番号> -f query='
query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){
  reviewThreads(first:100){nodes{id isResolved isOutdated
    comments(first:30){nodes{databaseId author{login} path line body url}}}}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | select(.isResolved|not)
        | select(.comments.nodes[0].author.login | test("copilot";"i"))
        | select([.comments.nodes[1:][] | select(.author.login | test("copilot";"i") | not)] | length == 0)'
```

## 返信して resolve する

各スレッドの先頭コメントの `databaseId` に REST で返信し、GraphQL の `resolveReviewThread` で閉じる。返信が複数行ならファイルに書いて `--input` で渡す。

```bash
gh api repos/<owner>/<repo>/pulls/<番号>/comments/<databaseId>/replies -f body='<返信>'
gh api graphql -F id=<thread id> -f query='
mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}'
```

判断が付かない指摘は返信も resolve もせず、ユーザーに上げる。

## 報告

返信して resolve した件数と、残したスレッドとその理由を 1 行ずつ書く。返信文を本文に再掲しない。
