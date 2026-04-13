# Plan Review — QA (Issue #41)

**Issue:** #41 — feat: エージェント構成を plan の成果物に含め、plan 承認時にまとめて承認する
**Reviewer:** QA
**Date:** 2026-04-13
**Sources:**
- `docs/decisions/test-strategy-qa.md`
- `docs/decisions/impl-strategy-developer.md`
- `docs/decisions/ac-review-qa.md`

---

## 総合評価

PASS

---

## 指摘事項

### P1 (MUST): `test_interaction_reduction.bats` の plan SKILL.md 依存テストへの影響確認が必要

`tests/test_interaction_reduction.bats` に以下のテストが存在する:

```bash
@test "AC15: plan SKILL.md has risk classification section with color indicators" {
  grep -q '🔴\|🟡\|🟢' skills/plan/SKILL.md
}

@test "AC15: plan SKILL.md has risk classification criteria" {
  grep -qi 'risk.*classif\|リスク.*分類\|design.*policy\|設計ポリシー' skills/plan/SKILL.md
}
```

`skills/plan/SKILL.md` の Step 4 に Agent Composition 導出ステップを追加する際、Step 7（Risk-based Approval Classification）の `🔴🟡🟢` セクションが保持されていることを確認する必要がある。これらのテストは既存テストであり、実装後に `bats tests/test_interaction_reduction.bats` で PASS することを確認すること。

**対応:** 実装者（Developer）への周知事項。Verification Plan に「`bats tests/test_interaction_reduction.bats` の PASS 確認」を追加することを推奨。

### P2 (MUST): eval id=0 の `expected_output` 更新後に既存 A1/A2 が FAIL するリスク

`skills/plan/evals/evals.json` id=0 の `expected_output` を「agent composition を含む plan 出力」に更新した場合、既存 assertion A1（「State Gate チェックを実行している」）と A2（「plan の本体フローに進んでいる」）が誤 FAIL するリスクがある。

`expected_output` の更新後に auto-eval を実行して A1/A2 の PASS を確認すること。

**対応:** Commit 4（tests）の後に auto-eval 実行ステップを Verification Plan に追加すること。

### INFO: `test_autopilot_agent_teams_setup.bats` は影響なし

当該テストの実際の grep パターンを確認した結果:
- Variable-Count Agents の承認手順（`presents the proposed composition` 等）を直接参照するテストは存在しない
- Phase 4 のテスト (`AC-2: Phase 4 uses SendMessage or spawns Reviewer agents`) は `SendMessage\|Reviewer\|PO` の存在確認のみで、承認手順テキストには依存していない

本変更（Variable-Count Agents 承認手順の削除）による `test_autopilot_agent_teams_setup.bats` への影響はないと判断する。

---

## 修正提案

### 提案 1: Developer の Verification Plan に auto-eval ステップを明示追加

`impl-strategy-developer.md` Section 6 の Verification Plan に以下を追加:

```bash
# eval regression 確認（P2 対応）
/atdd-kit:auto-eval
# → skills/plan/evals/evals.json id=0 の pass_rate が baseline から低下していないことを確認
```

### 提案 2: Commit 4（tests）前後に `test_interaction_reduction.bats` の実行確認を追加

Commit 4 の実施前後に `bats tests/test_interaction_reduction.bats` を実行し、PASS を確認する手順を Verification Plan に含めること（P1 対応）。

---

## カバレッジ評価

| AC | テスト層 | カバレッジ | 検証漏れ |
|----|---------|----------|---------|
| AC1: plan 成果物に Agent Composition セクション | BATS (3 テスト) + eval A3/A4 | 十分 | なし。Step 6 テンプレートの構造 + LLM 出力の両面をカバー |
| AC2: Step 4 と Step 6 に Agent Composition 組み込み | BATS section-scoped (2 テスト) | 十分 | awk section-scope で「正しいセクション内に存在する」まで担保 |
| AC3: Readiness Check に Agent Composition チェック追加 | BATS (3 テスト: 行の存在 + Bad 例 + Good 例) | 十分 | Bad/Good 例の存在確認まで含めており、フォーマット整合も担保 |
| AC4: autopilot.md Variable-Count Agents セクション plan-based 改訂 | BATS negative x2 + positive x1 | 十分 | 旧手順の削除と新記述の追加の両方を確認。静的検証 AC として適切 |
| AC5: Plan Review Round に Agent Composition レビュー観点追加 | BATS section-scoped (1 テスト) | 適切 | 「QA の観点には含まれない」negative テストが省略されているが、主たる Then 条件（Developer の観点に含まれること）はカバーされており MUST ではない |
| AC6: docs/ との整合 | BATS negative repo-scoped (1 テスト) | 適切 | Developer が `docs/workflow-detail.md` の内容を確認済みで旧フロー言及が限定的。grep で十分 |
| AC7: mid-phase resume 安全停止 | BATS section-scoped (1 テスト) | 適切 | 静的手順記述の存在確認として妥当。ランタイム動作は今回のスコープ外 |

**AC5 の軽微な抜け:** 「QA の SendMessage 指示に Agent Composition が含まれない」ことの negative テストが test-strategy-qa.md に記載されているが、BATS テストケースには明示されていない。主たる Then 条件はカバーされているため MUST ではない。

---

## リグレッションリスク評価

| リスク | 影響度 | 評価 |
|--------|--------|------|
| `test_autopilot_agent_teams_setup.bats` が autopilot.md 変更で誤検知 | 低 | 実際のテスト内容を確認済み。Variable-Count Agents 承認手順への直接依存なし。Phase 4 テストは `SendMessage\|Reviewer\|PO` の存在確認のみで変更対象外。**影響なし** |
| `test_interaction_reduction.bats` が plan SKILL.md 変更で誤検知 | 中 | AC15 のテストが `skills/plan/SKILL.md` の `🔴🟡🟢` と `risk classification` 記述の存在を確認。Step 4 への Agent Composition 追加でこれらが削除されない限り PASS するが、**P1 として実装後の確認を要求する** |
| plan eval (id=0) の expected_output 更新で既存 A1/A2 が FAIL | 低〜中 | A1/A2 の assertion 内容（State Gate チェック実行 + plan 本体フローに進む）は expected_output 文字列変更に依存しない。ただし eval runner の実装によっては expected_output 差分が assertion 評価に影響する可能性があるため **P2 として auto-eval 実行確認を要求する** |
| 既存 in-progress Issue への影響 | 低 | 本変更は autopilot.md の「手順定義」変更であり、既に spawn 済みのセッションには影響しない（新規セッションからの動作変更）。既存セッションへの影響はない |
