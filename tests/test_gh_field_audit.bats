#!/usr/bin/env bats
# @covers: docs/**
# tests/test_gh_field_audit.bats
# AC1: gh --json fields are minimized to only what is actually used downstream

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SESSION_START="$REPO_ROOT/skills/session-start/SKILL.md"
AUTOPILOT="$REPO_ROOT/commands/autopilot.md"

# --- session-start/SKILL.md ---

@test "AC1: session-start gh pr view does not request mergeStateStatus (unused field)" {
  run grep "mergeStateStatus" "$SESSION_START"
  # mergeStateStatus should NOT appear anywhere
  [ "$status" -ne 0 ]
}

@test "AC1: session-start gh pr view call exists" {
  run grep "gh pr view" "$SESSION_START"
  [ "$status" -eq 0 ]
}

@test "AC1: session-start gh pr view fetches reviewDecision (used in PR status report)" {
  run grep "reviewDecision" "$SESSION_START"
  [ "$status" -eq 0 ]
}

@test "AC1: session-start gh pr view fetches statusCheckRollup (used in CI status)" {
  run grep "statusCheckRollup" "$SESSION_START"
  [ "$status" -eq 0 ]
}

@test "AC1: session-start gh pr view fetches mergeable (used in conflict detection)" {
  run grep "mergeable" "$SESSION_START"
  [ "$status" -eq 0 ]
}

# --- commands/autopilot.md ---

@test "AC1: autopilot Phase 5 combines statusCheckRollup and mergeable into one gh pr view call" {
  # Should have a single line with both fields
  run python3 -c "
import re
with open('$AUTOPILOT') as f:
    content = f.read()
pattern = r'gh pr view[^\n]*--json[^\n]*statusCheckRollup[^\n]*mergeable|gh pr view[^\n]*--json[^\n]*mergeable[^\n]*statusCheckRollup'
matches = re.findall(pattern, content)
assert len(matches) >= 1, f'Expected combined call, found none. Matches: {matches}'
print(f'OK: {len(matches)} combined call(s) found')
"
  [ "$status" -eq 0 ]
}

@test "AC1: autopilot does not have separate standalone --json statusCheckRollup call (must be merged)" {
  # No line should have '--json statusCheckRollup' without 'mergeable' in the same line
  run python3 -c "
with open('$AUTOPILOT') as f:
    lines = f.readlines()
violations = []
for i, line in enumerate(lines, 1):
    if '--json statusCheckRollup' in line and 'mergeable' not in line:
        violations.append(f'Line {i}: {line.rstrip()}')
    elif '--json' in line and 'statusCheckRollup' in line and 'mergeable' not in line:
        violations.append(f'Line {i}: {line.rstrip()}')
if violations:
    print('FAIL: standalone statusCheckRollup calls found:')
    for v in violations: print(v)
    import sys; sys.exit(1)
print('OK')
"
  [ "$status" -eq 0 ]
}

@test "AC1: autopilot does not have separate standalone --json mergeable call (must be merged)" {
  # No line should have '--json mergeable' without 'statusCheckRollup' in the same line
  run python3 -c "
with open('$AUTOPILOT') as f:
    lines = f.readlines()
violations = []
for i, line in enumerate(lines, 1):
    if '--json mergeable' in line and 'statusCheckRollup' not in line:
        violations.append(f'Line {i}: {line.rstrip()}')
if violations:
    print('FAIL: standalone mergeable calls found:')
    for v in violations: print(v)
    import sys; sys.exit(1)
print('OK')
"
  [ "$status" -eq 0 ]
}

@test "AC1: autopilot Phase 5 still has separate gh pr view --json comments call (must be preserved)" {
  # Step 1 of Phase 5 fetches comments separately (by design)
  run grep "gh pr view.*--json comments" "$AUTOPILOT"
  [ "$status" -eq 0 ]
}

@test "AC1: autopilot Phase 5 combined call includes statusCheckRollup" {
  run grep "statusCheckRollup" "$AUTOPILOT"
  [ "$status" -eq 0 ]
}

@test "AC1: autopilot Phase 5 combined call includes mergeable" {
  run grep "statusCheckRollup,mergeable" "$AUTOPILOT"
  [ "$status" -eq 0 ]
}
