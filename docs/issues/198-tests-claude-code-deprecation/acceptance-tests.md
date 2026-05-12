# Acceptance Tests: tests/claude-code/ 廃止（#198 / D1 + #199 / D2 統合）

> 注: B3 (#190) 未実装期間の手動代行。形式は `templates/docs/issues/acceptance-tests.md`（state marker: planned/draft/green/regression）に準拠。FS / CS は `user-stories.md` 参照。

## AT-001: tests/claude-code/ ディレクトリ完全消滅 (FS-1)

- [ ] [planned] AT-001: tests/claude-code/ directory removed
  - **Given:** PR #225 適用後の HEAD
  - **When:** `ls tests/claude-code/ 2>&1` を実行
  - **Then:** `No such file or directory` を含む出力（exit non-zero）

## AT-002: test_l4_*.bats 5 件削除 + 1 件 rename (FS-2)

- [ ] [planned] AT-002: legacy l4 tests removed and renamed
  - **Given:** PR #225 適用後の HEAD
  - **When:** `ls tests/test_l4_*.bats 2>&1` および `ls tests/test_skill_description_lint.bats` を実行
  - **Then:** `test_l4_*.bats` glob は 0 件マッチ、`test_skill_description_lint.bats` は存在

## AT-003: test_l4_ 参照 0 件 (FS-2)

- [ ] [planned] AT-003: no l4 references in tests/
  - **Given:** PR #225 適用後の HEAD
  - **When:** `grep -r "test_l4_" tests/`
  - **Then:** 0 hit (exit 1)

## AT-004: tests/claude-code 参照 0 件 (FS-3)

- [ ] [planned] AT-004: no tests/claude-code references
  - **Given:** PR #225 適用後の HEAD
  - **When:** `grep -r "tests/claude-code" docs/ scripts/ rules/ .github/ tests/ commands/ skills/ 2>&1 | grep -v "docs/issues/198-"` を実行（CHANGELOG.md / `docs/issues/` は除外）
  - **Then:** 0 hit

## AT-005: #199 close 連動 (FS-4)

- [ ] [planned] AT-005: PR #225 closes #199
  - **Given:** PR #225 description 更新後
  - **When:** `gh pr view 225 --json closingIssuesReferences` を実行
  - **Then:** `closingIssuesReferences` に Issue 番号 198 と 199 の両方が含まれる

## AT-006: 外部観測動作不変 (CS-1)

- [ ] [planned] AT-006: skill-e2e dry-run identical before and after
  - **Given:** main HEAD 時点の `scripts/run-skill-e2e.sh --all --dry-run` の output を baseline として記録
  - **When:** PR #225 適用後の HEAD で `scripts/run-skill-e2e.sh --all --dry-run` を実行
  - **Then:** stdout が baseline と完全一致（diff 0 件）

## AT-007: 旧用語残存検知 pass (CS-2)

- [ ] [planned] AT-007: terminology grep pass
  - **Given:** PR #225 適用後の HEAD
  - **When:** `bats tests/test_skill_terminology_grep.bats` を実行
  - **Then:** pass（旧用語残存 0 hit）

## AT-008: BATS フルスイート green (CS-3)

- [ ] [planned] AT-008: full BATS suite green
  - **Given:** PR #225 適用後の HEAD
  - **When:** `bats tests/*.bats` を実行
  - **Then:** 全 test pass、exit 0

## AT-009: CI 全 PASS (CS-3)

- [ ] [planned] AT-009: CI all green
  - **Given:** PR #225 が push 完了している
  - **When:** `gh pr checks 225` を実行
  - **Then:** 全 check が success、failure / pending なし

## AT-010: rename 後 lint test 動作確認 (FS-2)

- [ ] [planned] AT-010: renamed lint test still green
  - **Given:** `tests/test_skill_description_lint.bats` (rename 後)
  - **When:** `bats tests/test_skill_description_lint.bats` を実行
  - **Then:** 全 case pass（rename 前と同等の挙動を維持）

## ライフサイクル

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装（本ファイル現在の状態） |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
