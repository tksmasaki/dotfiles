---
name: rv-pr
description: |
  他人の PR をレビューする準備から結果まで。git mkwt で PR の worktree を用意し、セッションを移して、
  pr-fullcheck をレビュアーモード（-r）で実行する。手動起動専用（/rv-pr）。
argument-hint: "<PR 番号か URL> [effort（省略時は high）] [-s]"
disable-model-invocation: true
---

# PR の worktree を作ってレビューする（rv-pr）

他人の PR について、worktree の用意、セッションの移動、`pr-fullcheck -r` の実行を続けて行う。
**コードを書き換えず、GitHub にも投稿しない。** 投稿するのは、ユーザーが頼んだときだけ。

## 引数

```text
/rv-pr <PR 番号か URL> [effort] [-s]
```

- **PR**: 必須。無ければ何もせずに引数の形を示して終了する。
- **effort** と **`-s`**: そのまま pr-fullcheck に渡す。解釈は pr-fullcheck の「引数」に従う。

PR の対象リポジトリの作業ツリー内で実行する。`gh` の対象も worktree の作成元も、カレントのリポジトリから決まる。`git mkwt` が PATH に無ければ、そう伝えて終了する。

## 手順

### 1. PR を確かめる

```bash
gh pr view <PR> --json number,url,title,author,state,headRefOid
gh api user --jq .login
```

次の場合は、理由を示して終了する。

- PR が無い、または `state` が `MERGED` か `CLOSED`。
- 作成者が自分。自分の PR は `/pr-fullcheck`（`-r` なし）で確かめるよう案内する。

### 2. worktree を用意する

```bash
git mkwt <PR 番号>
```

その PR の worktree が既にあれば再利用し、無ければ作る。標準出力に worktree の絶対パスが出る。標準エラーには、再利用したか、導入コマンドの失敗、フォークの PR で実行しなかった導入コマンドなどが出るので、最後の報告に含める。

続けて、worktree を PR の head に合わせる。再利用した worktree や既存のローカルブランチは、PR より古いことがある。

- `git -C <worktree> status --porcelain` が空でなければ、未コミットの変更があることを伝えて終了する。レビューの対象が PR と食い違うため。
- `git -C <worktree> rev-parse HEAD` が `headRefOid` と違えば、次で合わせる。フォークのブランチは upstream が無いので `pull` は使えない。fast-forward できなければ、状況を伝えて終了する。

```bash
git -C <worktree> fetch origin "pull/<番号>/head"
git -C <worktree> merge --ff-only FETCH_HEAD
```

HEAD が `headRefOid` と一致することを確かめてから次へ進む。

### 3. セッションを worktree へ移す

`mcp__ccd_directory__change_directory` に worktree の絶対パスを渡す。deferred なら ToolSearch で読み込んでから呼ぶ。

フォルダへのアクセスはすぐに付くが、作業ディレクトリが移るのはターンの終了時になる。このターンで続けるため、Bash で `cd <worktree>` を実行し、続く呼び出しで `pwd` が worktree を指すことを確かめる。

次の場合は、pr-fullcheck を実行せずに案内して終了する。

- ツールが見つからない、またはユーザーが移動を承認しなかった。`cd <worktree>` と `/pr-fullcheck <PR> -r` を案内する。
- `pwd` が worktree にならない。次のターンでは移っているので、`/pr-fullcheck <PR> -r` を打つよう案内する。

### 4. pr-fullcheck をレビュアーモードで実行する

pr-fullcheck は `disable-model-invocation: true` のため Skill ツールでは呼べない。`~/.claude/skills/pr-fullcheck/SKILL.md` を読み、引数を `<PR> <effort> -r`（`-s` があれば付ける）として、その手順に従う。

pr-fullcheck の手順 1 で止まった場合は、その案内をそのまま示す。

### 5. 報告する

pr-fullcheck のレポートの前に、次を短く添える。

- worktree の絶対パスと、新しく作ったか既存を使ったか
- セッションを worktree へ移したこと
- `git mkwt` が出した警告（あれば）
