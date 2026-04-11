#!/usr/bin/env bats

# Tests for Issue #96: ship skill review gate (HARD-GATE)

SHIP_SKILL="skills/ship/SKILL.md"
PLAN_SKILL="skills/plan/SKILL.md"

# --- AC1: ship SKILL.md に HARD-GATE タグが存在する ---

@test "AC1: ship SKILL.md contains <HARD-GATE> tag" {
  grep -q '<HARD-GATE>' "$SHIP_SKILL"
}

@test "AC1: ship SKILL.md contains </HARD-GATE> closing tag" {
  grep -q '</HARD-GATE>' "$SHIP_SKILL"
}

# --- AC2: HARD-GATE がレビュー完了確認を要求する ---

@test "AC2: HARD-GATE mentions ready-for-PR-review label" {
  # Extract content between HARD-GATE tags and check for label reference
  sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$SHIP_SKILL" | grep -q 'ready-for-PR-review'
}

@test "AC2: HARD-GATE mentions review completion check" {
  # Must mention checking that review is complete/passed before proceeding
  sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$SHIP_SKILL" | grep -qi 'review.*\(pass\|complete\|approved\|removed\)'
}

# --- AC3: Red Flags にレビュースキップが追加されている ---

@test "AC3: Red Flags section includes review skip warning" {
  # Extract from Red Flags section to end of that section and check for skip/review mention
  sed -n '/## Red Flags/,/^## /p' "$SHIP_SKILL" | grep -qi 'skip.*review\|review.*skip'
}

# --- AC4: plan スキルがレビュースキップを提案しない ---

@test "AC4: plan SKILL.md explicitly prohibits skipping review" {
  # plan skill must contain an explicit prohibition against skipping review
  grep -qi 'never.*skip.*review' "$PLAN_SKILL"
}

@test "AC4: plan SKILL.md requires QA process for all tasks" {
  # plan skill must state that every plan goes through the QA process
  grep -qi 'every.*plan.*QA\|regardless.*complexity.*autonomy' "$PLAN_SKILL"
}

# --- AC1-136: Step 7 に具体的なレビューサイクル手順 ---

@test "AC1-136: Step 7 mentions review wait flow" {
  sed -n '/### Step 7/,/### Step 8/p' "$SHIP_SKILL" | grep -qi 'wait for review'
}

@test "AC1-136: Step 7 mentions needs-pr-revision handling" {
  sed -n '/### Step 7/,/### Step 8/p' "$SHIP_SKILL" | grep -q 'needs-pr-revision'
}

# --- AC2-136: Step 7 でレビュースキップ禁止 ---

@test "AC2-136: Step 7 prohibits AskUserQuestion skip options" {
  sed -n '/### Step 7/,/### Step 8/p' "$SHIP_SKILL" | grep -qi 'do not.*AskUserQuestion\|AskUserQuestion.*merge.*skip'
}

@test "AC2-136: Red Flags includes Step 7 skip warning" {
  sed -n '/## Red Flags/,/^## /p' "$SHIP_SKILL" | grep -qi 'offering.*merge.*skip.*AskUserQuestion\|AskUserQuestion.*step 7'
}

# --- AC3-136: Step 8 にレビュー前提条件 ---

@test "AC3-136: Step 8 has review prerequisite check" {
  sed -n '/### Step 8/,/### Step 9/p' "$SHIP_SKILL" | grep -qi 'prerequisite\|review.*complete'
}

@test "AC3-136: Step 8 returns to Step 7 if review incomplete" {
  sed -n '/### Step 8/,/### Step 9/p' "$SHIP_SKILL" | grep -qi 'return to step 7\|step 7.*wait'
}
