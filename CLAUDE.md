# dotfiles (mise)

ドットファイルを mise の dotfiles 機能で管理する。適用の定義はリポジトリ直下の `mise.toml` と `mise.mac.toml` の `[dotfiles]`、適用先は `$HOME`。ツールは `Brewfile` で Homebrew から入れ、mise はリポジトリごとに版を固定する言語の処理系にだけ使う。

## このリポジトリは公開されている

コミットメッセージとファイルに、他のリポジトリ名・組織名・業務の中身を書かない。別のリポジトリから持ち込んだ変更は「作業中のリポジトリ」「元のリポジトリ」と書く。

`.githooks/pre-push` が、push するコミットのメッセージ・ファイル名・追加行を `~/.config/dotfiles/public-denylist.txt` の語と照合し、当たれば push を止める。一覧を公開しないため、このファイルはリポジトリの管理外に置く。hook は `install.sh` が `core.hooksPath` を設定して有効にする。

## 配置

- `home/` は `$HOME` と同じ並びで置く。`dot-` で始まる名前が `.` で始まる名前に対応する（`home/dot-config/git/config` は `~/.config/git/config`）。
- 適用先は 2 つのファイルに分けて書く。`mise.toml` には、Claude のクラウド環境でも要るもの（Claude が読む指示・rules・references と、共有の skill の `~/.claude/skills` 側）だけを置く。それ以外（シェルやアプリの設定、`~/.local/bin`、git の設定、`settings.json` と hook、Codex 用の `~/.agents/skills`）は、Mac で適用するため `mise.mac.toml` に置く。`mise.mac.toml` は `-E mac`（`MISE_ENV=mac`）を付けたときだけ読まれる。
- 適用先は 1 つずつ書く。ファイルは symlink、ディレクトリは `symlink-each` にする。`symlink-each` は管理外のファイルが同居するディレクトリでも、管理するファイルだけをリンクする。`~` そのものを対象にしない。適用先のディレクトリを走査するので、HOME 全体を読んで止まる。
- `symlink-each` にしたディレクトリにファイルを足すだけなら、適用先の定義は変えない。それ以外の場所にファイルやディレクトリを足したら、どちらかのファイルに適用先を足す。
- `claude/` は `~/.claude/settings.json` の生成元。`agents/` は Codex と共有する skill の原本（後述）。
- `archive/` は使っていない設定の保管場所で、適用しない。

## 適用

```bash
mise -E mac -C <リポジトリ> dotfiles apply     # zsh では abbr の dotap
mise -E mac -C <リポジトリ> dotfiles status    # 同じく dotst
```

`$HOME` 側はソースへの symlink なので、既存ファイルの編集はどちら側からでも即座に反映される。新規追加・リネーム・削除は apply で反映される。`symlink-each` の配下でソースを消すと、次の apply でリンクも消える。

skill / rules を編集しても実行中のセッションには反映されない。そのセッションで使うなら `/reload-skills` を打つ。

zsh の `$DOTFILES_DIR` は、`~/.zshrc` の symlink をたどってリポジトリの場所を決める。リポジトリをどこに複製しても動く。

## Claude Code の settings.json

`~/.claude/settings.json` だけは実体のファイルで、apply のたびに `claude/build-settings.sh` が `claude/settings.base.json` から作る。変更は `settings.base.json` に書く。

`/model` などの Claude Code 自身による設定変更は `~/.claude/settings.json` に書かれ、次の apply で上書きされる（mise は上書きの前に警告を出す）。残したい変更は、apply の前に `settings.base.json` に書き戻す。

`build-settings.sh` は、`~/.config/claude/` の次のファイルがあれば合成する。リポジトリの管理外で、マシンごとに置く。jq が無い環境では合成せず、`settings.base.json` をそのまま使う。

- `env.json`: `env` に足す。md-output skill が読む `MD_OUTPUT_DIR` のような、マシン固有のパスを入れる
- `plugins.json`: `enabledPlugins` に足す
- `denied-mcp-servers.json`: `deniedMcpServers` に入れる

## hooks / skills / rules

`home/dot-claude/hooks/*.sh` は symlink 経由で実行され、実行ビットはソース側のファイルモードで決まる。

hook は `home/dot-claude/hooks/lib/claude-env.sh` を `source` し、`AGENT_AUTO_COMMIT` などの現在値を settings ではなくファイルから読み直す。最優先はリポジトリの git ディレクトリ直下の `claude-env.json`（worktree ごとの上書き）。この値を書き換える `toggle-auto-commit` / `toggle-remote-confirm` は `home/dot-local/bin/` で管理している。

`home/dot-claude/skills/<名前>/` は Claude だけで使う skill。`home/dot-claude/rules/*.md` は全プロジェクトのセッションで自動的に読み込まれ、Claude 固有の指示だけを置く。

## Codex と共有する

共有する指示と skill の原本は Codex 側に置き、Claude からはそれを参照する。

- 指示: 原本は `home/dot-codex/AGENTS.md`（`~/.codex/AGENTS.md`）。`home/dot-claude/CLAUDE.md` は `@~/.codex/AGENTS.md` で取り込むだけにする。Claude 固有の指示（Claude Code の道具の扱い）は AGENTS.md に書かず、rules（`claude-tools.md`）に置く。AGENTS.md は Codex の上限 32 KiB に収める。
- skill: 共有するものの原本は `agents/skills/<名前>` に置き、`~/.claude/skills/<名前>`（`mise.toml`）と `~/.agents/skills/<名前>`（`mise.mac.toml`）からフォルダごと symlink する。Codex は symlink になった `SKILL.md` を読まないので、ファイルごとのリンクにしない。
- Claude 固有の道具（Artifact、Claude Docs、組み込みの code-review、セッションログ）が手順の中心にある skill は共有しない。共有する skill で Claude 固有の道具に触れる箇所は、「使える質問の道具（Claude Code では AskUserQuestion）」のように目的で書き、道具が無い環境での振る舞いを添える。
- 手動起動専用の skill は、SKILL.md の `disable-model-invocation: true`（Claude 向け）と `agents/openai.yaml` の `policy.allow_implicit_invocation: false`（Codex 向け）の両方を書く。Claude は `openai.yaml` を読まない。
- `~/.agents/skills` と `~/.claude/skills` には `npx skills` が入れた skill も同居する。リポジトリの管理外なので消さない。
- hook・権限・MCP は形式が違うので共有しない。

## 新しいマシン

- macOS: リポジトリを複製して `install.sh` を実行する。Homebrew・Brewfile の導入、dotfiles の適用、mise の処理系の導入までを行う。
- Claude のクラウド環境: `cloud-setup-claude.sh` の中身を環境のセットアップスクリプトに貼る。`mise.toml` の分だけを適用し、`settings.json` や hook はクラウド環境の設定のまま残す。リポジトリの複製より前に動くので、mise のバイナリを GitHub Releases から直接取る。版は手動で更新する。
- Codex のクラウド環境: `cloud-setup-codex.sh` の中身を環境のセットアップスクリプトに貼る。初回セットアップ専用で、mise が無ければ GitHub Releases から導入し、dotfiles を clone する。`mise.toml` と `mise.mac.toml` を読み、`~/.codex/AGENTS.md` と共有 skill の `~/.agents/skills/<名前>` だけを `--force` で適用する。同名の既存設定は置き換え、管理外の skill は残す。Codex 実行時と同じ `$HOME` を使い、`CODEX_HOME` は既定のままにする。
