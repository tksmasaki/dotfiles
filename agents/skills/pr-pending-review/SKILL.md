---
name: pr-pending-review
description: レビューの指摘を、GitHub の PR の pending レビューに行コメントとしてまとめて置く。1 回のリクエストで全件を置き、submit はしない。「指摘を PR に置いて」「pending レビューに置いて」と言われたとき、pr-review の -p、review-code や別のレビューの結果を PR に置くときに使う。
argument-hint: "[PR URL か番号]（省略時はカレントブランチの PR）"
---

# 指摘を pending レビューに置く（pr-pending-review）

**submit しない。** pending の間はレビューした本人にしか見えず、作者には届かない。submit は、ユーザーが GitHub で内容を確かめてから行う。

コメントは REST API の「Create a review for a pull request」で、1 回のリクエストでまとめて置く。`event` を省くと pending になる（[GitHub Docs](https://docs.github.com/en/rest/pulls/reviews#create-a-review-for-a-pull-request): "To create a pending review for a pull request, leave the event parameter blank."）。コメントを 1 件ずつ足すツールは、1 件ごとに承認を求められることがあるので使わない。

## 受け取るもの

- PR: URL か番号。
- 指摘を出したときの head の SHA。分からなければ、置く直前に取った値を使い、指摘がその版のコードを見たものかをユーザーに確かめる。
- 指摘の一覧。各件に区分（must / should / question / nit / follow-up）、場所（`<パス>:<行>` か行の範囲）、本文の材料。

## 手順

### 1. 置くものを決める

差分に無いファイル、PR 本文、issue への指摘は置かない。出力の「置けなかったコメント」に回す。

同じ箇所で同じ直し方になる指摘は 1 件にまとめる。

### 2. head と既存の pending レビューを確かめる

```bash
gh pr view <PR> --json number,headRefOid,url
gh api --paginate repos/{owner}/{repo}/pulls/<番号>/reviews --jq '.[] | select(.state=="PENDING") | {id, commit_id}'
```

- `headRefOid` が受け取った SHA と違えば置かない。指摘の行がずれている可能性があるので、本文と行を出力し、レビューのやり直しを「次にすること」に書く。
- 自分の pending レビューが既にあれば置かない。GitHub では pending レビューを 1 人 1 つしか持てず、ユーザーが書きかけのコメントが入っていることがある。ユーザーに伝え、既存のものを submit か削除してから再実行してもらう。既存のものに足すよう頼まれたら、コメントを 1 件ずつ足すツールで足す（1 件ごとに承認を求められることがある）。

### 3. コメントを付ける行を決める

行は GitHub の差分の hunk に含まれていなければならない。`gh pr diff <PR>` の `@@` で範囲を確かめる。

- 追加・変更した行は `side: "RIGHT"` と変更後の行番号、削除した行は `side: "LEFT"` と変更前の行番号で付ける。
- 範囲で付けるときは `start_line` と `start_side` も渡す。範囲は 1 つの hunk に収める。
- 指摘の行が hunk の外にあるときは、同じ処理の中で hunk に含まれる行に付け、本文で元の `<パス>:<行>` を挙げる。
- そういう行が無い指摘は、行コメントにせず、レビュー本体の `body` に `<パス>` を挙げて書く。この API の `comments` には、ファイル単位のコメントを指定する項目が無い。

### 4. 本文を書く

```text
[<区分>] by <実行しているモデルの表示名>

<本文>
```

- 何が起きるかを入力・状態・結果の具体例で書き、直し方の案を 1 つ添える。作者が直すのに要らない根拠は省く。
- 実行していない点は「コードを読んだだけで、実行はしていません」のように書き、断定しない。
- nit は直すかを作者に委ねる。follow-up は PR の範囲外であることを書き、issue にするよう提案する。
- 作成者に宛てた敬体で書く。ほかのコメントを `#<番号>` で指さない（GitHub が issue や PR へのリンクにする）。

### 5. まとめて置く

リクエストの JSON を、リポジトリの外の一時ディレクトリにファイルとして書く。本文の改行や引用符でコマンドが崩れないよう、コマンドラインに本文を書かない。`event` は入れない。入れると即 submit になる。

```json
{
  "commit_id": "<headRefOid>",
  "body": "<行に付けられなかった指摘。無ければこのキーごと省く>",
  "comments": [
    { "path": "app/models/user.rb", "line": 20, "side": "RIGHT", "body": "..." },
    { "path": "app/x.vue", "start_line": 157, "start_side": "RIGHT", "line": 172, "side": "RIGHT", "body": "..." }
  ]
}
```

```bash
jq -e 'has("event") | not' <ファイル> && \
gh api --method POST repos/{owner}/{repo}/pulls/<番号>/reviews --input <ファイル> --jq '{id, state, html_url}'
```

- 応答の `state` が `PENDING` であることを確かめる。`PENDING` でなければ submit されているので、すぐユーザーに伝える。
- 置いた件数を `gh api --paginate repos/{owner}/{repo}/pulls/<番号>/reviews/<id>/comments --jq '.[].id' | wc -l` で数え、置いた予定の件数と比べる。
- 422 が返ったら、エラーの本文を示す。再送する前に、手順 2 のコマンドで pending レビューができていないかを確かめる。行が hunk の外にあると 422 になることが多いので、手順 3 で行を見直す。

## 出力

- 置いた件数と、pending レビューの URL（`html_url`）。
- 置けなかったコメント: 各件の `<パス>:<行>`、理由、本文。
- 次にすること: GitHub で pending レビューを確かめて submit する。
