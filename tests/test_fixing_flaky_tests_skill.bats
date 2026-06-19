#!/usr/bin/env bats
# @covers: skills/fixing-flaky-tests/SKILL.md
# Unit Test for the fixing-flaky-tests skill (flaky-test-fix lightweight route, #322).
# claude is NOT invoked; structural / wording invariants are checked via grep.
#
# Scope (#322): fixing-flaky-tests is a thin ORCHESTRATION skill for the flaky-test category.
# It reuses existing skills only (no new methodology), chains 5 skills, skips the
# 3 definition skills, overrides bug's hard-coded forward chain WITHOUT editing bug,
# wires platform-aware probabilistic reproduction (failure rate + iterative anchor),
# classifies non-determinism via debugging's Types on a flaky sub-axis,
# specializes the middle gate to cause-agreement (classification + failure rate),
# adds quarantine judgment, promotes Type A to the full route, and keeps the merge User gate.

SKILL_FILE="skills/fixing-flaky-tests/SKILL.md"
BUG_FILE="skills/bug/SKILL.md"
DEBUGGING_FILE="skills/debugging/SKILL.md"
FIXING_BUGS_FILE="skills/fixing-bugs/SKILL.md"

# --- Identity ---------------------------------------------------------------

@test "identity: name field matches directory (fixing-flaky-tests)" {
  local name
  name=$(grep '^name:' "$SKILL_FILE" | sed 's/^name:[[:space:]]*//')
  [ "$name" = "fixing-flaky-tests" ]
}

@test "description: trigger conditions only, no workflow summary (DEVELOPMENT.md Skill Description Field Rules)" {
  local desc
  desc=$(grep '^description:' "$SKILL_FILE")
  # トリガー条件を述べる ("Use when ...")
  echo "$desc" | grep -qiE 'use when|trigger|flaky|intermittent'
  # ワークフロー要約の典型パターン "creates X, then Y, then Z" を含まない
  ! echo "$desc" | grep -qiE 'creates .*then .*then'
}

# --- AT-322-1: skip 3 / chain 5 -------------------------------------------

@test "AT-322-1: chains the 5 flaky-fix skills in order" {
  grep -q 'bug' "$SKILL_FILE"
  grep -q 'debugging' "$SKILL_FILE"
  grep -q 'running-atdd-cycle' "$SKILL_FILE"
  grep -q 'reviewing-deliverables' "$SKILL_FILE"
  grep -q 'merging-and-deploying' "$SKILL_FILE"
}

@test "AT-322-1: skips the 3 full-route definition skills in a 'skip' context" {
  grep -qiE 'skip' "$SKILL_FILE"
  grep -q 'defining-requirements' "$SKILL_FILE"
  grep -q 'extracting-user-stories' "$SKILL_FILE"
  grep -q 'writing-plan-and-tests' "$SKILL_FILE"
}

# --- AT-322-1b: forward-chain override WITHOUT editing bug -----------------

@test "AT-322-1b: documents orchestrator-driven invocation override" {
  grep -qiE 'orchestrator-driven' "$SKILL_FILE"
}

@test "AT-322-1b: chained skills' Next Step is advisory and overridden under this route" {
  grep -qiE 'advisory' "$SKILL_FILE"
  grep -qiE 'override' "$SKILL_FILE"
  grep -qiE 'Next Step' "$SKILL_FILE"
}

@test "AT-322-1b: after bug, invoke debugging (not bug's defining-requirements Next Step)" {
  # bug 完了後 defining-requirements を辿らず debugging を呼ぶ旨
  grep -qiE 'after.*bug.*debugging|bug.*complet.*debugging|bug.*invoke.*debugging|debugging.*next' "$SKILL_FILE"
}

@test "AT-322-1b: bug SKILL.md is unedited (no essential rewrite of reused skills)" {
  run git diff --quiet "$BUG_FILE"
  [ "$status" -eq 0 ]
}

# --- AT-322-2: description trigger-only ------------------------------------

@test "AT-322-2: name is fixing-flaky-tests" {
  grep -q 'fixing-flaky-tests' "$SKILL_FILE"
}

@test "AT-322-2: description contains flaky/intermittent trigger signals" {
  local desc
  desc=$(grep '^description:' "$SKILL_FILE")
  echo "$desc" | grep -qiE 'flaky|intermittent|不安定'
}

# --- AT-322-3: platform-aware probabilistic reproduction -------------------

@test "AT-322-3: reproduction step branches per platform (other / web / iOS)" {
  grep -qiE 'platform' "$SKILL_FILE"
  grep -qiE 'other|bats|loop' "$SKILL_FILE"
  grep -q 'playwright-cli' "$SKILL_FILE"
  grep -qiE 'Xcode|simulator' "$SKILL_FILE"
  grep -q 'sim-pool' "$SKILL_FILE"
}

@test "AT-322-3: records failure rate (failure count / total runs)" {
  grep -qiE 'failure rate|失敗率' "$SKILL_FILE"
}

@test "AT-322-3: single-run execution is not accepted as reproduction confirmation" {
  grep -qiE 'single.?run|単発' "$SKILL_FILE"
}

@test "AT-322-3: playwright-cli / Xcode MCP are external references, not atdd-kit-owned" {
  grep -qiE 'external skill|external (tool|MCP)|external reference' "$SKILL_FILE"
}

# --- AT-322-4: iterative failing anchor → N-consecutive-green oracle -------

@test "AT-322-4: anchor turns red with non-zero probability in repeated execution" {
  grep -qiE 'non-zero probability|一定確率|at least once' "$SKILL_FILE"
}

@test "AT-322-4: convergence requires N consecutive greens (not single green)" {
  grep -qiE 'N consecutive|N 回連続' "$SKILL_FILE"
}

@test "AT-322-4: single-run green is not accepted as convergence" {
  grep -qiE 'single.?run.*not.*convergence|single.?run.*not.*収束|単発.*収束としない|単発 green を収束としない' "$SKILL_FILE"
}

# --- AT-322-5: non-determinism categories under debugging Types ------------

@test "AT-322-5: all 5 non-determinism categories appear in skill" {
  grep -qiE 'timing|タイミング' "$SKILL_FILE"
  grep -qiE 'order.?dependent|順序依存' "$SKILL_FILE"
  grep -qiE 'shared.?state|共有状態' "$SKILL_FILE"
  grep -qiE 'external.?depend|外部依存' "$SKILL_FILE"
  grep -qiE 'resource.?leak|リソースリーク' "$SKILL_FILE"
}

@test "AT-322-5: categories framed under debugging Type C sub-axis (not as new Type axis)" {
  grep -qiE 'Type C|sub.?axis' "$SKILL_FILE"
  grep -qiE 'debugging' "$SKILL_FILE"
}

@test "AT-322-5: debugging SKILL.md is unedited" {
  run git diff --quiet "$DEBUGGING_FILE"
  [ "$status" -eq 0 ]
}

# --- AT-322-6: cause-agreement middle gate before ATDD ---------------------

@test "AT-322-6: middle gate specialized to cause-agreement" {
  grep -qiE 'cause-agreement' "$SKILL_FILE"
}

@test "AT-322-6: gate approval target includes non-determinism classification + failure rate" {
  grep -qiE 'classification|分類' "$SKILL_FILE"
  grep -qiE 'failure rate|失敗率' "$SKILL_FILE"
}

@test "AT-322-6: ATDD (determinization fix) never starts before cause-agreement gate" {
  grep -qiE 'never start|before the cause-agreement|通過後' "$SKILL_FILE"
}

@test "AT-322-6: gate count stays three (specialization, not removal/addition)" {
  grep -qiE 'gate count stays three|stays three|三のまま' "$SKILL_FILE"
}

# --- AT-322-7: quarantine judgment -----------------------------------------

@test "AT-322-7: quarantine judgment point exists with platform-aware isolation markers" {
  grep -qiE 'quarantine|隔離' "$SKILL_FILE"
  grep -qiE 'skip|fixme|XCTSkip' "$SKILL_FILE"
}

@test "AT-322-7: tracking after isolation is mandatory (Issue tracking / re-dispatch)" {
  grep -qiE 'track|re-dispatch' "$SKILL_FILE"
}

@test "AT-322-7: isolation is via external runner features only (no atdd-kit local impl)" {
  grep -qiE 'external runner|external.*feature' "$SKILL_FILE"
}

# --- AT-322-8: Type A promotion to the full route -------------------------

@test "AT-322-8: Type A (AC Gap) promotes to the full feature route via defining-requirements" {
  grep -qiE 'Type A' "$SKILL_FILE"
  grep -qiE 'promot|昇格' "$SKILL_FILE"
  grep -q 'defining-requirements' "$SKILL_FILE"
}

# --- AT-322-9 / AT-322-10: merge User gate --------------------------------

@test "AT-322-9: merge goes via merging-and-deploying and always requires the User gate (AL-1)" {
  grep -q 'merging-and-deploying' "$SKILL_FILE"
  grep -qiE 'User (merge )?gate' "$SKILL_FILE"
  grep -qiE 'AL-1' "$SKILL_FILE"
  grep -qiE 'never auto-merge|auto-merge|自動マージ' "$SKILL_FILE"
}

# --- AT-322-12: reuse-only contract (CS-2) --------------------------------

@test "AT-322-12: documents binding existing skills (reuse / zero duplication), not new methodology" {
  grep -qiE 'reuse|re-use|only bind' "$SKILL_FILE"
  grep -qiE 'duplication|no new methodology|adds no new methodology|zero duplication' "$SKILL_FILE"
}

@test "AT-322-12: fixing-bugs sibling route SKILL.md is unedited" {
  run git diff --quiet "$FIXING_BUGS_FILE"
  [ "$status" -eq 0 ]
}
