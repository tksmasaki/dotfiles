---
name: md-output
description: md ファイルにまとめ・調査結果・ドキュメントを出力するときの出力先の決め方とチャットへの要約の書き方。「md に出して」「ファイルに保存」と言われたとき、他の skill が md ファイルを書くときに使う。
argument-hint: "[--vault | --path <ディレクトリ>]（省略時は ./tmp）"
---

# md ファイル出力ルール

## 出力先

スキルの引数かユーザーの指示で、出力先を次のとおり決める。確認は取らない。

- 指定なし: 作業ディレクトリの `./tmp`
- `--vault`: vault の直下。vault のパスは環境変数 `MD_OUTPUT_DIR`、空なら `~/.config/claude/env.json` の `MD_OUTPUT_DIR`（`jq -r '.MD_OUTPUT_DIR // empty' ~/.config/claude/env.json`）から引く。どちらにも無ければ、書き出さずにそう伝える。
- `--path <ディレクトリ>`: 指定したディレクトリ

出力先ディレクトリは `mkdir -p` で作成してから書き出す。
ファイル名は出力内容を表す kebab-case にする。

## md 出力済みの場合の要約

内容を md ファイルに出力した場合、チャット上では保存先の絶対パス + 1行サマリに留める。ファイルに書いた内容を本文で再掲しない（トークン節約のため）。

例:

```text
保存しました: /abs/path/to/repo/tmp/xxx.md
（調査対象16件中、条件に該当する4件を特定）
```

## md ファイルでの折りたたみ記載

md ファイルで折りたたみ（開閉ブロック）を書くときは、Obsidian と GitHub の両方で動く「空行区切りの `<details>` 方式」を使う。

```html
<details>
<summary>タイトル</summary>

ここに本文。空行を 1 つ入れるのが最重要。

- リスト項目
- リスト項目

</details>
```

- `<summary>` の直後と `</details>` の直前に空行を入れる。
