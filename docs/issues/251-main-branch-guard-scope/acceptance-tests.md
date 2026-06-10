# Acceptance Tests: main-branch-guard の判定をプロジェクトリポジトリ × 対象 worktree ブランチ基準に修正

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

> 実行形態: AT-001〜AT-004, AT-006, AT-007 は `tests/test_main_branch_guard.bats`（フック実体を stdin JSON で起動するブラックボックステスト）。AT-005 は grep / 目視によるドキュメント検証。
>
> **設置場所の前提（全 BATS 共通）**: テストリポジトリ（`$WORK`）・負例リポジトリ・worktree はすべて **allow-list 外**（`$HOME` 直下の `mktemp -d` で作る `$MBG_BASE` 配下）に置く。`$BATS_TMPDIR` は macOS で `/private/var/folders/...`、Linux で `/tmp` に解決され、`ALLOW_PREFIXES_STATIC`（`hooks/main_branch_guard.py:22-27`）に含まれるため、その配下では deny 系テストが成立せず、allow 系負例は旧実装でも pass する空虚なテストになる。

## AT-001: プロジェクトリポジトリ外の編集は deny されない（US-1 / 偽陽性モード 1）

- [ ] [planned] AT-001: セッション cwd と無関係な別 git リポジトリ配下のファイル編集が allow される
  - Given: cwd はプロジェクトリポジトリ（main ブランチ）。**allow-list 外**の `$MBG_BASE/other-repo`（`$HOME` 直下の mktemp ベース配下）に別の git リポジトリ（main ブランチ、dotfiles 相当）が存在する（`$BATS_TMPDIR` 配下は allow-list 内のため不可 — 旧実装でも `{}` になり負例として空虚化する。実障害は allow-list 外の `~/.local/share/chezmoi/` で発生）
  - When: 別リポジトリ内ファイルを `file_path` とする Edit のフック JSON を main-branch-guard.sh に渡す
  - Then: stdout が `{}`、exit 0（deny されない）。旧実装（cwd main → allow-list 照合）ではこのパスは deny になるため、本テストは修正前実装で red になる真の負例として偽陽性モード 1 の回帰を固定する

## AT-002: feature ブランチ worktree 配下の編集は allow される（US-2 / 偽陽性モード 2）

- [ ] [planned] AT-002: cwd が main にあっても、feature worktree 配下への Write が allow される
  - Given: プロジェクトリポジトリ（main）から `git worktree add "$MBG_BASE/mbg-wt" -b feat/test` で **allow-list 外**に feature worktree を作成済み。cwd は main 側のまま（worktree を `$BATS_TMPDIR` 配下に置くと旧実装でも allow-list 照合で pass し、負例として空虚化するため不可。実障害は allow-list 外の `~/github.com/` 配下 worktree で発生）
  - When: feature worktree 配下のファイルを `file_path` とする Write のフック JSON を渡す
  - Then: stdout が `{}`、exit 0（deny されない）。旧実装ではこのパスは deny になるため、本テストは修正前実装で red になる真の負例として偽陽性モード 2 の回帰を固定する

## AT-003: main/master 上の直接編集は引き続き deny される（US-3 / 真陽性維持）

- [ ] [planned] AT-003a: main worktree 内ファイルへの直接編集は deny される
  - Given: cwd はプロジェクトリポジトリ（main ブランチ）。対象ファイルは同リポジトリの main worktree 配下で allow-list 外
  - When: そのファイルを `file_path` とする Edit のフック JSON を渡す
  - Then: stdout に `"permissionDecision":"deny"` を含む deny JSON が出力される（master ブランチでも同様）
- [ ] [planned] AT-003b: 既存 allow-list 例外は不変
  - Given: cwd はプロジェクトリポジトリ（main ブランチ）
  - When: `/tmp`・`~/.claude`・`~/.config`・`/dev/null` 配下のパスを `file_path` とするフック JSON を渡す
  - Then: いずれも stdout が `{}`（allow-list が従来どおり機能する）

## AT-004: ブランチ判定が py 側の対象ファイル基準に集約されている（US-4）

- [ ] [planned] AT-004: cwd が feature ブランチでも、main worktree 内のファイル編集は deny される
  - Given: cwd は feature worktree（旧実装では sh の早期 return で無条件 allow になっていた状況）。対象ファイルは同一リポジトリの main worktree 配下で allow-list 外
  - When: そのファイルを `file_path` とする Edit のフック JSON を渡す
  - Then: deny JSON が出力される（判定が cwd ブランチではなく対象ファイルの worktree ブランチに基づく）。あわせて `hooks/main-branch-guard.sh` に `git branch --show-current` による早期 return が存在しない

## AT-005: ドキュメントとバージョンが同期されている（US-5）

- [ ] [planned] AT-005: README / CHANGELOG / plugin.json が本変更と同期している
  - Given: 実装・テストの変更が完了している
  - When: `hooks/README.md`・`tests/README.md`・`CHANGELOG.md`・`.claude-plugin/plugin.json` を確認する
  - Then: hooks/README.md が新判定基準（プロジェクトリポジトリ外 allow / 対象 worktree ブランチ基準 / sh-py 責務分担）を記述し、tests/README.md の `test_main_branch_guard.bats` 行に #251 が反映され、CHANGELOG に 3.7.1 エントリがあり、plugin.json の version が `3.7.1` である

## AT-006: fail-safe — 判定不能時は allow（CS-1）

- [ ] [planned] AT-006: git/python3 不在・非 git・malformed・detached HEAD のすべてで `{}` が返る
  - Given: 次のいずれかの異常条件 — (a) cwd が非 git ディレクトリ, (b) PATH から git が見えない, (c) PATH から python3 が見えない, (d) stdin が malformed JSON, (e) 対象ファイル側の worktree が detached HEAD
  - When: フックを実行する
  - Then: いずれも stdout が `{}`、exit 0（正当な編集をブロックしない）

## AT-007: 回帰テスト全 green（CS-2）

- [ ] [planned] AT-007: BATS スイート全件 green
  - Given: AT-001〜AT-004・AT-006 のテストケースが `tests/test_main_branch_guard.bats` に追加され、テストリポジトリ（`$WORK`）が allow-list 外（`$HOME` 直下の mktemp ベース）へ移設済みで、既存 deny テストの対象パスが新基準（リポジトリ内 × allow-list 外パス）に修正済み
  - When: `bats tests/test_main_branch_guard.bats` を実行する
  - Then: 全テスト pass（fail 0）。偽陽性 2 モードの負例・真陽性維持・fail-safe が回帰として固定される

<!-- 実装開始後は [planned] → [draft] に変更する -->
<!-- テストが通過したら [draft] → [green] に変更する -->
<!-- リグレッション対象になったら [green] → [regression] に変更する -->

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
