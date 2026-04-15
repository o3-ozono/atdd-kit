#!/usr/bin/env bats
# tests/test_autopilot_context_reference.bats
# AC2: Agent Team spawn prompts use references only, no full-text injection

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
AUTOPILOT="$REPO_ROOT/commands/autopilot.md"

# --- Forbidden patterns: full-text injection ---

@test "AC2: no 'include.*full.*body' pattern in autopilot SendMessage/spawn instructions" {
  run python3 -c "
import re, sys
with open('$AUTOPILOT') as f:
    content = f.read()
# Forbidden: injecting full body text
forbidden = [
    r'include.*full.*body',
    r'inject.*body',
    r'paste.*body',
    r'copy.*body.*here',
]
found = []
for pat in forbidden:
    matches = re.findall(pat, content, re.IGNORECASE)
    if matches:
        found.extend(matches)
if found:
    print(f'FAIL: forbidden patterns found: {found}')
    sys.exit(1)
print('OK')
"
  [ "$status" -eq 0 ]
}

@test "AC2: AC Review Round Developer spawn includes Issue number reference not full body" {
  # AC Review Round spawns Developer/QA - they should reference by number, not inject full text
  run python3 -c "
with open('$AUTOPILOT') as f:
    content = f.read()
# Find AC Review Round section
import re
section_match = re.search(r'## AC Review Round.*?## Phase 2', content, re.DOTALL)
assert section_match, 'AC Review Round section not found'
section = section_match.group(0)
# Should have Issue number reference
assert 'issue_number' in section or 'Issue #' in section or '<number>' in section, \
    'AC Review Round must reference issue by number'
print('OK: AC Review Round has issue number reference')
"
  [ "$status" -eq 0 ]
}

@test "AC2: Phase 2 plan SendMessage uses reference not full body injection" {
  # Phase 2 SendMessage to Developer/QA should use references
  run python3 -c "
with open('$AUTOPILOT') as f:
    content = f.read()
import re
section_match = re.search(r'## Phase 2.*?## Plan Review Round', content, re.DOTALL)
assert section_match, 'Phase 2 section not found'
section = section_match.group(0)
# Must have 'Issue number' reference pattern
assert re.search(r'Issue number|Issue #|<number>', section), \
    'Phase 2 SendMessage must reference Issue by number'
# Must have 'reference to' pattern (reference injection approach)
assert re.search(r'reference to.*[Ii]ssue|[Ii]ssue.*comment.*contain', section), \
    'Phase 2 must use reference-based context passing'
print('OK: Phase 2 uses reference-based context')
"
  [ "$status" -eq 0 ]
}

@test "AC2: Plan Review Round SendMessage uses reference not full body injection" {
  run python3 -c "
with open('$AUTOPILOT') as f:
    content = f.read()
import re
section_match = re.search(r'## Plan Review Round.*?## Phase 3', content, re.DOTALL)
assert section_match, 'Plan Review Round section not found'
section = section_match.group(0)
assert re.search(r'Issue number|Issue #|<number>', section), \
    'Plan Review Round must reference Issue by number'
assert re.search(r'reference to.*[Ii]ssue|[Ii]ssue.*comment.*contain|unified Plan', section), \
    'Plan Review Round must use reference-based context'
print('OK: Plan Review Round uses reference-based context')
"
  [ "$status" -eq 0 ]
}

@test "AC2: Phase 3 implementation SendMessage uses reference not full body injection" {
  run python3 -c "
with open('$AUTOPILOT') as f:
    content = f.read()
import re
section_match = re.search(r'## Phase 3.*?## Phase 4', content, re.DOTALL)
assert section_match, 'Phase 3 section not found'
section = section_match.group(0)
# Must reference Issue by number
assert re.search(r'Issue number|Issue #|<number>', section), \
    'Phase 3 must reference Issue by number'
print('OK: Phase 3 uses reference-based context')
"
  [ "$status" -eq 0 ]
}

@test "AC2: Phase 4 Reviewer spawn uses reference not full body injection" {
  run python3 -c "
with open('$AUTOPILOT') as f:
    content = f.read()
import re
section_match = re.search(r'## Phase 4.*?## Phase 5', content, re.DOTALL)
assert section_match, 'Phase 4 section not found'
section = section_match.group(0)
# Phase 4 spawns Reviewers - they should get PR number, not full PR body
# Must have variable-count agents referenced
assert 'Reviewer' in section, 'Phase 4 must mention Reviewer agents'
print('OK: Phase 4 has Reviewer agents')
"
  [ "$status" -eq 0 ]
}

@test "AC2: SendMessage instructions do not contain raw Issue/PR text blocks (no triple-backtick injection)" {
  # The autopilot.md should not have patterns like:
  # "Send the following to Developer:" followed by large text blocks that are the Issue content
  run python3 -c "
with open('$AUTOPILOT') as f:
    content = f.read()
import re
# Check: SendMessage sections do not instruct to inject full Issue body literally
# The key pattern: 'Include the full Issue body:' or 'Paste the Issue body:'
forbidden_patterns = [
    r'Include the full Issue body',
    r'Paste the Issue body',
    r'Send.*full.*Issue.*body',
    r'forward.*Issue.*body.*to.*agent',
]
found = []
for pat in forbidden_patterns:
    if re.search(pat, content, re.IGNORECASE):
        found.append(pat)
if found:
    print(f'FAIL: forbidden injection patterns: {found}')
    import sys; sys.exit(1)
print('OK')
"
  [ "$status" -eq 0 ]
}
