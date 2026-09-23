---
name: rails-impl-reference
description: Rails アプリを実装するときに引く外部資料のインデックス。クラスの置き場、ファイル名と定数の対応、PORO の置き場、concern を作る判断、ジョブの再試行と冪等性、トランザクション、日付時刻の計算、テストでの時刻固定、spec の構造といった論点から、Rails Guides / API リファレンス / 各 Style Guide / Sidekiq / 37signals のどれを読むかを引き当てる。資料の要約ではなく原文への入口。
---

# Rails 実装リファレンス

Rails アプリを実装するときに引く資料のインデックス。内容の要約は載せない。論点から資料を引き当て、原文を読むための入口として使う。

確認日: 2026-08-20。2026-09-10 に追加した URL は同日に確認した

## この文書を参照したエージェントへ

参照して気づいた点があれば、**この文書の修正案をユーザーに提案すること**。黙って書き換えない。提案の対象は次の通り。

- リンク切れ、または確認日以降に内容が変わっている資料。URL を再確認したら確認日も更新を提案する
- 「論点から引く」表に無い論点を扱った。該当する資料が見つかれば行の追加を提案する
- 「未カバーの論点」を調べて資料を特定した。表への移動を提案する
- 「所見」が実際の実装や設計判断と食い違っている

**この文書は資料のインデックスであり、資料の要約ではない。** 各資料の内容をここに書き写して肥大化させないこと。追加してよいのは「どの論点でどれを引くか」の対応づけと、その入口となる URL に留める。

**プロジェクト固有の事情はここに書かない。** Rails の版、ジョブのバックエンド、ディレクトリの使われ方、禁止事項といったリポジトリごとの前提は、そのリポジトリの `CLAUDE.local.md` か `.claude/rules/` に置き、この文書は資料の対応づけだけを持つ。

## 資料一覧

| 資料 | 種別 | 何に強いか |
| --- | --- | --- |
| [Rails Guides](https://guides.rubyonrails.org/index.html) | 公式ガイド | 機能ごとの入口。確認時点の版は 8.1 |
| [Rails API](https://api.rubyonrails.org/) | 公式 API リファレンス | メソッドの正確な挙動と引数。ガイドで足りないときに引く |
| [Autoloading and Reloading Constants](https://guides.rubyonrails.org/autoloading_and_reloading_constants.html) | 公式ガイド | `app` 配下のディレクトリとオートロード、ディレクトリ＝名前空間の規則 |
| [Zeitwerk](https://github.com/fxn/zeitwerk) | gem の README | ファイル名と定数の対応、暗黙／明示の名前空間、eager load |
| [Active Job Basics](https://guides.rubyonrails.org/active_job_basics.html) | 公式ガイド | キュー、コールバック、`retry_on` / `discard_on`、ジョブのテスト |
| [Active Support Core Extensions](https://guides.rubyonrails.org/active_support_core_extensions.html) | 公式ガイド | `Date.current` / `tomorrow` / `1.day.ago` などの日付・時刻の拡張 |
| [ActiveRecord::Transactions::ClassMethods](https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html) | 公式 API リファレンス | `transaction`、`ActiveRecord::Rollback`、入れ子とセーブポイント、分離レベル |
| [ActiveSupport::Testing::TimeHelpers](https://api.rubyonrails.org/classes/ActiveSupport/Testing/TimeHelpers.html) | 公式 API リファレンス | `travel_to` / `freeze_time` / `travel_back` の挙動 |
| [ActiveSupport::Cache::Store](https://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html) | 公式 API リファレンス | `fetch` のオプション、`race_condition_ttl` の適用範囲、`delete_matched` の位置づけ |
| [ActiveSupport::Cache::RedisCacheStore](https://api.rubyonrails.org/classes/ActiveSupport/Cache/RedisCacheStore.html) | 公式 API リファレンス | Redis ストア固有の挙動。`delete_matched` の実装と、失敗時に例外を投げるかどうか |
| [Ruby Style Guide](https://rubystyle.guide/) | コミュニティ規約 | Ruby の書き方。RuboCop の既定ルールの土台 |
| [Rails Style Guide](https://rails.rubystyle.guide/) | コミュニティ規約 | Rails 固有の書き方。モデル、クエリ、時刻、テスト |
| [RSpec Style Guide](https://rspec.rubystyle.guide/) | コミュニティ規約 | `describe` / `context` の書き分け、`let`、`subject`、モック |
| [Sidekiq: Best Practices](https://github.com/sidekiq/sidekiq/wiki/Best-Practices) | 公式 wiki | ジョブ引数、冪等性、並行実行の前提 |
| [Vanilla Rails is plenty](https://dev.37signals.com/vanilla-rails-is-plenty/) | 企業の設計方針 | PORO の置き場、サービス層を持たない構成、親概念の下への入れ子 |
| [Good concerns](https://dev.37signals.com/good-concerns/) | 企業の設計方針 | concern を作ってよい条件（trait / acts as の意味を持つか） |
| [The Rails Doctrine](https://rubyonrails.org/doctrine) | 思想 | 設計判断の理由づけに使う 9 つの柱 |

種別が違うものを同列に扱わない。公式ガイドと API リファレンスはフレームワークの挙動そのものだが、コミュニティ規約と企業の設計方針は**意見**であり互いに矛盾する（サービスオブジェクトの是非がその例）。設計の根拠にする資料は 1 つに決める。

## 論点から引く

| 論点 | 最初に引く | 補足 |
| --- | --- | --- |
| クラスをどのディレクトリに置くか | Autoloading | `app` 配下は既定でオートロードされる。`app/services` は Rails の規約ではない |
| ファイル名と定数の対応、名前空間 | Autoloading | 詳細は Zeitwerk。ディレクトリが名前空間になる |
| 永続化しないクラス（PORO）の置き場 | Vanilla Rails is plenty | `app/models` に置く立場。反対の立場を採るなら根拠を別に用意する |
| concern を作るか、クラスを切り出すか | Good concerns | private ヘルパの入れ物は concern にしない |
| ジョブの再試行・例外処理 | Active Job Basics | Sidekiq 固有の設定（`sidekiq_options`）は Sidekiq 側 |
| ジョブの引数、冪等性 | Sidekiq: Best Practices | 「少なくとも1回」実行される前提 |
| トランザクションとロールバック | ActiveRecord::Transactions | `ActiveRecord::Rollback` は再 raise されない。入れ子はセーブポイント |
| コールバックでキャッシュや外部システムを触る | ActiveRecord::Transactions | `after_save` / `after_update` は COMMIT 前に走る。キャッシュ破棄は `after_commit` |
| キャッシュの破棄・失効の挙動 | ActiveSupport::Cache::Store | `race_condition_ttl` は期限切れにのみ効き、`delete_matched` には効かない。ストア固有の挙動と失敗時に例外を投げるかは RedisCacheStore |
| 日付・時刻の計算 | Active Support Core Extensions | タイムゾーンの扱いは Rails Style Guide にも規約がある |
| テストでの時刻固定 | ActiveSupport::Testing::TimeHelpers | `freeze_time` は `travel_to(Time.now)` |
| spec の構造・命名 | RSpec Style Guide | プロジェクト規約が優先 |
| クエリの書き方、モデル設計 | Rails Style Guide | |
| Ruby の書き方 | Ruby Style Guide | RuboCop の指摘の出どころを確かめるときに引く |
| 設計判断の説明 | The Rails Doctrine | 規約より上位の理由づけ |

## 未カバーの論点

この一覧では扱えていない。必要になったら資料の調査から始める。

- 定期実行（cron）の設定と sidekiq-scheduler
- N+1、`includes` / `preload` の使い分けと計測
- キャッシュ戦略（破棄のタイミングは ActiveRecord::Transactions、破棄・失効の挙動は ActiveSupport::Cache で引ける。TTL の置き方・キー設計・破棄の粒度は未カバー）
- マイグレーションとスキーマ管理
- 認証・認可（Devise / Pundit）
- フロントエンドとの境界
- 監視・エラー通知

## 所見

以下は資料の記述ではなく私見。

- 1 つのジョブだけが使うクラスは、ジョブ名前空間下（`app/jobs/<job_name>/`）に置くのが素直
- 実行文脈（`Rails.env`、dry-run の有無）で分岐するクラスをドメインモデルに置くと役割が濁る。呼び出し元側の名前空間に寄せる
- 37signals の方針は「Rails 標準で足りる」に振り切った立場。層を足す判断をするなら、足す理由を明示的に書く

## 注意

- コミュニティ規約と企業の設計方針は生きた文書で、確認日以降の変更は追えていない
- Rails Guides の確認時点の版は 8.1。対象リポジトリの版が違えば、当てはまらない記述がある
- Active Job Basics は既定のバックエンドを Solid Queue として説明する。別のバックエンドを使うリポジトリでは、キューとリトライの記述がそのまま当てはまらない
- 各資料は入口として確認しただけで、全文を読み込んだわけではない
