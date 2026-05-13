# User Stories: tests/claude-code/ 廃止（#198 / D1 + #199 / D2 統合）

> 注: B2 (#189 extracting-user-stories skill) 未実装期間の手動代行。形式は `templates/docs/issues/user-stories.md` + persona 抜き Connextra 規約に準拠。

## Functional Stories

### FS-1: 旧 SAT ハーネスの完全除去

**I want to** `tests/claude-code/` 配下の旧 SAT 系ハーネス（`run-skill-tests.sh` / `samples/fast-*.sh` 6 件 / `samples/integration-*.sh` 7 件 / `fixtures/` / `test-helpers.sh` / `analyze-token-usage.py` / `README.md`）を完全削除しディレクトリ自体を消滅させたい,
**so that** `scripts/run-skill-e2e.sh` + `tests/e2e/<skill>.bats`（#222 確定）以外の skill テスト経路が存在しなくなる。

### FS-2: 廃止対象依存テストの削除（D2 #199 統合）

**I want to** `tests/test_l4_*.bats` 6 件を本 PR で一括削除し、`test_l4_*` prefix を `tests/` 配下から消したい,
**so that** 廃止対象に依存する形骸化テストが残らず BATS suite が中間状態で壊れない。

### FS-3: 参照箇所のクリーンアップ

**I want to** `tests/README.md` / `scripts/README.md` / `.github/workflows/*.yml` / `docs/testing-skills.md` 等から `tests/claude-code/` への参照を全削除したい,
**so that** ドキュメント / CI / コードコメントから旧パスが grep ヒットしない。

### FS-4: #199 (D2) close 連動

**I want to** PR description で `Closes #199` を宣言し、D1 (#198) と D2 (#199) を同一 PR で close したい,
**so that** epic #179 D シリーズの進捗が一貫した状態で更新される。

## Constraint Stories (Non-Functional)

### CS-1: 外部観測動作不変

In order to **#222 で確定した Skill E2E Test 実行経路の挙動を変えずに旧資産だけを除去する**, the system must `scripts/run-skill-e2e.sh --all --dry-run` の出力が PR 前後で完全一致する状態を保つ。

### CS-2: 旧用語残存 0 hit

In order to **新体系の正典 `docs/testing-skills.md` の権威性を保つ**, the system must `tests/test_skill_terminology_grep.bats` が pass し続ける状態（旧用語の許容例外パス外への流出を 0 件に維持）にする。

### CS-3: CI green / BATS フルスイート green

In order to **D2 (#199) 統合による中間状態で壊れた main 状態が出ない**, the system must `bats tests/*.bats` フルスイート green と CI 全 PASS を本 PR 適用後に同時に満たす。
