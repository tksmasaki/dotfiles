# Artifact のレイアウトと目次

和文の Artifact で、artifact-design skill の指示に足すもの。

## 和文の崩れを防ぐ

- 和文 1 字は約 2ch なので、本文の行長は 85〜95ch にする。`max-width` は段落・箇条書き・見出しに個別に掛け、表やカード群を包む要素には掛けない。
- grid の子（`::before` を含む）が列数より多いときは、すべての子に `grid-column` と `grid-row` を書く。自動配置だと本文が狭い列に落ち、1 文字ずつ折り返す。
- 表のラベル列・数値列と `th` には `white-space: nowrap` を置き、`table` の `min-width` とラッパーの `overflow-x: auto` で横スクロールに逃がす。

## 目次を付けるとき

Artifact は cross-origin の iframe で描画されるため、次を守る。

- ページ内遷移は `href="#id"` のままにし、`preventDefault` や `scrollIntoView` を使わない。移動先には `scroll-margin-top` を置く。
- `rootMargin` は無視される。現在地は、可視高さ（`intersectionRect.height`）が一定以上の節のうち文書順で最も上のものにし、`threshold` を細かく刻む。最後の節が全体表示なら最後の節にする。現在地には `aria-current="location"` を付ける。
