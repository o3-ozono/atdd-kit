# Plan Review — QA Perspective (Issue #36)

**対象:** `docs/decisions/unified-plan.md`
**Reviewer:** QA Agent
**Date:** 2026-04-12

---

## Test Layer Validity

### 判定: PASS

**BATS / grep（AC1/AC4/AC5/AC6/AC7/AC8）**
変更対象が `skills/discover/SKILL.md` のプロンプトテキストであり、構造・用語・テンプレート配置の検証に BATS + grep を採用する判断は適切。LLM ランタイムを介さない静的検証として必要十分。

**skill-creator eval（AC2/AC3/AC9）**
成果物の内容（"三層構造が含まれているか" / "DoD のみか"）は BATS では検証できず、eval を選択することは正しい。eval は LLM 出力に対する structural assertion で検証するため、AC の Then 条件と直接対応する。

**E2E 不要の判断**
SKILL.md の変更はプロンプト定義のみで UI/API/DB 変更を伴わない。E2E を省略する判断は合理的。

**1件の懸念（INFO レベル）**
AC2/AC3 の eval は「LLM が正しい構造を出力するか」を検証するが、「モデルが実際に DoD 導出ステップを実行したか」（プロセスの検証）は検証できない。テスト層の限界としてプランに記載があれば十分だが、現行の unified-plan.md にはこの限界が明記されていない。

---

## Coverage Strategy

### 判定: PASS（1件の軽微な指摘あり）

**網羅性チェック**

| AC | テスト手段 | Then 条件に対応しているか |
|----|---------|-------------------------|
| AC1: DoD 導出ステップが実行される | BATS grep（各フロー） | 各フローセクションに DoD 導出ステップが存在することを確認 — OK |
| AC2: 三層構造が導出される | eval A8/A9 + 既存 A1-A7 | DoD・User Story・Given/When/Then の三要素を assertion で確認 — OK |
| AC3: 非コードタスクで DoD のみ | eval C1/C2更新/C5追加 | DoD のみ / User Story・G/W/T が含まれないことを確認 — OK |
| AC4: Completion Criteria 廃止 | BATS negative grep | "Completion Criteria" の不在を確認 — OK |
| AC5: テンプレートで DoD が先頭 | BATS 行番号順序チェック | DoD セクション行が User Story 行より前であることを確認 — OK |
| AC6: Bug Flow に DoD（Root Cause より前） | BATS + eval B6 | DoD 行 < Root Cause 行の順序チェック + eval assertion — OK |
| AC7: Refactoring 固有 DoD 必須項目 | BATS grep | 文言の存在確認 — OK（但し後述の指摘 P1 あり） |
| AC8: plan が新ヘッダを読める | BATS grep（plan Step 1） | "DoD" ヘッダへの対応が記述されていることを確認 — OK |
| AC9: eval regression guard | auto-eval + baseline 比較 | pass_rate ≥ 0.9 — OK |

**指摘 P1（SHOULD）: AC7 の grep 対象文言が実装に依存しすぎる**

現行テスト設計（test-strategy-qa.md）では AC7 の BATS テストが `外部.*動作\|observable.*behavior\|behavior.*unchanged\|externally` を grep する。実装者が「外部から観測可能」ではなく「ユーザーが観測できる動作を変更しない」等の言い回しを採用した場合、正しく実装されていても BATS が FAIL する。

推奨: grep パターンをより広く、または "外部動作不変" に相当する概念であれば複数の表現でマッチするよう調整するか、テストの説明コメントに許容する表現のガイドを追加する。

---

## Eval Update Plan

### 判定: PASS（1件の懸念あり）

**追加 assertion の妥当性**

| Assertion | AC の Then 条件との対応 | 判定 |
|-----------|----------------------|------|
| A8: DoD セクションが User Story より前 | AC5 の Then「DoD セクションが先頭に配置」に完全対応 | OK |
| A9: DoD セクションが存在し完了条件がリスト化 | AC2 の Then「DoD が含まれる」に対応 | OK |
| B6: DoD セクションが Root Cause より前 | AC6 の Then「先頭（Root Cause の前）」に対応 | OK |
| C1 更新: DoD セクションが検証可能な項目リスト | AC3 の Then「DoD のみが含まれる」に対応 | OK |
| C2 更新: User Story と G/W/T が含まれず DoD のみ | AC3 の Then（否定条件）に直接対応 | OK |
| C5 追加: "Completion Criteria" の表記なし | AC4 の Then「用語廃止」に対応 | OK |

**懸念 P2（MUST）: documentation eval の expected_output フィールドが更新されていない**

evals.json の `id=2` (documentation) の `expected_output` フィールドは現在:

```
"expected_output": "Verifiable completion criteria as checklist, approach exploration, no Given/When/Then (docs flow uses completion criteria instead)"
```

このフィールドは "completion criteria" を基準として記述されており、変更後は "DoD" 形式になる。`expected_output` は評価の文脈説明として使われるため、不正確なまま残ると eval runner が誤った基準で判定する可能性がある。unified-plan.md の Eval 更新計画に `expected_output` の更新が含まれていない。

**P2 対処:** `id=2` の `expected_output` を以下に更新する計画を追加すること:
```
"expected_output": "Verifiable DoD items as list (not Given/When/Then), approach exploration, no User Story, no Acceptance Criteria section"
```

**懸念 P3（SHOULD）: eval id=0 の expected_output も更新が必要**

`id=0` (dev-feature) の `expected_output` に DoD の言及がない（現在は "user story, 3+ ACs" のみ）。eval runner がこのフィールドを参照して A8/A9 の合否を判定する場合、expected_output に DoD を追記しないと基準が不整合になる。

---

## Baseline Comparison Procedure

### 判定: PASS

**手順の実行可能性**

1. `baseline.json` の pass_rate=1.0 を確認 — 現在の `baseline.json` で確認済み（1.0）
2. SKILL.md + evals.json 変更後 `auto-eval` 実行 — `auto-eval` スキルが存在することを確認済み
3. pass_rate ≥ 0.9 を確認 — 閾値は承認済み AC9 と一致
4. FAIL 時に SKILL.md を修正して再実行 — フィードバックループとして適切
5. PASS 後に `baseline.json` を更新 — baseline 更新の責任が明確

**閾値 0.9 の妥当性**

- 現 baseline は全 eval が 1.0 (pass_rate=1.0, 3 eval / 16 assertions)
- 新規追加 assertion は A8/A9/B6/C5 の 4 件（C1/C2 は更新）
- 合計 assertion 数は 16 → 20 件になる
- 10% 低下 = 20 件中 2 件まで FAIL を許容する計算
- 新規 assertion が一時的に FAIL する可能性（実装途中の実行時）を考慮すると、FINAL 検証時には pass_rate=1.0 を目標にすべきだが、段階的実装中の閾値として 0.9 は許容範囲

**懸念 P4（INFO）: "PASS 後に baseline.json を更新" のタイミングが曖昧**

コミット戦略と baseline 更新タイミングの対応が unified-plan.md に記載されていない。コミット #8（AC9）のタイミングで baseline.json を更新するのか、最終コミット #9 に含めるのかを明確にすることを推奨。

---

## Test Duplication / Conflict Check

### 判定: PASS（1件の要確認あり）

**既存テストとの重複確認**

| 既存テストファイル | 新規 `test_discover_dod_structure.bats` との関係 |
|-------------------|-----------------------------------------------|
| `test_discover_approach_parity.bats` | Step 2 の equal-detail ルールを対象。DoD 変更と無関係。競合なし |
| `test_discover_autopilot_approval.bats` | Step 7/8 の autopilot 分岐を対象。DoD 変更と無関係。競合なし |
| `test_legacy_terms.bats` | `type:investigation` 等の旧用語を対象。"Completion Criteria" は対象外。競合なし |
| `test_task_type_workflow.bats` | autopilot.md のタスクタイプ別分岐を対象。discover SKILL.md と無関係。競合なし |

**要確認 P5（SHOULD）: `test_legacy_terms.bats` への将来的な影響**

AC4 で "Completion Criteria" が discover SKILL.md から廃止されるが、`test_legacy_terms.bats` はこの用語を旧用語としてチェックしていない。将来の保守性のため、"Completion Criteria" を `test_legacy_terms.bats` の検査対象（discover SKILL.md 限定）に追加することを検討する価値があるが、今回のスコープ外として SHOULD 扱い。

**BATS テストケースの重複なし**

`test_discover_dod_structure.bats` の 9 テストケースはすべて新規の対象（DoD 構造・用語・順序・Refactoring 必須項目・plan 対応）であり、既存テストとの assertion レベルでの重複は確認されない。

---

## Verdict

APPROVE WITH CHANGES

P2（documentation eval の `expected_output` 更新漏れ）は evals.json の eval 品質に直接影響するため実装前に修正が必要。P1（AC7 grep パターンの脆弱性）は実装者への注意事項として plan に追記することを推奨。その他の指摘（P3/P4/P5）は SHOULD/INFO レベルであり実装を止める必要はない。

---

## 指摘一覧

| # | 重要度 | 対象 | 内容 |
|---|--------|------|------|
| P1 | SHOULD | AC7 テスト | grep パターンが実装の文言に依存しすぎる。許容表現のガイドを追加するか、パターンを広くする |
| P2 | MUST | evals.json id=2 | `expected_output` フィールドに "completion criteria" が残っており更新が必要 |
| P3 | SHOULD | evals.json id=0 | `expected_output` に DoD の言及がなく A8/A9 の評価基準と不整合 |
| P4 | INFO | AC9 手順 | `baseline.json` 更新タイミングをコミット戦略と対応付けて明確化 |
| P5 | SHOULD | `test_legacy_terms.bats` | 将来保守のため "Completion Criteria" を旧用語リストに追加することを検討 |
