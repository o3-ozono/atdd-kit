# Plan: main-branch-guard の判定をプロジェクトリポジトリ × 対象 worktree ブランチ基準に修正

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

> Anchor: `docs/issues/251-main-branch-guard-scope/prd.md`（Gate ① 承認済み）
> 判定フロー（PRD What-1 で確定）: 対象ファイルを canonicalize → ①プロジェクトリポジトリ（フック cwd のリポジトリ、`git rev-parse --git-common-dir` 比較）に属さない → allow → ②属するが対象 worktree のブランチが main/master 以外 → allow → ③main/master 上 → 既存 allow-list 照合 → deny。判定不能はすべて fail-safe allow。
> Design doc: 不要。判定方式（git-common-dir 比較）と sh/py の責務分担は PRD 壁打ちで確定済みで、競合する代替案のトレードオフは残っていない。

## Implementation

### `hooks/main_branch_guard.py` — 対象ファイル基準判定の実装

- [ ] `main_branch_guard.py` に `_git(args, cwd)` ヘルパーを追加する（`subprocess.run` で `git -C <cwd> <args>` を実行、失敗・非ゼロ終了・git 不在は `None` を返す）
- [ ] verify: `python3 -c` でモジュールを import し、git リポジトリ内/非 git ディレクトリで `_git(["rev-parse", "--git-common-dir"], ...)` がそれぞれ文字列 / `None` を返す

- [ ] `nearest_existing_dir(path)` を追加する（canonicalize 済みパスの dirname から存在する最近接祖先ディレクトリまで遡って返す。Write の新規ファイル対応）
- [ ] verify: 未存在の深いパス（例: `<repo>/a/b/new.md`）を渡すと `<repo>` 配下の既存ディレクトリが返る

- [ ] `resolve_common_dir(dir)` を追加する（`git -C <dir> rev-parse --git-common-dir` の出力 `out` を `os.path.realpath(os.path.join(dir, out))` で **`<dir>` 基準に結合してから**絶対化して返す。git 2.50.1 実測で `--git-common-dir` は main worktree 内からは相対パス（toplevel で `.git`、サブディレクトリで `../.git`）、linked worktree からは絶対パスを返すため、`os.path.realpath(out)` 単体では Python プロセスの cwd 基準で誤解決され `<dir>` 基準の絶対化にならない。`os.path.join` は `out` が絶対パスのとき `dir` を無視するので両形式を正しく扱える。代替として `git rev-parse --path-format=absolute --git-common-dir` を使ってもよい。worktree は common dir を共有するため同一リポジトリ判定キーになる。失敗時 `None`）
- [ ] verify: **Python プロセスの cwd をリポジトリルート以外（例: `/tmp`）に置いて**実行し、同一リポジトリの main worktree と `git worktree add` した feature worktree で同じ値、別リポジトリで異なる値、非 git ディレクトリで `None` が返る。cwd がリポジトリルートだと相対パス `out` の cwd 基準解決が偶然正解と一致してバグを隠蔽するため、リポジトリルートからの実行で済ませてはならない。AT-004 相当（cwd = feature worktree・対象 = main worktree 直下のファイル）で対象側の common dir が `<feature-worktree>/.git` に誤解決されないことも確認する

- [ ] `branch_of(dir)` を追加する（`git -C <dir> branch --show-current` の結果を返す。空文字（detached HEAD）・失敗時は `None`）
- [ ] verify: main worktree で `"main"`、feature worktree でブランチ名、非 git ディレクトリで `None` が返る

- [ ] `main()` の判定を差し替える: canonicalize 後、(a) フック `cwd` の common dir が解決不能 → fail-safe allow、(b) 対象ファイルの common dir が解決不能 or `cwd` 側と不一致（プロジェクトリポジトリ外）→ allow、(c) 一致かつ `branch_of(対象側)` が `main`/`master` 以外（`None` 含む）→ allow、(d) main/master → 既存 `is_allowed()` 照合 → deny
- [ ] verify: `echo '<hook JSON>' | python3 hooks/main_branch_guard.py` の手動実行で、リポジトリ外ファイル → `{}`、feature worktree 内ファイル → `{}`、main 上のリポジトリ内ファイル → deny JSON になる

- [ ] docstring・コメントを新判定フロー（プロジェクトリポジトリ × 対象 worktree ブランチ基準）に更新する
- [ ] verify: docstring に「cwd ブランチ基準」の記述が残っておらず、3 段階判定 (a)-(d) が説明されている

### `hooks/main-branch-guard.sh` — 役割縮小（US-4）

- [ ] `main-branch-guard.sh` から `git branch --show-current` によるブランチ検出と「main/master でなければ即 allow」の早期 return ブロック（22-34 行）を削除し、常に py へ委譲する
- [ ] verify: `grep -n 'branch --show-current' hooks/main-branch-guard.sh` がヒットしない

- [ ] sh 側に `command -v git` / `command -v python3` の存在確認を追加し、不在なら `{}` exit 0 で fail-safe する（入力読取り・PY_SCRIPT 存在確認・RC fail-safe は現状維持）
- [ ] verify: `PATH=/usr/bin:/bin` 等で python3 を見えなくして実行すると `{}` が返る（手動確認。回帰は Testing 節の BATS で固定）

- [ ] sh のヘッダコメントを新しい責務（入力読取り・git/python3 存在確認・fail-safe のみ。判定はすべて py 側）に書き換える
- [ ] verify: コメントが実装と一致し、cwd ブランチ判定への言及がない

## Testing

> **設置場所の大前提（P0）**: `$BATS_TMPDIR` は macOS で `/private/var/folders/...`、Linux で `/tmp` に解決され、いずれも `ALLOW_PREFIXES_STATIC`（`hooks/main_branch_guard.py:22-27`: `/tmp`, `/var/folders`, `/private/var/folders`, `/private/tmp`）に含まれる。そのため `$BATS_TMPDIR` 配下に置いたリポジトリ内パスは、新判定フローの段階 (d)（main/master → allow-list 照合）で**必ず allow（`{}`）になり、deny 系テストは絶対に green にならない**（`tests/test_main_branch_guard.bats:41-42` の既存コメントが明記する罠。実機確認済み: TMPDIR 配下パスは allow-listed: True）。テストリポジトリ・負例リポジトリ・worktree は**すべて allow-list 外（`$HOME` 直下の `mktemp -d` 等）**に置く。
> 既存 BATS の deny テストはデフォルト `file_path=/some/repo/file.md`（テストリポジトリ外）を使っており、新判定では allow に変わる。テストリポジトリ設置場所の変更と既存テストの期待値修正が先行タスク。

- [ ] `tests/test_main_branch_guard.bats` の `setup()` / `teardown()` を変更し、テストリポジトリを allow-list 外へ移設する: `MBG_BASE="$(mktemp -d "$HOME/.mbg-test-XXXXXX")"` を作成し、`WORK="$MBG_BASE/work"` として `git init -b main "$WORK"`、`teardown()` は `rm -rf "$MBG_BASE"` に変更する（`$HOME` 直下は home 由来 allow-list が `~/.claude` / `~/.config` のみのため衝突しない。`BATS_TMPDIR` 配下のままでは deny 系テストが段階 (d) の allow-list 照合で必ず allow になる）
- [ ] verify: `python3 -c 'import sys; sys.path.insert(0,"hooks"); import main_branch_guard as m; print(m.is_allowed(m.canonicalize("'"$WORK"'/file.md","")))'` 相当の手動確認で `False` が返る（`$WORK` 配下が allow-list 外であること）

- [ ] `run_guard` / `run_guard_nb` のデフォルト deny 用パスを移設後の `$WORK` 配下の実在パス（例: `$WORK/file.md` / `$WORK/notebook.ipynb`）に変更し、既存 deny テスト（AC1 / AC3 / AC4 / AC4(a) / AC3(#181)）が新基準（プロジェクトリポジトリ内 × main × allow-list 外）でも真陽性として成立するよう修正する。AC5(#181) の prefix-trap deny テスト（`/tmpfoo`・`/var/foldersx/foo`・`/tmp/../etc/passwd`）はリポジトリ外パスのため新判定では allow に変わる — リポジトリ内の等価パス（例: `$WORK/tmpfoo`）へ差し替えるか、allow-list 照合の単体検証として期待値を見直す
- [ ] verify: `bats tests/test_main_branch_guard.bats` で既存テスト群が pass する（新規追加前の中間確認）

- [ ] AT-001（US-1 / 偽陽性モード 1 の負例）を追加する: **allow-list 外**の `$MBG_BASE/other-repo` に別 git リポジトリ（main ブランチ）を `git init` し、cwd は `$WORK`（main）のまま、別リポジトリ内ファイルへの Edit が `{}` を返す。`$BATS_TMPDIR` 配下に置いてはならない — そこでは旧実装でも allow-list 照合で `{}` になり「修正前でも green の空虚な負例」になる。allow-list 外に置くことで旧実装（cwd main → allow-list 照合 → deny）では red になり、新ロジック（リポジトリ外 allow）の回帰を固定できる（実際の障害も allow-list 外の `~/.local/share/chezmoi/` で発生）
- [ ] verify: `bats tests/test_main_branch_guard.bats -f "AT-001"` が green。かつ修正前の `main_branch_guard.py`（git stash 等で一時復元）に対して同テストが red（deny）になることを確認する

- [ ] AT-002（US-2 / 偽陽性モード 2 の負例）を追加する: `$WORK` から `git worktree add "$MBG_BASE/mbg-wt" -b feat/test` で **allow-list 外**に feature worktree を作成し、cwd は `$WORK`（main）のまま、worktree 配下ファイルへの Write が `{}` を返す（teardown で `git worktree remove` も追加）。worktree も `$BATS_TMPDIR` 配下（旧案の `../mbg-wt-$$` が `$WORK` を TMPDIR に置いたまま解決される位置）に置いてはならない — 旧実装でも allow-list 照合で pass してしまい再発検知能力がゼロになる（実際の障害は allow-list 外の `~/github.com/` 配下 worktree で発生）
- [ ] verify: `bats tests/test_main_branch_guard.bats -f "AT-002"` が green。かつ修正前実装に対して同テストが red（deny）になることを確認する

- [ ] AT-003（US-3 / 真陽性維持）を追加する: main 上の `$WORK` 内ファイルへの Edit が deny JSON（`permissionDecision":"deny"`）を返し、`/tmp` / `~/.claude` 等 allow-list パスは `{}` のまま
- [ ] verify: `bats tests/test_main_branch_guard.bats -f "AT-003"` が green

- [ ] AT-004（US-4 / sh 早期 return 廃止の構造検証）を追加する: cwd を feature worktree に置き、main worktree（`$WORK`）内のファイルへの Edit が deny される（旧実装では cwd 基準早期 return で素通りしていたケース）
- [ ] verify: `bats tests/test_main_branch_guard.bats -f "AT-004"` が green

- [ ] AT-006（CS-1 / fail-safe 回帰）を追加・拡充する: 非 git cwd・git/python3 不在（PATH 細工）・malformed JSON・detached HEAD（対象側）で `{}` が返る
- [ ] verify: `bats tests/test_main_branch_guard.bats -f "AT-006"` が green

- [ ] BATS 全件を実行し AT-007（CS-2）を確認する
- [ ] verify: `bats tests/test_main_branch_guard.bats` が全件 green（fail 0）

## Finishing

- [ ] `hooks/README.md` の main-branch-guard 説明を新判定基準（プロジェクトリポジトリ外 allow / 対象 worktree ブランチ基準 / sh-py 責務分担）に更新する
- [ ] verify: README の記述が実装の 3 段階判定と一致している

- [ ] `tests/README.md` の `test_main_branch_guard.bats` 行（140 行目）を更新し、本 plan による BATS 変更（テストリポジトリの allow-list 外への移設 + 既存 deny テストのパス修正 + AT-001〜AT-004/AT-006 追加）を反映して `main-branch-guard PreToolUse hook (Issue #38 / #181 / #251)` とする — DEVELOPMENT.md の「ディレクトリ内ファイルを変更したら同一 PR で対応する README.md を更新する」invariant（DEVELOPMENT.md:61）に従う
- [ ] verify: `grep -n '#251' tests/README.md` が `test_main_branch_guard.bats` の行にヒットする

- [ ] `CHANGELOG.md` に 3.7.1 エントリ（Fixed: 偽陽性 2 モードの解消、判定基準の変更）を Keep a Changelog 形式で追加する
- [ ] verify: `grep -n '3.7.1' CHANGELOG.md` がヒットし、形式が既存エントリと揃っている

- [ ] `.claude-plugin/plugin.json` の version を 3.7.0 → 3.7.1 に更新する
- [ ] verify: `grep '"version"' .claude-plugin/plugin.json` が `3.7.1` を返す

- [ ] ドキュメント整合性チェック（PRD の Outcome / Non-Goals と実装・テスト・README の突き合わせ）
- [ ] verify: Non-Goals（他リポジトリ main 保護なし・allow-list 不変・フック登録方式不変）に反する変更が diff に含まれていない

- [ ] `docs/issues/251-main-branch-guard-scope/acceptance-tests.md` の状態マーカーを実装結果に合わせて更新する
- [ ] verify: 全 AT が `[green]` になっている
