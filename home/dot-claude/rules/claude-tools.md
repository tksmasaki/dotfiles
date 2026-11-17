# Claude Code の道具の使い方

## 動作確認のブラウザ

開発中のアプリを画面で動作確認するときは playwright-secrets（Playwright MCP を `--secrets` 付きで起動したもの）で行う。アプリ内のブラウザは使わない。ログインは secrets のキー名を入力欄に渡して行い、値は読まない。

playwright-secrets が無い、または接続できないときは Claude in Chrome で確認し、切り替えたことを伝える。どちらも無ければ Playwright など別の手段で確認し、それも無ければ確認できなかったと伝える。

## それ以外のブラウザ確認

開発中のアプリの動作確認以外でブラウザを使うとき（GitHub・Notion などの表示確認、Web ページの閲覧）は Claude in Chrome を使う。playwright-secrets はこれらのサービスにログインしていない。

## サブエージェントに委譲する

要約と確かめられなかった点だけを返させる。ログ本文はパスで受け取る。

Explore と Plan は CLAUDE.md を読まない。この 2 つに効かせたいルールは委譲時のプロンプトで言い直す。
