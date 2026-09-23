---
name: api-design-reference
description: REST/JSON API を設計・レビューするとき、または OpenAPI の仕様書を書くときに引く外部資料のインデックス。命名、日時、日付範囲のパラメータ、エラー形式、ステータスコード、ページネーション、冪等性、バージョニングといった論点から、Zalando / Google AIP / RFC / OpenAPI 仕様 / 実在 API のどれを読むかを引き当てる。資料の要約ではなく原文への入口。
---

# API 設計リファレンス

REST/JSON API を設計するときに引く資料のインデックス。内容の要約は載せない。論点から資料を引き当て、原文を読むための入口として使う。

確認日: 2026-08-17。2026-09-08 に追加した URL は同日に確認した

## この文書を参照したエージェントへ

参照して気づいた点があれば、**この文書の修正案をユーザーに提案すること**。黙って書き換えない。提案の対象は次の通り。

- リンク切れ、または確認日以降に内容が変わっている資料。URL を再確認したら確認日も更新を提案する
- 「論点から引く」表に無い論点を扱った。該当する資料が見つかれば行の追加を提案する
- 「未カバーの論点」を調べて資料を特定した。表への移動を提案する
- 実例（Stripe / GitHub）を他のエンドポイントでも確認した。一般化できるかどうか「注意」の記述を更新する
- 「所見」が実際の実装や設計判断と食い違っている

**この文書は資料のインデックスであり、資料の要約ではない。** 各資料の規約内容をここに書き写して肥大化させないこと。追加してよいのは「どの論点でどれを引くか」の対応づけと、その入口となる URL に留める。

## 資料一覧

| 資料 | 種別 | 何に強いか |
| --- | --- | --- |
| [Zalando RESTful API Guidelines](https://opensource.zalando.com/restful-api-guidelines/) | 企業の内部規約 | REST/JSON 前提の網羅的な規約。ルール単位で MUST/SHOULD が付き、番号 ID で参照できる |
| [Google AIP](https://google.aip.dev/) | 企業の内部規約 | リソース指向設計の思想。protobuf/gRPC 前提 |
| [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines) | 企業の内部規約 | 大企業の統制を含む規約。汎用 / Azure 向け / Graph 向けの 3 系統がある |
| [RFC 9457 Problem Details](https://www.rfc-editor.org/rfc/rfc9457.html) | 標準規格 | HTTP API のエラー形式。IETF Standards Track (Proposed Standard) |
| [RFC 9110 HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html) | 標準規格 | メソッドとステータスコードの定義。どのコードを使うかの一次情報 |
| [OpenAPI Specification 3.0.3](https://spec.openapis.org/oas/v3.0.3.html) | 標準規格 | 決めた設計を仕様書でどう表現するか。`format` / `pattern` / `examples` の定義 |
| [Redocly のガイド](https://redocly.com/blog/openapi-examples) | ツールベンダーのガイド | OpenAPI の書き方の指針。[パラメータ設計](https://redocly.com/blog/openapi-parameter-types) の記事もある |
| [JSON:API](https://jsonapi.org/format/) | コミュニティ仕様 | リソースと関連の表現、クエリパラメータの体系 |
| [Stripe API Reference](https://docs.stripe.com/api) | 実在 API の実例 | 金額・ID・冪等性・バージョニング。長期運用に耐えた設計 |
| [GitHub REST API](https://docs.github.com/en/rest) | 実在 API の実例 | 素直な CRUD リソースの形 |

種別が違うものを同列に扱わない。標準規格は準拠すれば相互運用性が得られるが、企業の内部規約は**互いに矛盾する**（命名は Zalando が snake_case、Microsoft Azure が camelCase）。根拠にする規約は 1 つに決める。

## 論点から引く

| 論点 | 最初に引く | 補足 |
| --- | --- | --- |
| プロパティ名・URL の命名 | Zalando | Microsoft Azure は結論が逆（camelCase） |
| 日時・期間 | Zalando | 思想は [AIP-142](https://google.aip.dev/142)。ただし protobuf 型の指定は移せない |
| 日付範囲のパラメータ | [Zalando ルール 127](https://opensource.zalando.com/restful-api-guidelines/#127) | 実例は [Google Analytics Data API: DateRange](https://developers.google.com/analytics/devguides/reporting/data/v1/rest/v1beta/DateRange)。ISO 8601 の区間表記は [CDISC の解説](https://www.cdisc.org/kb/articles/when-would-i-use-iso8601-interval-format) |
| 金額・通貨 | [Stripe: Balance Transaction](https://docs.stripe.com/api/balance_transactions/object) | 最小通貨単位の整数で持つ実例 |
| ID の形式 | Stripe | 型プレフィックスと `object` フィールド |
| エラー形式 | RFC 9457 | 独自形式の実例は Microsoft Azure と JSON:API |
| ページネーション | [GitHub: Milestones](https://docs.github.com/en/rest/issues/milestones) | 次ページ URL を返す方式は Microsoft Azure。既定値・上限をどう扱うかは [AIP-158](https://google.aip.dev/158) |
| フィルタ・ソート | GitHub | 予約パラメータの体系は JSON:API |
| ステータスコード | GitHub | 400 と 403 の切り分けなど定義は [RFC 9110 §15.5](https://www.rfc-editor.org/rfc/rfc9110.html#name-client-error-4xx) |
| 制約の仕様書での表現 | [OpenAPI Specification: Data Types](https://spec.openapis.org/oas/v3.0.3.html#data-types) | 散文ではなくスキーマキーワードで書く指針は Redocly のパラメータ設計の記事 |
| 例（examples）の与え方 | [Redocly: examples](https://redocly.com/blog/openapi-examples) | 複数例のキー制約は OpenAPI 仕様の Media Type Object と Components Object |
| 冪等性 | [Stripe: Idempotent requests](https://docs.stripe.com/api/idempotent_requests) | `Idempotency-Key` ヘッダー、POST のみ |
| バージョニング | [Stripe: Versioning](https://docs.stripe.com/api/versioning) | `Stripe-Version` ヘッダー、日付ベース |
| リソースと関連の表現 | JSON:API | 移行コストは高い。単純な CRUD には過剰 |
| 非推奨・廃止のポリシー | Zalando | |

## 未カバーの論点

この一覧では扱えていない。必要になったら資料の調査から始める。

- 認証・認可
- レート制限
- キャッシュ、ETag、条件付きリクエスト
- 非同期処理（202 とポーリング）

## 所見

以下は資料の記述ではなく私見。

- Rails アプリの API に規約を入れるなら土台は Zalando。REST/JSON 前提が一致し、snake_case が Rails の既定と衝突しない
- エラー形式だけは RFC 9457 を別途検討する価値がある。標準規格なので説明コストが低い
- Google AIP は思想の参照に留める。protobuf 前提の型指定は移植できない
- 全ルールを採用する必要はない。命名と日時から始めて足す

## 注意

- 実例（Stripe / GitHub / Google Analytics）は確認したエンドポイントが数個ずつ。API 全体の規約として一般化する前に他のエンドポイントも見ること
- OpenAPI は 3.0 系と 3.1 系で使えるスキーマキーワードが違う。手元の生成物のバージョンを確認してから仕様書を引くこと
- Redocly はツールベンダーの文書で、記述が自社 lint の実装に寄る。標準規格と同じ重みで扱わない
- Zalando と Stripe は更新される生きた文書。確認日以降の変更は追えていない
