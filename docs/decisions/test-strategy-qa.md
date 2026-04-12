# Test Strategy -- QA

Issue #3: bug: discover の autopilot モード検出が PO 直接呼び出しを認識しない

## 1. Outer Loop (Story Test)

- **User Story:** autopilot PO として、discover/plan/atdd を Skill tool で直接呼び出した際に autopilot モードが正しく検出されてほしい。そうすることで、AUTOPILOT-GUARD 警告のスキップと承認フロー制御が正しく動作する。
- **Test layer:** Integration (BATS)
- **Rationale:** 対象は SKILL.md / autopilot.md のプロンプトテキスト。実行環境不要で、テキストパターン検証で十分。BATS の sed + grep パターンで cross-file consistency を含む統合検証が可能。E2E は不要（LLM 実行を伴わないテキスト仕様変更のため）。

## 2. AC ごとのテスト層選定

| AC | テスト層 | Rationale |
|----|---------|-----------|
| AC1: discover の `--autopilot` 検出 | Unit (BATS) | SKILL.md 内の4箇所（HARD-GATE, AUTOPILOT-GUARD, Step 7, Step 8）のテキストパターン検証 |
| AC2: discover Standalone モード維持 | Unit (BATS) | Step 7/Step 8 の standalone 分岐テキストが維持されていることの検証 |
| AC3: plan の `--autopilot` 検出 | Unit (BATS) | AUTOPILOT-GUARD 内のテキストパターン検証 |
| AC4: atdd の `--autopilot` 検出 | Unit (BATS) | AUTOPILOT-GUARD 内のテキストパターン検証 |
| AC5: autopilot.md の `--autopilot` 付与 | Unit (BATS) | Phase 1, Phase 3 の Skill 呼び出しテキスト検証 |
| AC6: 既存テスト全件 PASS | Integration (BATS) | テストファイル自体の更新。`bats tests/` 実行で全件 PASS を確認 |

## 3. 具体的なテストケース設計

### テストファイル

既存の `tests/test_discover_autopilot_approval.bats` を更新する。新規テストファイルは作成しない（同一テーマ・同一ファイル群を対象としているため）。

### ファイルヘッダ / 変数

```bash
#!/usr/bin/env bats

# Issue #3: discover の autopilot モード検出が PO 直接呼び出しを認識しない
# Tests verify --autopilot flag detection in discover, plan, atdd, and autopilot

DISCOVER="skills/discover/SKILL.md"
PLAN="skills/plan/SKILL.md"
ATDD="skills/atdd/SKILL.md"
AUTOPILOT="commands/autopilot.md"
```

Note: 既存の `OVERRIDES` 変数は使用されていないため削除。`PLAN` と `ATDD` を追加。

---

### AC1: discover の --autopilot 検出 (6テスト)

```bash
# --- AC1: --autopilot フラグで autopilot モード検出 ---

@test "AC1: HARD-GATE autopilot exception references --autopilot flag" {
  local hard_gate
  hard_gate=$(sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$DISCOVER")
  echo "$hard_gate" | grep -q '\-\-autopilot'
}

@test "AC1: HARD-GATE exception requires BOTH --autopilot AND AC Review Round" {
  local hard_gate
  hard_gate=$(sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$DISCOVER")
  echo "$hard_gate" | grep -q '\-\-autopilot'
  echo "$hard_gate" | grep -qi 'AC Review Round'
}

@test "AC1: AUTOPILOT-GUARD uses --autopilot flag for mode detection" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER")
  echo "$guard" | grep -q '\-\-autopilot'
}

@test "AC1: Step 7 autopilot branch uses --autopilot flag" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -q '\-\-autopilot'
}

@test "AC1: Step 7 autopilot mode outputs draft AC and skips approval" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi 'draft'
  echo "$step7" | grep -qi 'skip'
}

@test "AC1: Step 8 autopilot skip references --autopilot flag" {
  local step8
  step8=$(sed -n '/### Step 8/,/^---$/p' "$DISCOVER")
  echo "$step8" | grep -q '\-\-autopilot'
}
```

---

### AC2: Standalone モード維持 (3テスト -- 既存テスト継続)

```bash
# --- AC2: standalone mode preserves approval gate ---

@test "AC2: Step 7 standalone mode preserves approval request text" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -qi 'Approve.*Needs revision\|approve'
}

@test "AC2: Step 8 standalone mode preserves Issue comment posting" {
  local step8
  step8=$(sed -n '/### Step 8/,/^---$/p' "$DISCOVER")
  echo "$step8" | grep -q 'gh issue comment'
}

@test "AC2: Step 8 standalone mode preserves inline plan execution" {
  local step8
  step8=$(sed -n '/### Step 8/,/^---$/p' "$DISCOVER")
  echo "$step8" | grep -qi 'inline.*plan\|plan.*inline\|plan.*Core.*Flow'
}
```

Note: 既存テスト #7, #8, #9 をそのまま維持。assertion パターンは standalone パスのテキストを検証しており、`--autopilot` 変更に影響されない。

---

### AC3: plan の --autopilot 検出 (1テスト -- 新規)

```bash
# --- AC3: plan の AUTOPILOT-GUARD ---

@test "AC3: plan AUTOPILOT-GUARD uses --autopilot flag" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$PLAN")
  echo "$guard" | grep -q '\-\-autopilot'
}
```

---

### AC4: atdd の --autopilot 検出 (1テスト -- 新規)

```bash
# --- AC4: atdd の AUTOPILOT-GUARD ---

@test "AC4: atdd AUTOPILOT-GUARD uses --autopilot flag" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$ATDD")
  echo "$guard" | grep -q '\-\-autopilot'
}
```

---

### AC5: autopilot.md の --autopilot 付与 (2テスト -- 新規)

```bash
# --- AC5: autopilot.md の Skill 呼び出しに --autopilot 付与 ---

@test "AC5: autopilot Phase 1 discover call includes --autopilot" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -q '\-\-autopilot'
}

@test "AC5: autopilot Phase 3 atdd call includes --autopilot" {
  local phase3
  phase3=$(sed -n '/## Phase 3/,/## Phase 4/p' "$AUTOPILOT")
  echo "$phase3" | grep -q '\-\-autopilot'
}
```

---

### Negative tests: 旧方式除去の確認 (3テスト -- 新規)

```bash
# --- REGRESSION: <teammate-message> 旧方式が除去されている ---

@test "REGRESSION: discover AUTOPILOT-GUARD does not use teammate-message for detection" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER")
  ! echo "$guard" | grep -q 'teammate-message'
}

@test "REGRESSION: plan AUTOPILOT-GUARD does not use teammate-message for detection" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$PLAN")
  ! echo "$guard" | grep -q 'teammate-message'
}

@test "REGRESSION: atdd AUTOPILOT-GUARD does not use teammate-message for detection" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$ATDD")
  ! echo "$guard" | grep -q 'teammate-message'
}
```

---

### Cross-file consistency (2テスト -- 既存テスト更新)

```bash
# --- Cross-file consistency ---

@test "discover HARD-GATE and autopilot AC Review Round are consistent on approval flow" {
  grep -qi 'AC Review Round' "$DISCOVER"
  grep -qi 'approval' "$AUTOPILOT"
}

@test "discover autopilot exception is documented in HARD-GATE, not just Step 7" {
  local hard_gate
  hard_gate=$(sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$DISCOVER")
  echo "$hard_gate" | grep -qi '\-\-autopilot\|AC Review Round'
}
```

Note: テスト #15 はそのまま維持。テスト #16 は `autopilot\|AC Review Round` → `\-\-autopilot\|AC Review Round` に更新（より厳密に。ただし optional -- 現行でも PASS する）。

---

### Autopilot AC Review Round テスト (5テスト -- 既存テスト維持)

```bash
# --- autopilot AC Review Round (既存テスト -- 変更なし) ---

@test "autopilot AC Review Round posts Issue comment after user approval" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -q 'gh issue comment'
}

@test "autopilot Issue comment is posted AFTER approval, not before" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  local approval_line comment_line
  approval_line=$(echo "$acr" | grep -ni 'approv' | head -1 | cut -d: -f1)
  comment_line=$(echo "$acr" | grep -ni 'gh issue comment' | head -1 | cut -d: -f1)
  [[ -n "$approval_line" ]]
  [[ -n "$comment_line" ]]
  [[ "$approval_line" -lt "$comment_line" ]]
}

@test "autopilot AC Review Round mentions Three Amigos integration" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -qi 'Three Amigos'
}

@test "autopilot AC Review Round has reject handling" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -qi 'reject'
}

@test "reject triggers PO modification, not AC Review Round restart" {
  local acr
  acr=$(sed -n '/## AC Review Round/,/## Phase 2/p' "$AUTOPILOT")
  echo "$acr" | grep -qi 'PO.*修正\|PO.*modif\|PO.*revise\|PO.*correct'
}
```

## 4. 既存テスト更新計画

### `test_discover_autopilot_approval.bats` 全18テスト

| # | 既存テスト名 | 対応 | 詳細 |
|---|------------|------|------|
| 1 | AC5: HARD-GATE contains autopilot exception clause | **更新** | `teammate-message` grep → `--autopilot` grep。テスト名も AC1 に付け替え |
| 2 | AC5: HARD-GATE exception requires BOTH teammate-message AND AC Review Round approval | **更新** | テスト名・assertion を `--autopilot` + AC Review Round に変更 |
| 3 | AC1: Step 7 has autopilot-mode conditional branch | **更新** | `teammate-message\|autopilot` → `--autopilot` に厳密化 |
| 4 | AC1: Step 7 autopilot mode outputs draft AC without approval request | **維持** | `draft` grep は変更不要 |
| 5 | AC1: Step 7 autopilot mode skips approval request | **統合** | テスト #4 と統合して「outputs draft AC and skips approval」に |
| 6 | AC1: Step 8 has autopilot skip instruction | **更新** | `--autopilot` を含む assertion に強化 |
| 7 | AC2: Step 7 standalone mode preserves approval request text | **維持** | standalone パスは変更なし |
| 8 | AC2: Step 8 standalone mode preserves Issue comment posting | **維持** | standalone パスは変更なし |
| 9 | AC2: Step 8 standalone mode preserves inline plan execution | **維持** | standalone パスは変更なし |
| 10 | AC4: autopilot AC Review Round posts Issue comment after user approval | **維持** | autopilot.md の AC Review Round は変更なし |
| 11 | AC4: autopilot Issue comment is posted AFTER approval, not before | **維持** | 順序検証は変更なし |
| 12 | AC3: autopilot AC Review Round mentions Three Amigos integration | **維持** | 変更なし |
| 13 | AC3: autopilot AC Review Round has reject handling | **維持** | 変更なし |
| 14 | AC3: reject triggers PO modification, not AC Review Round restart | **維持** | 変更なし |
| 15 | Cross-file: HARD-GATE and autopilot AC Review Round are consistent | **維持** | `teammate-message` に依存していない |
| 16 | Cross-file: autopilot exception is documented in HARD-GATE | **更新 (optional)** | `--autopilot` に厳密化 |

**まとめ:**
- **更新:** 4件 (#1, #2, #3, #6) + 1件 optional (#16)
- **維持:** 11件 (#7-#15)
- **統合:** 1件 (#4 + #5 → 1テスト)
- **削除:** 0件
- **新規追加:** 7件 (AC1-GUARD, AC3, AC4, AC5 x2, REGRESSION x3)

### 最終テスト数

18 (既存) - 1 (統合) + 7 (新規) = **24件**

## 5. カバレッジ戦略

### 境界条件

| 境界条件 | テストの有無 | 対応 |
|---------|------------|------|
| `--autopilot` が引数の唯一の要素 | テスト不要 | SKILL.md はプロンプト記述。LLM が `--autopilot` の存在を判定するため、位置の厳密なテストは不適切 |
| `--autopilot` と Issue 番号の順序 | テスト不要 | 同上 |
| typo（`--auto-pilot`, `-autopilot`） | テスト不要 | LLM の引数解釈の問題であり、テキストパターンテストの対象外 |
| Bug Flow Step 5 の autopilot 分岐 | カバー済み | Step 5 は "same as development flow Step 7" と参照。Step 7 テスト (AC1) で間接カバー |

### エッジケース

| エッジケース | テストの有無 | 対応 |
|------------|------------|------|
| ユーザーが standalone で `--autopilot` を付けた場合 | テスト不要 | ユーザーの意図的な操作。ブロックしない方針 |
| HARD-GATE と AUTOPILOT-GUARD の一貫性 | テストあり | AC1 のテストで HARD-GATE と GUARD の両方を検証 |
| 3つの SKILL.md 間の一貫性 | テストあり | AC1 (discover), AC3 (plan), AC4 (atdd) + REGRESSION negative tests |

## 6. リグレッションリスク分析

### 影響範囲

`teammate-message` を grep しているテストは `test_discover_autopilot_approval.bats` のみ（tests/ 配下全43ファイルを確認済み）。他のテストファイルへの影響はない。

### リスク一覧

| リスク | 影響度 | 発生確率 | 対策 |
|--------|-------|---------|------|
| 既存テスト #1, #2 が FAIL | 高 | 確実 | AC6: テスト更新で対応 |
| 既存テスト #3 が assertion 緩すぎで PASS するが不正確 | 低 | 中 | `--autopilot` に厳密化 |
| plan/atdd の AUTOPILOT-GUARD 変更で他テストが FAIL | 低 | なし | 他テストに plan/atdd GUARD テストは存在しない |
| autopilot.md Phase 1 変更で test_po_dev_qa.bats が FAIL | 低 | なし | `Phase.*1.*discover` パターンは `--autopilot` 追加後も PASS |
| autopilot.md Phase 1 変更で test_autopilot_args.bats が FAIL | 低 | なし | 引数解析テストで Skill 呼び出し記述に依存していない |

### 既存機能の安全性

以下の機能は変更の影響を受けない:
- AC Review Round フロー（autopilot.md のこのセクションは変更なし）
- Plan Review Round フロー（変更なし）
- Phase 3-5 フロー（Phase 3 の atdd 呼び出しに `--autopilot` 追加のみ）
- discover Development Flow Steps 1-6（変更なし）
- discover Bug Flow Steps 1-4, 6（変更なし）
- plan Core Flow Steps 1-8（AUTOPILOT-GUARD のみ変更）
- atdd 全フロー（AUTOPILOT-GUARD のみ変更）
