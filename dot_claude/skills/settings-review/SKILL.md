---
name: settings-review
description: セッションログから Claude の設定を見直す作業を、前回の引き継ぎメモから始める。/settings-review と、「settings-review を実行して」のように skill 名を挙げて頼まれたときだけ使う。設定の質問や個別の設定変更では使わない。
---

# settings-review

chezmoi のソースディレクトリ（`chezmoi source-path` で引く）直下の `.settings-review-handoff.md` を読み、その「次回の進め方」に沿って作業を始める。

ファイルが無ければ、そう伝えて止める。引数があれば、引き継ぎメモより優先する追加の指示として扱う。
