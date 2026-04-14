#!/usr/bin/env bats

# Issue #138 / #34: Agent Teams architecture tests
# Agent definitions live in agents/*.md

# --- AC1 (#34): 7 agent definitions with model/effort ---

@test "AC1: all 7 agent definitions exist" {
  for agent in po developer qa researcher tester reviewer writer; do
    [[ -f "agents/${agent}.md" ]]
  done
}

@test "AC1: PO agent has model opus and effort high" {
  grep -q 'model:.*opus' agents/po.md
  grep -q 'effort:.*high' agents/po.md
}

@test "AC1: non-PO agents have model sonnet and effort high" {
  for agent in developer qa researcher tester reviewer writer; do
    grep -q 'model:.*sonnet' "agents/${agent}.md"
    grep -q 'effort:.*high' "agents/${agent}.md"
  done
}

@test "AC1: tester agent has verify skill" {
  grep -q 'atdd-kit:verify' agents/tester.md
}

@test "AC1: reviewer agent has Agent tool" {
  grep -q 'Agent' agents/reviewer.md
}

@test "AC1: writer agent has Write and Edit tools" {
  grep -q 'Write' agents/writer.md
  grep -q 'Edit' agents/writer.md
}

@test "AC1: no old role name (implementer) in agents/" {
  local result
  result=$(grep -rl 'implementer' agents/ 2>/dev/null || true)
  [[ -z "$result" ]]
}

@test "AC1: workflow-config template no longer exists" {
  [[ ! -f "templates/workflow-config.yml.tmpl" ]]
}

# --- AC2: autopilot end-to-end flow ---

@test "AC2: autopilot.md has Phase 1 discover" {
  grep -qi 'Phase.*1.*discover\|Phase.*discover' commands/autopilot.md
}

@test "AC2: autopilot.md has AC Review Round" {
  grep -q '## AC Review Round\|AC.*Review.*Round\|AC.*レビュー' commands/autopilot.md
}

@test "AC2: autopilot.md has Phase for plan" {
  grep -qi 'Phase.*plan\|Plan.*作成\|Plan.*策定' commands/autopilot.md
}

@test "AC2: autopilot.md references Developer agent" {
  grep -qi 'Developer.*agent\|Developer' commands/autopilot.md
}

@test "AC2: autopilot.md references QA agent" {
  grep -qi 'QA.*agent\|QA' commands/autopilot.md
}

@test "AC2: autopilot.md has merge decision phase" {
  grep -qi 'merge\|マージ判断' commands/autopilot.md
}

# --- AC3: AC Review Round ---

@test "AC3: autopilot.md AC Review Round has PO perspective" {
  grep -qi 'PO.*requirement\|PO.*completeness\|PO.*business\|PO.*要件\|PO.*網羅\|PO.*ビジネス' commands/autopilot.md
}

@test "AC3: autopilot.md AC Review Round has Dev perspective" {
  grep -qi 'Developer.*architectural\|Developer.*technical\|Developer.*edge cases\|Dev.*アーキテクチャ\|Dev.*技術\|Dev.*エッジケース' commands/autopilot.md
}

@test "AC3: autopilot.md AC Review Round has QA perspective" {
  grep -qi 'QA.*testability\|QA.*boundary\|QA.*coverage\|QA.*テスト\|QA.*境界\|QA.*カバレッジ' commands/autopilot.md
}

# --- AC4: Plan Review Round ---

@test "AC4: autopilot.md has Plan Review Round" {
  grep -q '## Plan Review Round\|Plan.*Review.*Round\|Plan.*レビュー' commands/autopilot.md
}

@test "AC4: autopilot.md Plan Review Round has Dev perspective" {
  grep -qi 'Developer.*file structure\|Developer.*implementation order\|Developer.*technical risk\|Dev.*ファイル構成\|Dev.*実装順序\|Dev.*技術リスク' commands/autopilot.md
}

@test "AC4: autopilot.md Plan Review Round has QA perspective" {
  grep -qi 'QA.*test layer\|QA.*coverage strategy\|QA.*テスト層\|QA.*カバレッジ戦略' commands/autopilot.md
}

# --- AC5: PO Cross-Cutting Check ---

@test "AC5: autopilot.md checks mergeable" {
  grep -q 'mergeable' commands/autopilot.md
}

@test "AC5: autopilot.md mentions CONFLICTING" {
  grep -q 'CONFLICTING' commands/autopilot.md
}

@test "AC5: autopilot.md mentions rebase" {
  grep -qi 'rebase' commands/autopilot.md
}

# --- AC6: auto-* commands ---

@test "AC6: auto-implement.md does not exist" {
  [[ ! -f commands/auto-implement.md ]]
}

@test "AC6: auto-review.md does not exist" {
  [[ ! -f commands/auto-review.md ]]
}

@test "AC6: auto-sweep.md still exists" {
  [[ -f commands/auto-sweep.md ]]
}
