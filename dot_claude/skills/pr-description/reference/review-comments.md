# レビュー観点を diff にコメントする手順

`pr-description` skill から参照する。特定の変更箇所に紐づく判断を diff の該当行にコメントし、body には索引だけを置く。

## 1 件ずつ独立したコメントとして投稿する

`reviews` エンドポイントで複数のコメントをまとめない。まとめると review 本体が親として残り、あとで中のコメントを差し替えたときに空の review が消えずに残る。提出済みの review は API で削除できない（`Can not delete a non-pending pull request review`）。通知はコメントごとに分かれるが、差し替えのたびに残骸が積むほうが読み手の負担が大きい。

コメント本文の 1 行目に「何を見てほしいか」を置き、理由と経緯を続ける。既に同じ観点のコメントが付いている箇所には重ねて投稿せず、既存コメントの URL を索引に使う。

投稿は 1 件につき 1 回、JSON をファイルに書いて渡す。

```bash
gh api repos/<owner>/<repo>/pulls/<番号>/comments --input comment.json
```

```json
{
  "body": "**この命名を見てください。**\n\n...",
  "commit_id": "<head の SHA>",
  "path": "app/foo.rb",
  "line": 11,
  "side": "RIGHT"
}
```

複数行にかけるときは `start_line` と `start_side` を足す。`commit_id` は `gh api repos/<owner>/<repo>/pulls/<番号> -q .head.sha` で取る。

アンカーは diff の hunk 内の行に限る。`RIGHT` は変更後のファイルの行番号で、`gh pr diff <番号>` の hunk ヘッダ（`@@ -3,9 +3,11 @@` の右側）から数える。複数行にかけるときは `start_line` と `line` を同じ hunk・同じ side に置く。

## 差し替えるときは削除してから投稿する

観点を書き直すときは、古いコメントを消してから新しく投稿する。

```bash
gh api -X DELETE repos/<owner>/<repo>/pulls/comments/<コメントID>
```

過去に `reviews` でまとめて投稿した分は、コメントを消しても review 本体が残る。削除できないので GraphQL で outdated として畳む。UI の Hide と同じ操作である。

```bash
gh api graphql -f query='mutation($id: ID!) { minimizeComment(input: {subjectId: $id, classifier: OUTDATED}) { minimizedComment { isMinimized } } }' -F id=<review の node_id>
```

`node_id` は `gh api repos/<owner>/<repo>/pulls/<番号>/reviews -q '.[] | "\(.id) \(.node_id)"'` で取る。他者や bot の review は畳まない。

## 索引を作る

投稿後に URL を集める。`--paginate` を付け、自分のコメントだけに絞る。付けないと既存のコメントが多い PR で投稿分が取得結果に入らず、他者のコメント URL を貼ることになる。

```bash
gh api --paginate "repos/<owner>/<repo>/pulls/<番号>/comments" \
  -q ".[] | select(.user.login == \"$(gh api user -q .login)\") | \"\(.path):\(.line) -> \(.html_url)\""
```

索引は箇所と「見てほしい判断」を対にした表にする。

```markdown
| 箇所 | 見てほしい判断 |
|---|---|
| [`app/foo.rb`](https://github.com/<owner>/<repo>/pull/<番号>#discussion_r<コメントID>) | 変更範囲を当初の設計より広げた判断 |
```

追加コミットで行がずれるとコメントは outdated になり折り畳まれる。大きく作り直す予定があるうちは body に残す。
