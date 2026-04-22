#!/usr/bin/env bats
# @covers: skills/plan/SKILL.md
# Tests for Issue #41: Agent Composition in plan deliverables
# AC1-AC7: plan SKILL.md and autopilot.md changes

SKILL_FILE="skills/plan/SKILL.md"
AUTOPILOT_FILE="commands/autopilot.md"

# ---------------------------------------------------------------------------
# AC2: SKILL.md Step 4 と Step 6 に Agent Composition が組み込まれている
# ---------------------------------------------------------------------------

@test "AC2a: SKILL.md Step 4 contains Agent Composition derivation step" {
  run grep -n "Agent Composition" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  # Step 4 セクション内に存在することを確認
  run awk '/^### Step 4/,/^### Step [^4]/' "$SKILL_FILE"
  echo "$output" | grep -q "Agent Composition"
}

@test "AC2b: SKILL.md Step 6 template contains ### Agent Composition header" {
  run grep -n "### Agent Composition" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  # Step 6 テンプレートブロック内に存在することを確認
  run awk '/^### Step 6/,/^### Step [^6]/' "$SKILL_FILE"
  echo "$output" | grep -q "### Agent Composition"
}

@test "AC2c: SKILL.md Step 6 template has Role/Count/Focus columns" {
  # Agent Composition テーブルに必要な3列が存在する
  run grep -A 5 "### Agent Composition" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Role"
  echo "$output" | grep -q "Count"
  echo "$output" | grep -q "Focus"
}

# ---------------------------------------------------------------------------
# AC3: Readiness Check に Variable-Count Agents 行が追加されている
# ---------------------------------------------------------------------------

@test "AC3a: Readiness Check contains Variable-Count Agents row" {
  run grep -n "Variable-Count Agents" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "AC3b: Readiness Check has Bad example with unresolved count" {
  # Bad 例: "Reviewer x N" のような人数未定表記
  run grep -n "Reviewer x N" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "AC3c: Readiness Check has Good example with concrete count and focus" {
  # Good 例: 具体的な人数と観点が示されている
  run grep -n "Reviewer x 2" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AC4: autopilot.md Variable-Count Agents セクションが plan-based に改訂
# (旧承認手順の削除を negative grep で確認)
# ---------------------------------------------------------------------------

@test "AC4a: autopilot.md no longer contains old approval step text" {
  # 旧手順: "presents the proposed composition to the user for approval"
  run grep -n "presents the proposed composition to the user for approval" "$AUTOPILOT_FILE"
  [ "$status" -ne 0 ]
}

@test "AC4b: autopilot.md Variable-Count Agents section references plan-based spawn" {
  # 新フロー: plan 承認済み構成から spawn することが明記されている
  run grep -n "plan" "$AUTOPILOT_FILE"
  [ "$status" -eq 0 ]
  # Variable-Count Agents セクション内に plan への言及があること
  run awk '/^### Variable-Count Agents/,/^##[^#]/' "$AUTOPILOT_FILE"
  echo "$output" | grep -q "plan"
}

@test "AC4c: autopilot.md Variable-Count Agents section has no 4-step approval flow" {
  # 旧フローの 4 ステップ（1. PO determines / 2. PO presents / 3. User approves / 4. User rejects）がない
  run awk '/^### Variable-Count Agents/,/^##[^#]/' "$AUTOPILOT_FILE"
  [ "$status" -eq 0 ]
  # "User approves" → PO spawns というステップが消えている
  echo "$output" | grep -qv "User approves → PO spawns"
}

# ---------------------------------------------------------------------------
# AC5: autopilot.md Plan Review Round に Agent Composition レビュー観点
# (Developer only, QA には含まれない)
# ---------------------------------------------------------------------------

@test "AC5a: Plan Review Round Developer instruction contains Agent Composition" {
  run awk '/^## Plan Review Round/,/^## Phase [0-9]/' "$AUTOPILOT_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Agent Composition"
}

@test "AC5b: Agent Composition appears in Developer review instruction (not QA)" {
  # Developer の観点ブロックに Agent Composition が含まれている
  run awk '/\*\*Developer:\*\*/,/\*\*QA:\*\*/' "$AUTOPILOT_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Agent Composition"
}

# ---------------------------------------------------------------------------
# AC6: docs/ に旧承認フロー記述が残存しない
# ---------------------------------------------------------------------------

@test "AC6: docs/ (excluding decisions/) contains no old spawn approval flow reference" {
  # "presents the proposed composition to the user for approval" が docs/ に残っていない
  # docs/decisions/ は Decision Trail（工程ドキュメント）のため除外
  run grep -r --exclude-dir=decisions "presents the proposed composition to the user for approval" docs/
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# AC7: mid-phase resume で plan 未完了時に安全停止する記述が存在する
# ---------------------------------------------------------------------------

@test "AC7: autopilot.md Phase 0.9 mid-phase resume has plan absence STOP handling" {
  # Phase 0.9 の mid-phase resume セクションに plan コメント不在時の STOP 記述が存在する
  run awk '/^## Phase 0\.9/,/^## Phase [1-9]/' "$AUTOPILOT_FILE"
  [ "$status" -eq 0 ]
  # "plan" と "STOP" が mid-phase resume コンテキスト内に存在すること
  echo "$output" | grep -q "plan"
  echo "$output" | grep -qi "stop\|STOP"
}
