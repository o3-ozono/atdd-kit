# Test Strategy: QA

Issue #2: feat: session-start で Agent Teams 環境変数を自動設定する

## 1. AC ごとのテスト層選定

| AC | テスト層 | 理由 |
|----|---------|------|
| AC1: 毎セッション自動設定 | 構造テスト (BATS/grep) | session-start SKILL.md に Phase 1-G の手順が正しく記述されているかを検証。ランタイム動作は LLM が SKILL.md の指示に従って実行するため、指示の正確性を検証することが最も重要。 |
| AC2: 既存設定の保持 | 構造テスト (BATS/grep) | SKILL.md に「既に設定済みなら変更しない」旨の条件分岐が記述されているかを検証。 |
| AC3: settings.local.json 非存在時 | 構造テスト (BATS/grep) | SKILL.md に非存在時の新規作成手順が記述されているかを検証。 |
| AC4: autopilot Prerequisites Check | 構造テスト (BATS/grep) | commands/autopilot.md の Prerequisites Check セクションにフォールバック案内が記述されているかを検証。既存テストパターン（test_autopilot_agent_teams_setup.bats）と同じ手法。 |
| AC5: ドキュメント | 構造テスト (BATS/grep) | docs/workflow-detail.md と commands/autopilot.md に前提要件が記載されているかを検証。 |

**設計判断:** このリポジトリのテストは全て BATS による構造テスト（マークダウン指示書の内容を grep で検証）であり、ランタイムの統合テストは存在しない。この方針を踏襲する。LLM が実行するスキルの「正しい指示が書かれているか」を検証することがこのリポジトリにおけるテストの目的である。

## 2. 具体的なテストケース

### テストファイル: `tests/test_session_start_agent_teams_env.bats`

新規テストファイルとして作成する。session-start の Agent Teams 環境変数自動設定に特化した構造テスト。

```bash
#!/usr/bin/env bats

# Issue #2: session-start Agent Teams env auto-configuration tests

SKILL="skills/session-start/SKILL.md"
AUTOPILOT="commands/autopilot.md"
WORKFLOW_DETAIL="docs/workflow-detail.md"

# ===========================================================================
# AC1: 毎セッション自動設定 — Phase 1-G の手順が SKILL.md に存在
# ===========================================================================

@test "AC1: session-start has Phase 1-G Agent Teams env setup step" {
  grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "$SKILL"
}

@test "AC1: session-start references settings.local.json for env config" {
  grep -q 'settings.local.json' "$SKILL"
}

@test "AC1: session-start sets env value to 1" {
  grep -q '"1"' "$SKILL"
  grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "$SKILL"
}

@test "AC1: Phase 1-G step exists in session-start" {
  # Phase 1 の情報収集セクション内に G ステップがある
  sed -n '/## Phase 1/,/## Phase 2/p' "$SKILL" | grep -qi 'Agent Teams\|CLAUDE_CODE_EXPERIMENTAL'
}

# ===========================================================================
# AC2: 既存設定の保持 — 設定済みなら変更しない指示が存在
# ===========================================================================

@test "AC2: session-start has skip condition for existing setting" {
  # 既に設定されている場合はスキップする条件分岐の記述
  grep -qi 'already\|既に\|exist\|設定済み\|skip\|スキップ' "$SKILL" || \
  sed -n '/CLAUDE_CODE_EXPERIMENTAL/,/^### /p' "$SKILL" | grep -qi 'already\|exist\|設定済み\|skip'
}

# ===========================================================================
# AC3: settings.local.json 非存在時の新規作成
# ===========================================================================

@test "AC3: session-start handles missing settings.local.json" {
  # ファイルが存在しない場合の処理が記述されている
  sed -n '/CLAUDE_CODE_EXPERIMENTAL\|Agent Teams.*env\|Phase 1.*G/,/^### \|^## /p' "$SKILL" \
    | grep -qi 'not exist\|missing\|存在しない\|creat\|作成'
}

# ===========================================================================
# AC4: autopilot Prerequisites Check のフォールバック案内
# ===========================================================================

@test "AC4: autopilot Prerequisites Check mentions CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" {
  sed -n '/### Prerequisites Check/,/^## \|^### [^P]/p' "$AUTOPILOT" \
    | grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
}

@test "AC4: autopilot Prerequisites Check mentions settings.local.json" {
  sed -n '/### Prerequisites Check/,/^## \|^### [^P]/p' "$AUTOPILOT" \
    | grep -q 'settings.local.json'
}

@test "AC4: autopilot Prerequisites Check has STOP on Agent Teams failure" {
  sed -n '/### Prerequisites Check/,/^## \|^### [^P]/p' "$AUTOPILOT" \
    | grep -q 'STOP'
}

# ===========================================================================
# AC5: ドキュメントに前提要件が記載
# ===========================================================================

@test "AC5: workflow-detail.md mentions CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" {
  grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "$WORKFLOW_DETAIL"
}

@test "AC5: autopilot Prerequisites section mentions env requirement" {
  grep -A 10 '## Prerequisites' "$AUTOPILOT" | grep -qi 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS\|Agent Teams.*env\|env.*Agent Teams'
}

# ===========================================================================
# Regression: 既存の session-start 構造を破壊しない
# ===========================================================================

@test "regression: session-start still has Phase 0 update step" {
  grep -q '## Phase 0' "$SKILL"
}

@test "regression: session-start still has Phase 1 info gathering" {
  grep -q '## Phase 1' "$SKILL"
}

@test "regression: session-start still has Phase 2 status assessment" {
  grep -q '## Phase 2' "$SKILL"
}

@test "regression: session-start still has Phase 3 summary report" {
  grep -q '## Phase 3' "$SKILL"
}

@test "regression: session-start still references check-plugin-version.sh" {
  grep -q 'check-plugin-version' "$SKILL"
}

@test "regression: autopilot still has Phase 0.9 Agent Teams Setup" {
  grep -q '## Phase 0.9: Agent Teams Setup' "$AUTOPILOT"
}
```

## 3. カバレッジ戦略

### 構造テスト（BATS/grep）でカバーする範囲

| 検証対象 | カバレッジ |
|---------|-----------|
| SKILL.md に Phase 1-G が存在する | AC1 の核心 |
| SKILL.md に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` が記述されている | AC1 |
| SKILL.md に `settings.local.json` の参照がある | AC1 |
| SKILL.md に既存設定のスキップ条件がある | AC2 |
| SKILL.md にファイル非存在時の作成手順がある | AC3 |
| autopilot.md の Prerequisites Check に env var 案内がある | AC4 |
| autopilot.md の Prerequisites Check に STOP がある | AC4 |
| workflow-detail.md に前提要件の記載がある | AC5 |
| autopilot.md の Prerequisites に env 要件がある | AC5 |

### 構造テストでカバーできない範囲（手動検証）

| 検証対象 | 理由 |
|---------|------|
| JSON の正しいマージ（既存キー保持） | LLM のランタイム動作であり、grep では検証不可 |
| env キー自体が存在しない場合の処理 | 条件分岐のロジックはランタイムでのみ確認可能 |
| 空ファイル・不正 JSON の場合の挙動 | エッジケースはランタイムでのみ確認可能 |

**手動検証手順:** 実装完了後、以下の手順で確認する:
1. `.claude/settings.local.json` を削除した状態で session-start を実行 -> ファイルが作成されることを確認
2. `.claude/settings.local.json` に `env` なしの状態で session-start を実行 -> `env` が追加されることを確認
3. `.claude/settings.local.json` に既に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` がある状態で session-start を実行 -> 変更されないことを確認

## 4. リグレッションリスク分析

### 既存テストとの重複チェック

| 既存テストファイル | 重複状況 | 対応 |
|------------------|---------|------|
| `test_autopilot_agent_teams_setup.bats` | AC-7 の Prerequisites テスト（L12-26）が AC4/AC5 と部分的に重複。ただし既存は `workflow-config.yml` と `agents/` の存在チェックのみで、env var の案内テストはない。 | 重複なし。新規テストは env var 案内に特化するため棲み分け可能。 |
| `test_agent_teams.bats` | AC2 の「autopilot.md references Agent Teams」が AC5 と概念的に重複。ただし既存は Agent Teams アーキテクチャ全体のテストであり、env var の記載テストではない。 | 重複なし。 |
| `test_session_start_version.bats` | session-start の Phase 1 に関するテスト。Phase 1-G の追加により Phase 1 の構造が変わるが、既存テストは `check-plugin-version.sh` 関連のみなので影響なし。 | リグレッションテストに Phase 1 存在チェックを追加済み。 |
| `test_session_start_auto_sync.bats` | session-start の auto-sync テスト。Phase 1 の別ステップなので影響なし。 | 影響なし。 |
| `test_session_start_adapters.bats` | 「skill_adapters が session-start に存在しない」ことを検証。影響なし。 | 影響なし。 |
| `test_session_start_task_recommendation.bats` | Task Recommendation Rules のテスト。Phase 3 に関するテストで、Phase 1-G とは無関係。 | 影響なし。 |
| `test_doc_agent_teams_sync.bats` | ドキュメントの Agent Teams 関連記述テスト。AC5 の workflow-detail.md テストと概念的に近いが、既存は auto-implement/auto-review の除去を検証するものであり、env var 記載のテストではない。 | 重複なし。 |

### リグレッションリスク

| リスク | 重大度 | 対策 |
|--------|--------|------|
| SKILL.md の Phase 1 セクション構造変更により、既存の Phase 1 grep テストが壊れる | 低 | 既存テスト（test_session_start_version.bats 等）は `check-plugin-version` 等の固有文字列を grep しており、Phase 1 のサブセクション追加では壊れない。 |
| autopilot.md の Prerequisites Check 変更により、既存テスト（test_autopilot_agent_teams_setup.bats L12-26）が壊れる | 低 | 既存テストは `## Prerequisites` ヘッダと `workflow-config.yml`, `agents/` の存在を検証。env var 案内を追加しても既存テキストを削除しなければ影響なし。 |
| settings.local.json の操作が settings.json の既存設定に影響 | なし | AC は settings.local.json を対象としており、settings.json には触れない。完全に分離されている。 |

## 5. テストファイル構成

### 新規作成

| ファイル | 目的 |
|---------|------|
| `tests/test_session_start_agent_teams_env.bats` | AC1-AC5 の全テストケースと regression テストを格納 |

### 命名規則

既存の session-start テストファイルの命名パターンに従う:
- `test_session_start_version.bats` — バージョンチェック
- `test_session_start_auto_sync.bats` — 自動同期
- `test_session_start_recent_activity.bats` — 最近のアクティビティ
- `test_session_start_task_recommendation.bats` — タスク推奨
- **`test_session_start_agent_teams_env.bats`** — Agent Teams 環境変数 (new)

### 既存テストとの関係

```
tests/
  test_session_start_agent_teams_env.bats  # [NEW] AC1-AC5 + regression
  test_session_start_version.bats          # [既存] 影響なし
  test_session_start_auto_sync.bats        # [既存] 影響なし
  test_session_start_adapters.bats         # [既存] 影響なし
  test_session_start_recent_activity.bats  # [既存] 影響なし
  test_session_start_task_recommendation.bats  # [既存] 影響なし
  test_autopilot_agent_teams_setup.bats    # [既存] 影響なし（env var テストなし）
  test_agent_teams.bats                    # [既存] 影響なし
```

### テスト数サマリー

| カテゴリ | テスト数 |
|---------|---------|
| AC1: 毎セッション自動設定 | 4 |
| AC2: 既存設定の保持 | 1 |
| AC3: 非存在時の新規作成 | 1 |
| AC4: autopilot フォールバック案内 | 3 |
| AC5: ドキュメント記載 | 2 |
| Regression | 6 |
| **合計** | **17** |
