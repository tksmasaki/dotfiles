# レビュー観点を diff にコメントする手順

`pr-description` skill から参照する。特定の変更箇所に紐づく判断を diff の該当行にコメントし、body には索引だけを置く。

## 投稿する

1 回の review にまとめて投稿する。コメントごとに投稿するとレビュワーへの通知が分かれる。自分の PR では `APPROVE` / `REQUEST_CHANGES` を使えないため `event` は `COMMENT` にする。コメント本文の 1 行目に「何を見てほしいか」を置き、理由と経緯を続ける。

既に同じ観点のコメントが付いている箇所には重ねて投稿せず、既存コメントの URL を索引に使う。

投稿は JSON をファイルに書いて渡す。

```bash
gh api repos/<owner>/<repo>/pulls/<番号>/reviews --input review.json
```

```json
{
  "event": "COMMENT",
  "body": "見てほしい箇所に diff 上でコメントを付けました。",
  "comments": [
    { "path": "app/foo.rb", "line": 11, "side": "RIGHT", "body": "**この命名を見てください。**\n\n..." },
    { "path": "lib/bar.rb", "start_line": 6, "line": 18, "side": "RIGHT", "start_side": "RIGHT", "body": "..." }
  ]
}
```

アンカーは diff の hunk 内の行に限る。`RIGHT` は変更後のファイルの行番号で、`gh pr diff <番号>` の hunk ヘッダ（`@@ -3,9 +3,11 @@` の右側）から数える。複数行にかけるときは `start_line` と `line` を同じ hunk・同じ side に置く。

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
