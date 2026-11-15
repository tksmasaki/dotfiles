# GitHub への画像の添付

PR・issue の本文やコメントにスクリーンショットや画像を載せるときは、gh の `--attach` で添付する。ブラウザで GitHub の編集欄やコメント欄にアップロードしない。

`--attach` を使えるのは次のコマンド。

- `gh pr create` / `gh pr edit` / `gh pr comment`
- `gh issue create` / `gh issue edit` / `gh issue comment`

`gh pr review` と `gh release` は `--attach` を持たない。レビューに画像を添えたいときは、`gh pr comment` で別に投稿する。

## 手順

- 本文では `![初期表示の実装](./impl-initial.png)` のように相対パスで参照し、画像のあるディレクトリで gh を実行する。参照は添付先の URL に書き換わる
- 本文から参照していない添付は末尾に足される。置き場所を決めたい画像は、必ず本文から参照する
- 代替テキストには、何の画面のどの状態かを書く。ファイル名のままにしない
- 反映した後に本文を取り直し（`gh pr view <番号> --json body -q .body` など）、相対パスが URL に置き換わったことを確かめる

本文の書き方と更新の手順は、PR なら pr-description skill、issue なら issue-description skill に従う。
