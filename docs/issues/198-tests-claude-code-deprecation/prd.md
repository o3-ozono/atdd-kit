# PRD: tests/claude-code/ 廃止（旧 SAT ハーネス完全除去）

## Problem

**現状:**
- `tests/claude-code/` 配下に旧 SAT 系ハーネス（`run-skill-tests.sh` / `samples/fast-*.sh` 6 件 / `samples/integration-*.sh` 7 件 / `fixtures/` / `test-helpers.sh` / `analyze-token-usage.py` / `README.md`）が残存。
- `tests/test_l4_*.bats` 6 件がこのハーネスを test 対象とする形骸化テスト。
- #222 (PR #224, merged 2026-05-12) で `scripts/run-skill-e2e.sh` + `tests/e2e/<skill>.bats` が完全代替済み。

**痛み:**
- 旧用語（SAT / L1-L3 / Fast layer / Integration layer / BATS gate / Fast SAT / Integration SAT）が docs/コード/CI/grep 結果に残存し、新規参加者を混乱させる。
- 2 種類のテスト体系（旧 SAT 系 + 新 Skill E2E Test）が並存し、どちらを修正すべきかの判断コストが PR ごとに発生。
- `test_l4_*.bats` は stub claude が固定文字列を返すため false-positive 通過のリスク（#222 PRD で指摘済）。
- `docs/testing-skills.md`（#222 で新体系の正典として確立）の権威性が、旧資産残存によって弱まる。

## Why now

- **Trigger:** #222 (PR #224, merged 2026-05-12) で新体系（Unit Test / Skill E2E Test 2 層）と `scripts/run-skill-e2e.sh` runner が確定。旧資産は完全代替済みのため廃止可能になった。
- **Blocking chain:** #179 v1.0 redesign epic の D シリーズ Blocker。D1 (#198) は D2 (#199) → D3 (#200) → D4 (#201) を直接 block し、間接的に C1 (#196) / F1 (#207) / G1 (#208) も block する。v1.0 release の critical path。
- **Opportunity cost:**
  - 新 skill B 系列 (#190-#195) 実装時に「旧 `fast-*.sh` / `integration-*.sh` を follow すべきか、新 `tests/e2e/` を使うべきか」の判断コストが PR ごとに繰り返し発生。
  - 旧用語が新ドキュメントに transcription error として混入するリスク。
  - `tests/test_l4_*.bats` の false-positive が見過ごされ続け、CI green の信頼性が低下。

## Outcome

完了時に達成されている状態（測定可能）:

- `tests/claude-code/` ディレクトリが存在しない（`ls tests/claude-code/` → `No such file or directory`）
- `tests/test_l4_*.bats` が 0 件、`grep -r "test_l4_" tests/` が 0 hit
- `scripts/run-skill-e2e.sh --all --dry-run` の出力が PR 前後で同一（外部観測動作不変）
- `grep -r "tests/claude-code" docs/ scripts/ rules/ .github/ tests/ commands/ skills/` が 0 hit（CHANGELOG.md と `docs/issues/` 配下は除外）
- `tests/test_skill_terminology_grep.bats` が pass
- `bats tests/*.bats` フルスイートが green
- CI 全 PASS
- `#199` (D2) が本 PR で close（統合 PR 方式）

## What

**4.1 `tests/claude-code/` 配下の削除**
- `run-skill-tests.sh`（`scripts/run-skill-e2e.sh` で代替済）
- `samples/fast-*.sh` 6 件 / `samples/integration-*.sh` 7 件
- `fixtures/`（atdd-fixture-issue.md / discover-fixture-issue.md / *-keywords.txt / minimal-project/）
- `test-helpers.sh`
- `analyze-token-usage.py`
- `README.md`
- `tests/claude-code/` ディレクトリ本体

**4.2 `tests/test_l4_*.bats` 6 件の削除（D2 #199 統合）**
- 廃止対象依存の 4 件: `test_l4_samples.bats` / `test_l4_test_helpers.bats` / `test_l4_run_skill_tests.bats` / `test_l4_analyze_token_usage.bats`
- 残り 2 件: `test_l4_docs.bats` / `test_l4_lint_skill_descriptions.bats` は内容精査の上、削除 or `test_skill_*.bats` へ rename + 書き換え（Open Q3）

**4.3 参照箇所の更新**
- `tests/README.md` から `tests/claude-code/` 参照削除
- `scripts/README.md` から該当参照削除（あれば）
- `.github/workflows/*.yml` から該当 job/step 削除
- `docs/testing-skills.md` の旧パス言及確認

**4.4 #199 (D2) close 連動**
- 本 PR description で `Closes #199` 宣言

## Non-Goals

- **`scripts/` / `.github/workflows/` の "L4" 表記置換** — D3 (#200) の責務
- **`docs/` の "L4" 表記置換** — D4 (#201) の責務
- **`tests/e2e/<skill>.bats` の新規追加** — #196 (C1) と B 系列 (#190-#195) の責務
- **`scripts/run-skill-e2e.sh` の機能拡張** — #222 で完了済、本 PR は call 元としての利用のみ
- **CHANGELOG.md の旧用語履歴削除** — 履歴として保持
- **`evals/` ディレクトリ削除** — E3 (#204) の責務

## Open Questions

1. **`fixtures/minimal-project/` の継承可否** — 現状の `tests/e2e/defining-requirements.bats` が `fixtures/` 配下を参照していないかを plan フェーズで grep 確認。参照がなければ完全削除採用。

2. **`analyze-token-usage.py` の用途継続性** — `tests/claude-code/run-skill-tests.sh` 以外から呼ばれていないか grep 確認の上、参照ゼロなら完全削除。再利用が必要になれば別 Issue で `scripts/` 配下に再実装。

3. **`test_l4_docs.bats` / `test_l4_lint_skill_descriptions.bats` の処置** — plan フェーズで両ファイル中身を確認した上で確定。3 つの選択肢:
   - (a) 完全削除（廃止対象依存の場合）
   - (b) `test_skill_docs.bats` / `test_skill_description_lint.bats` への rename + 新フロー対応書き換え
   - (c) 別 Issue 化（Unit Test 再実装）
