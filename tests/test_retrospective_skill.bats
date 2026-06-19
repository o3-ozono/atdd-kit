#!/usr/bin/env bats
# @covers: skills/merging-and-deploying/SKILL.md
# @covers: skills/express/SKILL.md
# Unit tests for the retrospective invocation structure in merging-and-deploying SKILL.md (#309).
#
# Per docs/testing-skills.md, this is a Unit Test -- `claude` is not invoked;
# structural / wording-level invariants are checked via grep.
#
# Scope: assert the retrospective calling point, express structural-skip rationale,
# and all-channel sync are correctly wired in the SKILL.md files.

bats_require_minimum_version 1.5.0

SKILL_MERGE="skills/merging-and-deploying/SKILL.md"
SKILL_EXPRESS="skills/express/SKILL.md"

# --- Retrospective calling point -------------------------------------------

@test "#309 retrospective: merging-and-deploying SKILL.md has retrospective invocation" {
  grep -qiE 'retrospective' "$SKILL_MERGE"
}

@test "#309 retrospective: retrospective.sh is named as the invocation command" {
  grep -q 'retrospective.sh' "$SKILL_MERGE"
}

@test "#309 retrospective: retrospective.sh invocation includes --issue and --pr arguments" {
  grep -qE 'retrospective\.sh.*--issue|--issue.*--pr' "$SKILL_MERGE"
}

# --- Express structural skip -----------------------------------------------

@test "#309 express skip: merging-and-deploying SKILL.md documents express structural-skip rationale" {
  grep -qiE 'express.*skip|express.*structural|express.*not.*retrospective' "$SKILL_MERGE"
}

@test "#309 express skip: express SKILL.md has 0 retrospective invocations (structural skip)" {
  # express does not call merging-and-deploying; retrospective is not reachable via express
  if grep -q 'retrospective' "$SKILL_EXPRESS" 2>/dev/null; then
    echo "FAIL: ${SKILL_EXPRESS} references retrospective (express must not invoke retrospective)"
    return 1
  fi
}

# --- All-channel sync -------------------------------------------------------

@test "#309 all-channel sync: merging-and-deploying SKILL.md documents terminal + Issue/PR comment sync" {
  grep -qiE '(terminal|ターミナル).*(comment|コメント)|(comment|コメント).*(terminal|ターミナル)|both.channel|all.channel|全チャネル|両チャネル' "$SKILL_MERGE"
}

# --- Flow step count invariant (must still be 5 after retrospective addition) ---

@test "#309 flow steps: merging-and-deploying SKILL.md Flow section still has 5 numbered steps" {
  local steps
  steps=$(sed -n '/^## Flow/,/^## Responsibility Boundary/p' "$SKILL_MERGE" | grep -cE '^[0-9]+\. ')
  [ "$steps" -eq 5 ]
}

# --- Line budget -----------------------------------------------------------

@test "#309 line budget: merging-and-deploying SKILL.md is at most 200 lines" {
  local n
  n=$(wc -l < "$SKILL_MERGE" | tr -d ' ')
  [ "$n" -le 200 ]
}
