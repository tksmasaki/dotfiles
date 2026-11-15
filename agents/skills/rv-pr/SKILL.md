---
name: rv-pr
description: |
  他人の PR をレビューする準備から結果まで。git mkwt で PR の worktree を用意し、作業スペースを移して、
  pr-fullcheck をレビュアーモード（-r）で実行し、投稿に値する指摘を GitHub の pending レビューに行コメントとして置く。
  submit はしない。他人の PR について、レビューのコメントを GitHub に置く（投稿する・下書きする）ところまで
  頼まれたとき、/rv-pr で使う。コメントを置くよう頼まれていなければ pr-fullcheck を -r で使う。
argument-hint: "<PR 番号か URL> [-s]"
---

# PR の worktree を作ってレビューする（rv-pr）

他人の PR について、worktree の用意、作業スペースの移動、`pr-fullcheck -r` の実行、pending レビューへの投稿を続けて行う。
**コードを書き換えない。GitHub には pending レビューとしてコメントを置くだけで、submit しない。** pending のコメントは自分にしか見えず、submit するかはユーザーが決める。

## 引数

```text
/rv-pr <PR 番号か URL> [-s]
```

- **PR**: 必須。無ければ何もせずに引数の形を示して終了する。
- **`-s`**: そのまま pr-fullcheck に渡す。解釈は pr-fullcheck の「引数」に従う。

PR の対象リポジトリの作業ツリー内で実行する。`gh` の対象も worktree の作成元も、カレントのリポジトリから決まる。`git mkwt` が PATH に無ければ、そう伝えて終了する。

## 手順

### 1. PR を確かめる

```bash
gh pr view <PR> --json number,url,title,author,state,headRefOid,isCrossRepository
gh pr diff <PR> --name-only
gh api user --jq .login
```

次の場合は、理由を示して終了する。

- PR が無い、または `state` が `MERGED` か `CLOSED`。
- 作成者が自分。自分の PR は `/pr-fullcheck`（`-r` なし）で確かめるよう案内する。

次の場合は、PR の作者が書いた設定・hook・指示が、worktree へ移った後のエージェントで動く。手順 2 に進む前に該当するファイルを示し、続けてよいかユーザーに確認する。承認が得られなければ終了する。

- `isCrossRepository` が true（フォークの PR）。
- 変更ファイルに `.claude/`、`.codex/`、`.agents/`、`CLAUDE.md`、`CLAUDE.local.md`、`AGENTS.md`、`.mcp.json`、`.husky/`、`.githooks/` のいずれかが含まれる。

### 2. worktree を用意する

```bash
git mkwt <PR 番号>
```

その PR の worktree が既にあれば再利用し、無ければ作る。標準出力に worktree の絶対パスが出る。

標準エラーには、再利用したかどうか、導入コマンドの失敗、フォークの PR で実行しなかった導入コマンドなどが出る。これらは最後の報告に含める。

続けて、worktree を PR の head に合わせる。再利用した worktree や既存のローカルブランチは、PR より古いことがある。

- `git -C <worktree> status --porcelain` が空でなければ、未コミットの変更があることを伝えて終了する。レビューの対象が PR と食い違うため。
- `git -C <worktree> rev-parse HEAD` が `headRefOid` と違えば、次で合わせる。フォークのブランチは upstream が無いので `pull` は使えない。fast-forward できなければ、状況を伝えて終了する。

```bash
git -C <worktree> -c core.hooksPath=/dev/null fetch origin "pull/<番号>/head"
git -C <worktree> -c core.hooksPath=/dev/null merge --ff-only FETCH_HEAD
```

`core.hooksPath` を相対パスで設定したリポジトリでは、git は worktree の中のフックを使う。PR が同梱したフックを動かさないため、worktree の中で git を実行するときはフックを無効にする。

HEAD が `headRefOid` と一致することを確かめてから次へ進む。

### 3. 作業スペースを worktree へ移す

使える道具で、作業スペースを worktree の絶対パスへ移す。移し方と反映の時期は道具に任せる。続く手順は worktree の中で実行するので、`pwd` が worktree を指すことを確かめてから進む。

次の場合は、pr-fullcheck を実行せずに案内して終了する。

- 移す道具が無い、またはユーザーが移動を承認しなかった。`cd <worktree>` と `/pr-fullcheck <PR> -r` を案内する。
- `pwd` が worktree にならない。移った後に `/pr-fullcheck <PR> -r` を打つよう案内する。

### 4. pr-fullcheck をレビュアーモードで実行する

pr-fullcheck skill を、引数を `<PR> -r`（`-s` があれば付ける）として呼ぶ。呼べない環境では、この SKILL.md の実体（シンボリックリンクを解決した先）と同じ skills ディレクトリにある `pr-fullcheck/SKILL.md` を読んで従う。

pr-fullcheck の手順 1 で止まった場合は、その案内をそのまま示して終了する。

pr-fullcheck の最終レポート（`-s` のときは「サブエージェントで実行する（-s）」の手順 3 で組み直したもの）はチャットに出さず、この skill の手順 5 で投稿する指摘を選ぶ材料にする。

### 5. 投稿する指摘を選ぶ

区分は pr-fullcheck のレポートのもの（review-code の手順 6 の定義）をそのまま使う。

#### 投稿しないもの

次のどれかに当たる指摘は投稿せず、この skill の手順 7 の報告に理由と件数だけを書く。

- **判定対象外**: pr-fullcheck の反証で `不成立` になったもの。
- **関連資料が決めていて、その決定が妥当なもの**: 設計・仕様・テストの資料が形を決めている指摘は、資料を読み直して決定が妥当かを評価する。代替案と比べていて、その比較が今のコードベースでも成り立つなら投稿しない。比べた形跡が無い、または揃っている形から外れるなら投稿し、本文で資料のどの決定に触れるかを挙げる。資料の修正を添えるかは任意とする。

#### 区分ごとの書き方

- **should**: 起きる条件（例: マウスでは起きずキーボードでだけ起きる）を本文に書く。
- **nit**: 本文で「この PR で直すかはお任せします」のように判断を作者に委ねる。
- **follow-up**: 関係する差分の行に付け、この PR の範囲外であることを書き、issue にするよう提案する。

同じ箇所で同じ直し方になる指摘は 1 件にまとめる。

推奨は pr-fullcheck のレポートの判定をそのまま使う。

### 6. pending レビューに投稿する

GitHub MCP の `pull_request_review_write` と `add_comment_to_pending_review` を使う。ツールが無ければ、投稿する本文と行をチャットに出して終了する。

1. 投稿の直前に `gh pr view <PR> --json headRefOid,state` を取り直す。`headRefOid` がこの skill の手順 2 と違えば、投稿せずにやり直しを案内する。
2. 自分の pending レビューが既にあるかを `gh api --paginate repos/{owner}/{repo}/pulls/<番号>/reviews --jq '.[] | select(.state=="PENDING")'` で確かめる。GitHub では pending レビューを 1 人 1 つしか持てず、ユーザーのコメントが入っていることがある。
    - あれば、その `commit_id` が `headRefOid` と一致するかを確かめ、そこに足すかユーザーに確認する。足す場合は 3 を飛ばして 4 へ進む。
    - 足さない場合と、`commit_id` が違う場合は、投稿する本文と行をチャットに出して終了する。
3. `pull_request_review_write` を `method: "create"`、`commitID: <headRefOid>` で呼ぶ。`event` は渡さない。`event` を渡すと即 submit になる。
4. 指摘ごとに `add_comment_to_pending_review` を呼ぶ（行と引数は「コメントを付ける行」に従う）。
5. 2 と同じ API で PENDING のレビューの id を取り、`gh api --paginate repos/{owner}/{repo}/pulls/<番号>/reviews/<review id>/comments` で件数を確かめる。投稿した数と合わなければ、欠けた指摘を報告に挙げる。

#### コメントを付ける行

- 行は GitHub の差分の hunk に含まれていなければならない。`gh pr diff <PR>` の `@@` で範囲を確かめる。
- 追加・変更した行は `subjectType: "LINE"`、`side: "RIGHT"`、変更後の行番号で付ける。削除した行は `side: "LEFT"`、変更前の行番号で付ける。
- リネームしたファイルは、`path` に変更後のパスを渡す。hunk は変更前のパスとの差分のものだけが対象になる。
- 指摘の行が hunk の外にあるときは、同じ処理の中で hunk に含まれる行に付け、本文に「<元の行番号> 行目は差分の外なので、この行に付けています」と書く。同じ処理の中に hunk の行が無ければ、`subjectType: "FILE"`（`line` と `side` なし）でファイルに付け、本文の冒頭で `<パス>:<行>` を挙げる。
- ファイルが差分に無い指摘（PR 本文、issue、差分に無いファイル）は投稿せず、報告に回す。

#### 本文の形

```text
[<区分>] by <モデル名>

<本文>
```

- `<モデル名>` は実行しているモデルの表示名（例: `Claude Opus 5.5`）。
- 本文は pr-fullcheck の「コメント案の書き方」の箇条（具体例・根拠の場所・直し方の案・敬体）に従う。ただし材料の多さより簡潔さを優先し、作者が直すのに要らない根拠は省く。nit は 1〜3 文でよい。
- ほかのコメントを `#<番号>` で指さない（GitHub が issue や PR へのリンクにする）。説明で補い、補えなければそのコメントの URL を貼る。
- 差分の外のファイルの行に触れるときは、`<パス>:<行>` で挙げる。

#### 本文の確かめ

投稿する前に、指摘ごとに次を確かめる。

- 行番号や挙動をコードで確かめたか。実行していない点は「コードを読んだだけで、実行はしていません」のように書き、断定しない。
- 前提の資料を正しく引いているか。資料が決めていることを、作者のミスとして書いていないか。
- 作成者が読んで、何が起きるか（入力・状態・結果）と直し方が分かるか。

#### 投稿後に直すとき

pending のコメントは REST API の PATCH では編集できない（404 になる）。編集は GraphQL の `updatePullRequestReviewComment`、削除は `deletePullRequestReviewComment` を、コメントの `node_id` で呼ぶ。

### 7. 報告する

指摘の本文はチャットに繰り返さず、次だけを短く書く。

- **Summary**: 推奨（Approve / Comment / Request changes）と、その理由を 1〜2 文。投稿した件数（区分ごと）と、pending レビューの PR のリンク。submit していないこと。
- **準備**: worktree の絶対パスと、新しく作ったか既存を使ったか。作業スペースを worktree へ移したこと。`git mkwt` が出した警告（あれば）。
- **行に付けられなかった指摘**: 1 件ずつ、区分と内容を 1 行で。
- **投稿しなかった指摘**: 除外の理由ごとに件数と、代表的なものを一言。
- **資料**: 読んだ資料（1 次・2 次の段ごとのリンク）と、読めなかった資料とその理由、取得しなかった 3 次資料。未充足の受入条件、資料の更新漏れ、資料に無い変更で PR 本文に説明が無いものがあれば、ここに書く。
- **確かめていない点**: テストを実行したか、実行せずにコードから判断した指摘。
