#!/usr/bin/env bats
# @covers: commands/autopilot.md
# Issue #104: research task Phase 5 deliverable → action conversion

AUTOPILOT="commands/autopilot.md"

# --- AC5: dev/bug/doc/refactor Phase 5 non-destructive regression ---

@test "AC5: Phase 5 has development/bug/documentation/refactoring H3" {
  grep -q '### development / bug / documentation / refactoring' "$AUTOPILOT"
}

@test "AC5: Phase 5 has research H3" {
  grep -q '### research' "$AUTOPILOT"
}

@test "AC5: dev H3 contains Step 1 verify review PASS" {
  # Extract dev H3 section and check for Step 1
  awk '/### development \/ bug \/ documentation \/ refactoring/,/### research/' "$AUTOPILOT" | grep -q 'Verify review PASS'
}

@test "AC5: dev H3 contains gh pr merge squash" {
  awk '/### development \/ bug \/ documentation \/ refactoring/,/### research/' "$AUTOPILOT" | grep -q 'gh pr merge.*--squash'
}

@test "AC5: dev H3 contains Remove in-progress label" {
  awk '/### development \/ bug \/ documentation \/ refactoring/,/### research/' "$AUTOPILOT" | grep -q 'Remove.*in-progress.*label\|in-progress.*label'
}

@test "AC5: dev H3 contains git switch worktree step" {
  awk '/### development \/ bug \/ documentation \/ refactoring/,/### research/' "$AUTOPILOT" | grep -q 'git switch worktree-autopilot'
}

@test "AC5: dev H3 contains ExitWorktree" {
  awk '/### development \/ bug \/ documentation \/ refactoring/,/### research/' "$AUTOPILOT" | grep -q 'ExitWorktree'
}

@test "AC5: dev H3 contains TeamDelete" {
  awk '/### development \/ bug \/ documentation \/ refactoring/,/### research/' "$AUTOPILOT" | grep -q 'TeamDelete'
}

@test "AC5: dev H3 contains git checkout main" {
  awk '/### development \/ bug \/ documentation \/ refactoring/,/### research/' "$AUTOPILOT" | grep -q 'git checkout main'
}

# --- AC3: no_action case —-- research H3 closes issue with reason ---

@test "AC3: research H3 mentions no_action classification" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'no_action'
}

@test "AC3: research H3 closes source issue" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'gh issue close'
}

@test "AC3: research H3 does NOT mention gh pr merge" {
  count=$(awk '/### research/,/^## /' "$AUTOPILOT" | grep -c 'gh pr merge' || true)
  [ "$count" -eq 0 ]
}

# --- AC4: closing comment section omission ---

@test "AC4: research H3 has closing comment step" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'Closing Comment\|closing comment\|クロージングコメント'
}

@test "AC4: research H3 specifies 0-item section omission" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -qi 'omit.*section.*0\|0.*section.*omit\|section.*0.*omit\|0.*省略\|省略\|omit any section'
}

# --- AC6: zero findings ---

@test "AC6: research H3 handles zero findings" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -qi '発見.*0\|0.*発見\|発見なし\|zero.*find\|no.*find\|findings.*0'
}

# --- AC1: new_issue classification and creation ---

@test "AC1: research H3 mentions new_issue classification" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'new_issue'
}

@test "AC1: research H3 contains gh issue create command" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'gh issue create'
}

@test "AC1: research H3 links source issue in new issue body" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'source.*#\|link.*source\|source #'
}

# --- AC7: mixed classification ---

@test "AC7: research H3 has all three classification types" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'new_issue'
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'existing_comment'
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'no_action'
}

@test "AC7: research H3 processes in order new_issue then existing_comment" {
  section=$(awk '/### research/,/^## /' "$AUTOPILOT")
  new_line=$(echo "$section" | grep -n 'new_issue' | head -1 | cut -d: -f1)
  comment_line=$(echo "$section" | grep -n 'existing_comment' | head -1 | cut -d: -f1)
  [ -n "$new_line" ] && [ -n "$comment_line" ] && [ "$new_line" -lt "$comment_line" ]
}

# --- AC8: best-effort partial failure ---

@test "AC8: research H3 mentions best-effort on partial failure" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -qi 'best.effort\|部分失敗\|partial.*fail'
}

@test "AC8: research H3 BLOCKED only on all-fail" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -qi '全件失敗\|all.*fail\|all.*BLOCKED\|全件.*BLOCKED'
}

# --- AC9: idempotency guard ---

@test "AC9: research H3 has idempotency guard for closed issue" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -qi 'idempotency\|Idempotency\|冪等\|already closed\|CLOSED'
}

@test "AC9: research H3 returns BLOCKED on closed issue" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -qi 'BLOCKED'
}

# --- AC2: existing_comment case ---

@test "AC2: research H3 mentions existing_comment classification" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'existing_comment'
}

@test "AC2: research H3 contains gh issue comment command" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -q 'gh issue comment'
}

# --- research H3 meta: PR review/merge explicitly excluded ---

@test "research H3 states PR verify does not apply" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -qi 'do not apply\|not apply\|skip.*PR\|PR.*skip\|非適用'
}

@test "research H3 states ready-for-PR-review must NOT be added" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -qi 'Do NOT add.*ready-for-PR-review\|ready-for-PR-review.*not\|NOT.*ready-for-PR-review'
}

# --- Classification heuristic ---

@test "research H3 has classification heuristic with when-in-doubt rule" {
  awk '/### research/,/^## /' "$AUTOPILOT" | grep -qi 'when in doubt\|prefer.*existing_comment\|existing_comment.*sprawl'
}

# --- Steps 7-10 shared with dev H3 ---

@test "research H3 Steps 7-10 match dev H3 post-processing" {
  research=$(awk '/### research/,/^## /' "$AUTOPILOT")
  echo "$research" | grep -q 'git switch worktree-autopilot'
  echo "$research" | grep -q 'ExitWorktree'
  echo "$research" | grep -q 'TeamDelete'
  echo "$research" | grep -q 'git checkout main'
}
