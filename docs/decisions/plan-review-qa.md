# Plan Review: QA

Issue #7: feat: autopilot 完了時に Agent Team を削除する

## Review Summary

**Verdict: PASS with 2 recommendations**

テスト戦略は既存パターンに適合しており、AC カバレッジも十分。2 点の追加テストケースを推奨する。

## 1. テスト層の妥当性

**判定: 適切**

| AC | 提案層 | QA 評価 |
|----|--------|---------|
| AC1: Phase 0.9 ToolSearch に TeamDelete | Unit (BATS grep) | 適切 — ドキュメント構造の検証 |
| AC2: Phase 5 で TeamDelete 実行 | Unit (BATS grep) | 適切 — ワークフロー定義にステップが存在するか検証 |
| AC3: Phase 5 ステップ順序 | Unit (BATS grep) | 適切 — 行番号比較による順序検証は既存パターン (`test_worktree_isolation.bats`) と一貫 |
| AC4: 既存テスト整合性 | Unit (BATS) | 適切 — 全 BATS スイート実行で回帰確認 |

全テスト層が `test_autopilot_agent_teams_setup.bats` および `test_worktree_isolation.bats` の既存パターンと一致している。変更対象がマークダウンのワークフロー定義のみであるため、E2E / Integration テストは不要（TeamDelete の実行自体は Claude Code ハーネスの責務）。

## 2. カバレッジ戦略の網羅性

### カバーされている範囲

- Phase 0.9 の ToolSearch に TeamDelete が含まれること
- Phase 5 に TeamDelete ステップが存在すること
- ステップ順序: ExitWorktree -> TeamDelete -> git checkout main
- 既存テスト全パス

### 推奨 R1: Phase 5 の Tools annotation 更新テスト

Phase 5 は現在 `**Tools:** Bash (gh), ExitWorktree` と宣言している。TeamDelete 追加後は Tools annotation にも反映が必要。既存テストスイートには全 Phase の Tools annotation を検証するテスト群（AC-5 シリーズ、L175-217）が存在するため、整合性のためにこのテストを追加すべき:

```bash
@test "#7-AC2: Phase 5 Tools annotation includes TeamDelete" {
  grep -A 3 "## Phase 5" "$AUTOPILOT" | grep -q "TeamDelete"
}
```

**根拠:** 既存の AC-5 テスト群が全 Phase の Tools annotation を網羅的に検証しており、TeamDelete が Tools に含まれないと AC-5 テストのパターンと不整合が生じる。

### 推奨 R2: TeamDelete のスコープ限定テスト

TeamDelete が Phase 0.9（ToolSearch）と Phase 5（実行）以外に誤って追加されていないことを検証する否定テスト:

```bash
@test "#7: TeamDelete only referenced in Phase 0.9 and Phase 5" {
  count=$(grep -c "TeamDelete" "$AUTOPILOT")
  # Phase 0.9 ToolSearch (1) + Phase 5 Tools annotation (1) + Phase 5 step (1) = 3
  [ "$count" -ge 2 ] && [ "$count" -le 4 ]
}
```

**根拠:** TeamDelete は破壊的操作であり、Phase 5 以外で誤って呼ばれるとセッション中のチームが消える。スコープ限定テストで安全網を張る。

## 3. 境界条件とエッジケース

### TeamDelete 失敗時の扱い

Plan に TeamDelete 失敗時のハンドリングが含まれていない。以下の理由で **追加不要** と判断:

1. Phase 5 の TeamDelete 時点でマージ完了（Step 4）、ラベル削除済み（Step 5）、worktree 削除済み（Step 6）
2. TeamDelete 失敗の影響は「不要なチームリソースが残る」のみ — コード・リポジトリ状態への影響なし
3. Phase 0.9 の「失敗時 STOP」パターンはセットアップ（前提条件）向け。Phase 5 のクリーンアップは best-effort が適切
4. TeamDelete にエラーハンドリングを追加するとワークフロー定義が複雑化し、可読性が低下する

### チームが既に存在しない場合

外部クリーンアップやタイムアウトでチームが消えている場合、TeamDelete は冪等であるべき。これは Claude Code ハーネスの責務であり、autopilot ワークフロー側のテストは不要。

### リベース後の Phase 5 再実行

マージコンフリクト（Step 3）でリベース → Phase 4 → Phase 5 再実行のパスでもチームは存在し続ける。提案された配置（ExitWorktree 後、git checkout main 前）はこのパスでも正しく動作する。追加テスト不要。

## 4. 既存テストとのリグレッションリスク

**判定: リスク低**

| 既存テスト | 影響箇所 | リスク |
|-----------|---------|--------|
| `test_autopilot_agent_teams_setup.bats` AC-5 Phase 5 Tools annotation (L211-213) | Phase 5 の `**Tools:**` 行を変更 | **注意** — `grep -A 3 "## Phase 5" | grep '\*\*Tools:\*\*'` は Tools 行の存在のみ検証するため、内容を変更しても既存テストは壊れない |
| `test_worktree_isolation.bats` AC3 Phase 5 ExitWorktree (L53-58) | Phase 5 の ExitWorktree 行 | なし — ExitWorktree 行は移動・削除しない |
| その他全テスト | Phase 0.9 ToolSearch 行の変更 | なし — 既存テストは ToolSearch 行の内容（TeamCreate, SendMessage）を個別 grep しており、TeamDelete 追加で壊れない |

**唯一の注意点:** Phase 5 のステップ番号が変わる（ExitWorktree が Step 6 → TeamDelete 挿入で番号がずれる可能性）。既存テストはステップ番号ではなくキーワード grep なので影響なし。

## 5. AC との整合性

| AC | Plan の変更内容 | テストカバレッジ | 整合性 |
|----|----------------|----------------|--------|
| AC1 | Phase 0.9 ToolSearch に TeamDelete 追加 | grep テスト | OK |
| AC2 | Phase 5 に TeamDelete ステップ追加 | grep テスト + Tools annotation テスト (R1) | OK |
| AC3 | ステップ順序 ExitWorktree → TeamDelete → git checkout main | 行番号比較テスト | OK |
| AC4 | 既存テスト全パス + 新テストケース追加 | BATS スイート全実行 | OK |

**スコープ逸脱チェック:** 変更ファイルは `commands/autopilot.md` + `tests/test_autopilot_agent_teams_setup.bats` + ハウスキーピング（CHANGELOG, version bump）のみ。AC 範囲に収まっており逸脱なし。

## 6. 結論

テスト戦略は健全で、既存パターンとの一貫性がある。推奨 R1（Tools annotation テスト）と R2（スコープ限定テスト）を追加することでカバレッジが強化される。R1 は特に重要（既存 AC-5 テスト群との整合性維持）。TeamDelete 失敗時のハンドリングは不要と判断。
