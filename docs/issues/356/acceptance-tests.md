# Acceptance Tests: pre-merge フェイルセーフゲートの契約再定義（--all 再帰化＋影響選択 e2e 配線）

AT は `tests/test_run_tests.bats`（FS1/CS1）と構造 pin（FS2/CS2/CS3/CS4）で encode する。
`[regression]` 化する AT は時点依存値（行番号・バージョン・日付）を pin せず、契約の不変条件を assert する。

## FS1: `--all` の acceptance/ 再帰化（false-green を塞ぐ）

- [ ] [planned] AT-356-1a: `collect_all_bats` が `tests/acceptance/*.bats` を収集対象に含める
  - Given: `scripts/run-tests.sh` を `--_source-only` で source
  - When: `collect_all_bats <repo-root>` を実行する
  - Then: 出力に `tests/acceptance/AT-` を含む行が 1 件以上ある（acceptance/ が再帰収集されている）

- [ ] [planned] AT-356-1b: `--all` が失敗する acceptance テストを集約して非 0 を返す（false-green の直接 oracle・赤→緑 anchor）
  - Given: tmp リポジトリに `tests/acceptance/at_fail.bats`（必ず失敗する `@test` を 1 件含む）を置く
  - When: `run-tests.sh --all --repo <tmp>` を実行する
  - Then: 終了コードが非 0、かつ実行ログに当該 acceptance テストの `not ok` が現れる（修正前は exit 0 = false-green で赤）

## CS1: `--all` と `--impact` の判定一致

- [ ] [planned] AT-356-2: 同一 fixture で `--all` と `--impact`(FALLBACK) がともに acceptance/ の失敗を検出して非 0 を返す
  - Given: AT-356-1b と同じ tmp fixture（失敗する acceptance テストを含む）
  - When: `run-tests.sh --all --repo <tmp>` と `run-tests.sh --impact --base <ref> --repo <tmp>`（FALLBACK 経路）をそれぞれ実行する
  - Then: 両者ともに終了コードが非 0（必須側と影響側の BATS 判定が一致する）

## FS2: 影響選択 e2e の merge gate 配線

- [ ] [planned] AT-356-3: merge gate が `run-skill-e2e.sh --changed-files` を実行する記述を持つ
  - Given: `skills/merging-and-deploying/SKILL.md`
  - When: Pre-merge gate セクションを参照する
  - Then: `run-skill-e2e.sh --changed-files` が出現し、変更影響を受ける skill の e2e を実行する旨が記述されている（修正前は不在で赤）

## CS2: e2e は影響選択に限定（全件強制しない）

- [ ] [planned] AT-356-4: merge gate が e2e 全件実行（`--all`）を強制せず影響選択（`--changed-files`）である
  - Given: `skills/merging-and-deploying/SKILL.md` の Pre-merge gate セクション
  - When: e2e 実行記述を確認する
  - Then: e2e は `run-skill-e2e.sh --changed-files`（影響選択）で呼ばれ、merge gate で `run-skill-e2e.sh --all`（全件）を必須とする記述が無い。認証不在時は skip 明示＋BATS ゲート必須の方針が記述されている

## CS3: 文書と実装の整合

- [ ] [planned] AT-356-5a: #324 `acceptance-tests.md` の `AT-210f` が新契約（acceptance/ 再帰収集）に改訂されている
  - Given: `docs/issues/324-test-speedup/acceptance-tests.md`
  - When: AT-210f エントリを参照する
  - Then: 「acceptance/・e2e/ を除外する意図的設計」承認の記述が、`--all` が acceptance/ を再帰収集する新契約に改訂されている

- [ ] [planned] AT-356-5b: `collect_all_bats` のコードコメントが新スコープに整合している
  - Given: `scripts/run-tests.sh` の collect_all_bats 周辺コメント
  - When: スコープ説明コメントを参照する
  - Then: 「acceptance/ を含む再帰収集（e2e/ は別レイヤー）」が説明され、旧「maxdepth 1 により acceptance/ 除外」記述が無い

- [ ] [planned] AT-356-5c: `docs/methodology/test-execution-policy.md` が新契約に整合している
  - Given: `docs/methodology/test-execution-policy.md`
  - When: pre-merge gate の方針記述を参照する
  - Then: 「merge gate = acceptance を含む full BATS（`--all`）＋ 影響選択 skill-e2e」に整合している

## CS4: 既存ロジック再利用・CI 不変（影響範囲最小化）

- [ ] [planned] AT-356-6a: merge gate が独自 impact mapping を再実装せず既存 `run-skill-e2e.sh` を再利用する
  - Given: `skills/merging-and-deploying/SKILL.md` と `scripts/run-tests.sh`
  - When: e2e 影響選択の実装箇所を確認する
  - Then: 影響選択は `run-skill-e2e.sh`（内蔵 path-based mapping）に委譲され、merge gate 側に新規マッピング関数が追加されていない

- [ ] [planned] AT-356-6b: CI（pr.yml）の再帰 bats 実行が不変である
  - Given: `.github/workflows/pr.yml`
  - When: bats 実行ステップを参照する
  - Then: `bats tests/ addons/...`（再帰）の実行行が存在し、本 Issue で CI の bats スコープを変更していない

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
