# dotfiles (chezmoi)

ドットファイルを chezmoi で管理する。ソースは `~/.local/share/chezmoi`、適用先は `$HOME`。

## 管理対象

ソースの `dot_<名前>` が `~/.<名前>` に対応する。`dot_claude/skills/foo/SKILL.md` は `~/.claude/skills/foo/SKILL.md`、`dot_zshrc` は `~/.zshrc` になる。個々のファイルはここに列挙しない。現在の一覧は `chezmoi managed --exclude=dirs` で引く。

`exact_` プレフィックスは使わない。`~/.claude` や `~/.local/bin` には mise や各ツールが置いた symlink と管理外のファイルが同居していて、`exact_` を付けると `chezmoi apply` でそれらが削除される。

初回構築は `./install.sh`。Homebrew・sheldon・mise・chezmoi・herdr を入れて `chezmoi init --apply tksmasaki` まで実行する。`--local` を付けると `setup_for_local.sh` も走り、Claude Code と GitHub Copilot CLI が入る。Alacritty は自動で入らず、未インストールなら警告だけ出る。

## 編集の入口

`.chezmoi.toml.tmpl` で `mode = "symlink"` を指定しているため、テンプレート以外の管理対象は `$HOME` 側がソースへの symlink になる。`~/.claude/CLAUDE.md` や `~/.claude/hooks/*.sh` はどちら側から編集しても同じ実体。

テンプレート（`*.tmpl`）だけは実体のコピーになる。現在は `.chezmoi.toml.tmpl` と `dot_claude/settings.json.tmpl` の 2 つ。`~/.claude/settings.json` を直接編集しても次の `chezmoi apply` で消えるので、`dot_claude/settings.json.tmpl` を編集して apply する。

既存ファイルの編集は symlink 経由で即座に反映される。新規追加・リネーム・削除は `chezmoi apply` を実行するまで `$HOME` 側に現れない。

`$HOME` 側にある既存ファイルを管理下に入れるときは `chezmoi add <適用先パス>`。add はソースにコピーを作るだけで、適用先は通常ファイルのまま残るので、続けて `chezmoi apply <適用先パス>` を実行して symlink に置き換える。忘れると `$HOME` 側の編集がソースに反映されない。

symlink にならない管理対象は `~/.claude/settings.json` だけ。`install.sh` は apply 後に通常ファイルとして残った管理対象を列挙して警告する。

## Claude Code の設定変更と apply の衝突

`/model` などの Claude Code 自身による設定変更は `~/.claude/settings.json` に書かれるため、`chezmoi apply` でテンプレートの値に戻る。`chezmoi status` に `MM .claude/settings.json` が出ていたら、どちらを残すか決めてから apply する。

`~/` 側の変更を残す場合、テンプレートなので `chezmoi re-add` では取り込めない。`chezmoi diff ~/.claude/settings.json` で差分を見て `dot_claude/settings.json.tmpl` に手で書き戻す。

衝突を保留したまま他のファイルだけ適用したいときは、適用先パスを渡す。`chezmoi apply ~/.local/bin/roles-up` のように書けば `settings.json` に触らずに済む。

`settings.json.tmpl` は `~/.config/claude/automode.json` があれば中身を `autoMode` として取り込み、`~/.config/claude/env.json` があればそのキーと値を `env` に追加する。どちらも chezmoi の管理外で、マシンごとに置く。`env.json` には md-output skill が読む `MD_OUTPUT_DIR` のような、マシン固有のパスを入れる。

## コマンド

```bash
chezmoi status                                 # 差分のあるファイル
chezmoi managed --exclude=dirs                 # 管理下のファイル一覧
chezmoi diff ~/.claude/settings.json           # 適用先の絶対パスで渡す
chezmoi apply
chezmoi source-path ~/.claude/settings.json    # 適用先からソースを引く
chezmoi apply --dry-run -v                     # 適用結果だけ見る
chezmoi execute-template < dot_claude/settings.json.tmpl | jq .   # テンプレートの展開結果
```

## ソース直下にファイルを置くとき

ソース直下の通常ファイルは `~/<名前>` に適用される。リポジトリ用のドキュメントは `.chezmoiignore` に入れて適用対象から外す。

`.chezmoiignore` のパターンは適用先の相対パス全体と照合する。`CLAUDE.md` はルート直下だけを外し、`.claude/CLAUDE.md` は管理対象のまま残る。

## hooks / skills / rules

`dot_claude/hooks/*.sh` は symlink 経由で実行され、実行ビットはソース側のファイルモードで決まる。`executable_` プレフィックスは使っていない。

hook は `dot_claude/hooks/lib/claude-env.sh` を `source` し、`CLAUDE_AUTO_COMMIT` などの現在値を settings ではなくファイルから読み直す。最優先はリポジトリの git ディレクトリ直下の `claude-env.json`（worktree ごとの上書き）。この値を書き換える `toggle-auto-commit` / `toggle-remote-confirm` は `dot_local/bin/` で管理している。

`dot_local/bin/` は `~/.local/bin/` に symlink される自作コマンドの置き場。mise が置く shim と同居するため `exact_` は使わない。

`dot_claude/skills/*/SKILL.md` を追加すると `~/.claude/skills/` に symlink され、全プロジェクトで有効になる。

`dot_claude/rules/*.md` も `~/.claude/rules/` に symlink され、全プロジェクトのセッションで自動的に読み込まれる。
