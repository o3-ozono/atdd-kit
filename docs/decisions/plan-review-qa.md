# Plan Review: QA

Issue #2: feat: session-start で Agent Teams 環境変数を自動設定する

## Review Summary

**Verdict: PASS**

統合 Plan は AC との整合性が取れており、テスト戦略も妥当。変更は全て additive で既存動作を壊すリスクが低い。以下に詳細フィードバックを記載する。

## 1. テスト層の妥当性

**判定: 適切**

全テストを BATS 構造テスト（grep ベース）で行う方針はこのリポジトリのテストパターンに完全に合致している。

- このリポジトリのテストは全て「マークダウン指示書の内容を grep で検証する」パターン
- ランタイム統合テスト（実際に settings.local.json を操作する）は存在しない
- スキルの「正しい指示が書かれているか」を検証することがテストの目的

Developer の実装戦略で提案されたテストケースと QA のテスト戦略で提案されたテストケースの間にアプローチの差異がある。統合 Plan ではこの差異を解決する必要がある:

| 観点 | Developer 版テスト | QA 版テスト |
|------|-------------------|-------------|
| AC1 Phase 配置 | `awk` で Phase 1 内の `### G.` セクションを特定 | `sed -n '/Phase 1/,/Phase 2/'` で Phase 1 セクション内を検証 |
| AC2 deep-merge | `grep -q 'deep-merge\|merge'` | `grep -qi 'preserv\|既に\|exist\|設定済み\|skip'` |
| AC4 error message | `grep -A 5 'not found'` でエラーメッセージ近傍を検証 | `sed -n '/Prerequisites Check/,/^##/'` でセクション全体を検証 |

**推奨:** Developer 版のテストケースの方が具体的かつ精度が高い（特に AC1 の `### G.` ヘッダ検出と AC4 のエラーメッセージ近傍 grep）。実装時には Developer 版をベースに、QA 版の regression テスト（6件）を追加する形で統合するのが望ましい。

## 2. カバレッジ戦略の網羅性

**判定: 十分（1点補足あり）**

### カバーされている範囲

| AC | テストで検証する内容 | カバレッジ |
|----|-------------------|-----------|
| AC1 | SKILL.md に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` + `settings.local.json` + Phase 1-G の記述あり | 十分 |
| AC2 | SKILL.md に deep-merge / preserve の指示あり | 十分 |
| AC3 | SKILL.md に非存在時の作成手順あり | 十分 |
| AC4 | autopilot.md のエラーメッセージに env var + settings.local.json の案内あり | 十分 |
| AC5 | workflow-detail.md + autopilot.md Prerequisites に記載あり | 十分 |

### 補足: Developer 版テストに含まれていないが QA 版に含まれるもの

QA テスト戦略の regression テスト 6 件は Plan のテスト数（17件）に含まれている。Developer の実装戦略テスト案には regression テストが含まれていないため、実装時に追加が必要。

| テスト | 目的 |
|--------|------|
| Phase 0 存在チェック | SKILL.md の構造が壊れていないことを確認 |
| Phase 1 存在チェック | 同上 |
| Phase 2 存在チェック | 同上 |
| Phase 3 存在チェック | 同上 |
| check-plugin-version 参照チェック | 既存機能の維持確認 |
| autopilot Phase 0.9 存在チェック | autopilot.md の構造が壊れていないことを確認 |

これらは変更量が少ない（additive な挿入のみ）ため必須ではないが、安全網として有用。

### 構造テストでカバーできない範囲

テスト戦略に記載した手動検証手順（3パターン）は Plan に含まれていない。実装完了後の手動確認として Developer/QA が実施すべき:

1. settings.local.json が存在しない状態で session-start を実行
2. settings.local.json に env キーがない状態で session-start を実行
3. settings.local.json に既に設定済みの状態で session-start を実行

## 3. 既存テストとのリグレッションリスク

**判定: リスク低**

テスト戦略での分析結果を再確認し、Plan の変更ファイルリストと突合した。

| 変更ファイル | 影響を受ける可能性のある既存テスト | リスク |
|-------------|-------------------------------|--------|
| `skills/session-start/SKILL.md` | `test_session_start_version.bats`, `test_session_start_auto_sync.bats`, `test_session_start_adapters.bats`, `test_session_start_recent_activity.bats`, `test_session_start_task_recommendation.bats` | なし -- 既存テストは各自の固有文字列を grep しており、Phase 1 末尾へのセクション追加では壊れない |
| `commands/autopilot.md` | `test_autopilot_agent_teams_setup.bats` | なし -- 既存テストは `## Prerequisites` 直下 10 行を grep。env var 行を追加しても既存行を削除しなければ影響なし |
| `docs/workflow-detail.md` | `test_doc_agent_teams_sync.bats` | なし -- 既存テストは `auto-implement`/`auto-review` の除去と Agent Teams 参照を検証。line 69 の更新は影響しない |

**唯一の注意点:** `test_autopilot_agent_teams_setup.bats` L215-217 の Session Initialization テスト:

```bash
@test "AC-5: Tools annotation in Session Initialization" {
  grep -A 3 "### Prerequisites Check" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}
```

このテストは `### Prerequisites Check` 直下 3 行に `**Tools:**` が存在することを検証する。Prerequisites Check セクションの冒頭を変更しなければ影響なし。Plan では Prerequisites Check のステップ 3 のエラーメッセージを変更するだけなので問題ない。

## 4. AC との整合性

**判定: 完全にカバー**

| AC | Plan の変更ファイル | テストでカバー | 整合性 |
|----|-------------------|---------------|--------|
| AC1 | `skills/session-start/SKILL.md` Phase 1-G | AC1 テスト x4 | OK |
| AC2 | `skills/session-start/SKILL.md` Phase 1-G (deep-merge 指示) | AC2 テスト x1 | OK |
| AC3 | `skills/session-start/SKILL.md` Phase 1-G (非存在時) | AC3 テスト x1 | OK |
| AC4 | `commands/autopilot.md` Prerequisites Check エラーメッセージ | AC4 テスト x3 | OK |
| AC5 | `commands/autopilot.md` Prerequisites + `docs/workflow-detail.md` | AC5 テスト x2 | OK |

**スコープ逸脱チェック:**
- Plan の変更ファイル 7 個のうち、AC に直接対応するのは #1-#4。#5-#7 はハウスキーピング（CHANGELOG, version bump, tests README）で妥当。
- README.md / README.ja.md の変更が Plan に含まれていないが、Developer の AC レビューで言及されていた。AC5 は `docs/workflow-detail.md` と `commands/autopilot.md` を対象としており、README は AC 範囲外。スコープ逸脱を避けるため、Plan の現状（README 変更なし）が正しい。

## 5. 追加の指摘事項

### 5a. Developer テストと QA テストの統合方針

Plan では「17テスト」としているが、Developer 版テスト案（12件）と QA 版テスト案（17件）のどちらをベースにするかが明示されていない。

**推奨:** Developer 版テスト案（AC ごとのテスト 12 件）をベースに、QA 版の regression テスト 6 件を追加し、重複を除いた最終セットを確定する。重複する AC1-AC5 テストは Developer 版の方が assertion の精度が高い。

### 5b. 不正 JSON の扱い

Developer の AC レビューで提案された「不正 JSON の場合は warn して skip」が実装戦略に含まれている。テストで「不正 JSON を warn する」指示の存在を grep で検証するテストケースを追加することを推奨する:

```bash
@test "AC1: session-start handles invalid JSON gracefully" {
  grep -qi 'invalid JSON\|invalid json\|不正.*JSON' skills/session-start/SKILL.md
}
```

### 5c. 実装順序の妥当性

Step 1 (SKILL.md) -> Step 2 (autopilot.md, workflow-detail.md) -> Step 3 (tests) -> Step 4 (housekeeping) の順序は、依存関係の流れに合致しており妥当。テストを Step 3 に配置することで、Step 1-2 の実装内容を即座に検証できる。
