# Plan: tests/claude-code/ 廃止（#198 / D1 + #199 / D2 統合）

> 注: B3 (#190 writing-plan-and-tests skill) 未実装期間の手動代行。形式は `templates/docs/issues/plan.md`（superpowers writing-plans 形式）に準拠。

## Implementation

### A. tests/claude-code/ ディレクトリの完全削除

- [ ] `git rm tests/claude-code/run-skill-tests.sh tests/claude-code/test-helpers.sh tests/claude-code/analyze-token-usage.py tests/claude-code/README.md`
- [ ] verify: `ls tests/claude-code/*.sh tests/claude-code/*.py tests/claude-code/*.md 2>&1 | grep "No such"` で対象消失確認

- [ ] `git rm -r tests/claude-code/samples/`
- [ ] verify: `ls tests/claude-code/samples 2>&1` → `No such file or directory`

- [ ] `git rm -r tests/claude-code/fixtures/`
- [ ] verify: `ls tests/claude-code/fixtures 2>&1` → `No such file or directory`

- [ ] 空になった `tests/claude-code/` を確認（git は空ディレクトリを保持しないため自然に消滅）
- [ ] verify: `ls tests/claude-code 2>&1` → `No such file or directory`

### B. test_l4_*.bats の整理（D2 #199 統合）

- [ ] `git rm tests/test_l4_samples.bats tests/test_l4_test_helpers.bats tests/test_l4_run_skill_tests.bats tests/test_l4_analyze_token_usage.bats tests/test_l4_docs.bats`
- [ ] verify: `ls tests/test_l4_*.bats 2>&1 | grep -v lint_skill` で対象 5 件消失確認

- [ ] `git mv tests/test_l4_lint_skill_descriptions.bats tests/test_skill_description_lint.bats`
- [ ] verify: `ls tests/test_l4_*.bats 2>&1` → `No such ...`, `ls tests/test_skill_description_lint.bats` → 存在

- [ ] `tests/test_skill_description_lint.bats` 内のコメント行 `# test_l4_lint_skill_descriptions.bats -- AC4: ...` を `# test_skill_description_lint.bats -- skill description anti-pattern linter` に更新（中身ロジックは保持）
- [ ] verify: `grep -n "test_l4_" tests/test_skill_description_lint.bats` → 0 hit

- [ ] `grep -r "test_l4_" tests/` 全体確認
- [ ] verify: 出力が 0 件

### C. 参照箇所のクリーンアップ

- [ ] `tests/README.md` から `tests/claude-code/` への参照を全削除（言及されているディレクトリ説明セクションごと削除 or `tests/e2e/` 説明に置換）
- [ ] verify: `grep "claude-code" tests/README.md` → 0 hit

- [ ] `scripts/README.md` に `tests/claude-code/` 参照があれば削除
- [ ] verify: `grep "claude-code" scripts/README.md 2>&1 | grep -v "No such"` → 0 hit

- [ ] `.github/workflows/*.yml` の `tests/claude-code/` 参照を削除（job/step 単位で適切に廃止）
- [ ] verify: `grep -r "tests/claude-code" .github/workflows/` → 0 hit

- [ ] `docs/testing-skills.md` / `docs/guides/testing-skills.md` の旧パス言及を確認・削除
- [ ] verify: `grep -rn "tests/claude-code" docs/ 2>&1 | grep -v "docs/issues/"` → 0 hit

- [ ] 上記以外の参照を全体 grep で残存検知
- [ ] verify: `grep -r "tests/claude-code" docs/ scripts/ rules/ .github/ tests/ commands/ skills/ 2>&1 | grep -v "docs/issues/198-"` → 0 hit

### D. PR description の更新

- [ ] PR #225 description を本 Plan 完了状態で更新（D2 #199 統合完了 + Open Q1/Q2/Q3 解決方針を反映）
- [ ] verify: `gh pr view 225 --json body` に `Closes #199` と Open Q 解決状況が含まれる

- [ ] PR #225 を Draft → Ready 化（reviewer 引き渡し）
- [ ] verify: `gh pr view 225 --json isDraft` で `isDraft=false`

## Testing

- [ ] `bats tests/*.bats` フルスイート実行で green 確認（削除/rename 後）
- [ ] verify: 全 test pass、exit 0

- [ ] `tests/test_skill_terminology_grep.bats` が pass（旧用語残存 0 hit を維持）
- [ ] verify: `bats tests/test_skill_terminology_grep.bats` green

- [ ] `tests/test_skill_description_lint.bats` が rename 後も green（中身ロジック保持確認）
- [ ] verify: `bats tests/test_skill_description_lint.bats` green

- [ ] `scripts/run-skill-e2e.sh --all --dry-run` を PR 前後で実行し output 比較
- [ ] verify: PR 前後で stdout が同一（外部観測動作不変、CS-1 を機械検証）

## Finishing

- [ ] CHANGELOG.md Unreleased セクションに `Removed: tests/claude-code/ legacy SAT harness and tests/test_l4_*.bats (D1+D2)` を追加
- [ ] verify: `head -30 CHANGELOG.md` に該当エントリあり

- [ ] CI 全 PASS を待機
- [ ] verify: `gh pr checks 225` で全 check ✅
