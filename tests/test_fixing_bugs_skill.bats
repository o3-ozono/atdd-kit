#!/usr/bin/env bats
# @covers: skills/fixing-bugs/SKILL.md
# Unit Test for the fixing-bugs skill (bugfix lightweight route, #308).
# claude is NOT invoked; structural / wording invariants are checked via grep.
#
# Scope (#308): fixing-bugs is a thin ORCHESTRATION skill for the bugfix category.
# It reuses existing skills only (no new methodology), chains 5 skills, skips the
# 3 definition skills, overrides bug's hard-coded forward chain WITHOUT editing bug,
# wires platform-aware reproduction → failing test, specializes the middle gate to
# cause-agreement, promotes Type A to the full route, and keeps the merge User gate.

SKILL_FILE="skills/fixing-bugs/SKILL.md"
BUG_FILE="skills/bug/SKILL.md"

# --- Identity -------------------------------------------------------------

@test "identity: name field matches directory (fixing-bugs)" {
  local name
  name=$(grep '^name:' "$SKILL_FILE" | sed 's/^name:[[:space:]]*//')
  [ "$name" = "fixing-bugs" ]
}

@test "description: trigger conditions only, no workflow summary (DEVELOPMENT.md Skill Description Field Rules)" {
  local desc
  desc=$(grep '^description:' "$SKILL_FILE")
  # トリガー条件を述べる ("Use when ...")
  echo "$desc" | grep -qiE 'use when|trigger|explicit'
  # ワークフロー要約の典型パターン "creates X, then Y, then Z" を含まない
  ! echo "$desc" | grep -qiE 'creates .*then .*then'
}

# --- AT-308-1: skip 3 / chain 5 -------------------------------------------

@test "AT-308-1: chains the 5 bugfix skills in order" {
  grep -q 'bug' "$SKILL_FILE"
  grep -q 'debugging' "$SKILL_FILE"
  grep -q 'running-atdd-cycle' "$SKILL_FILE"
  grep -q 'reviewing-deliverables' "$SKILL_FILE"
  grep -q 'merging-and-deploying' "$SKILL_FILE"
}

@test "AT-308-1: skips the 3 full-route definition skills in a 'skip' context" {
  # スキップ文脈に 3 スキル名が揃って出現する
  grep -qiE 'skip' "$SKILL_FILE"
  grep -q 'defining-requirements' "$SKILL_FILE"
  grep -q 'extracting-user-stories' "$SKILL_FILE"
  grep -q 'writing-plan-and-tests' "$SKILL_FILE"
}

# --- AT-308-1b: forward-chain override WITHOUT editing bug -----------------

@test "AT-308-1b: documents orchestrator-driven invocation override" {
  grep -qiE 'orchestrator-driven' "$SKILL_FILE"
}

@test "AT-308-1b: chained skills' Next Step is advisory and overridden under this route" {
  grep -qiE 'advisory' "$SKILL_FILE"
  grep -qiE 'override' "$SKILL_FILE"
  grep -qiE 'Next Step' "$SKILL_FILE"
}

@test "AT-308-1b: after bug, invoke debugging (not bug's defining-requirements Next Step)" {
  # bug 完了後 defining-requirements を辿らず debugging を呼ぶ旨
  grep -qiE 'after .*bug.*debugging|bug.*completes.*debugging' "$SKILL_FILE"
}

@test "AT-308-1b: bug SKILL.md is unedited (no essential rewrite of reused skills)" {
  # bug の forward chain は本ルートで override されるが bug 自体は未編集である
  run git diff --quiet "$BUG_FILE"
  [ "$status" -eq 0 ]
}

# --- AT-308-3: platform-aware reproduction, external refs only ------------

@test "AT-308-3: reproduction step branches per platform (web / iOS / other)" {
  grep -qiE 'platform' "$SKILL_FILE"
  grep -q 'playwright-cli' "$SKILL_FILE"
  grep -q 'verify' "$SKILL_FILE"
  grep -qiE 'Xcode|simulator' "$SKILL_FILE"
  grep -q 'sim-pool' "$SKILL_FILE"
  grep -qiE 'CLI|script|bats' "$SKILL_FILE"
}

@test "AT-308-3: playwright-cli / verify / Xcode MCP are external references, not atdd-kit-owned" {
  grep -qiE 'external skill|external (tool|MCP)|external reference' "$SKILL_FILE"
}

# --- AT-308-4: reproduction encoded as failing test (赤→緑 oracle anchor) --

@test "AT-308-4: confirmed reproduction encoded as failing test, red->green oracle anchor" {
  grep -qiE 'failing test|failing reproduction' "$SKILL_FILE"
  grep -qiE '赤.?→.?緑|red.?→.?green|赤→緑' "$SKILL_FILE"
  grep -qiE 'anchor' "$SKILL_FILE"
}

# --- AT-308-7b: cause-agreement middle gate before ATDD -------------------

@test "AT-308-7b: middle gate specialized to cause-agreement before the fix starts" {
  grep -qiE 'cause-agreement' "$SKILL_FILE"
  # ATDD/最小修正は cause-agreement ゲート通過後にのみ開始する
  grep -qiE 'never start|after the cause-agreement|通過後' "$SKILL_FILE"
}

# --- AT-308-8: Type A promotion to the full route -------------------------

@test "AT-308-8: Type A (AC Gap) promotes to the full feature route via defining-requirements" {
  grep -qiE 'Type A' "$SKILL_FILE"
  grep -qiE 'promot|昇格' "$SKILL_FILE"
  grep -q 'defining-requirements' "$SKILL_FILE"
}

# --- AT-308-9: merge always passes the User gate ---------------------------

@test "AT-308-9: merge goes via merging-and-deploying and always requires the User gate (AL-1)" {
  grep -q 'merging-and-deploying' "$SKILL_FILE"
  grep -qiE 'User (merge )?gate' "$SKILL_FILE"
  grep -qiE 'AL-1' "$SKILL_FILE"
  # 自動マージしない
  grep -qiE 'never auto-merge|auto-merge|自動マージ' "$SKILL_FILE"
}

# --- Reuse-only contract (US-Constraint1): no new methodology --------------

@test "reuse-only: documents binding existing skills (reuse / zero duplication), not new methodology" {
  grep -qiE 'reuse|re-use|only bind' "$SKILL_FILE"
  grep -qiE 'duplication|no new methodology|adds no new methodology' "$SKILL_FILE"
}
