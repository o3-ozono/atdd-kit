#!/usr/bin/env bats
# @covers: hooks/**
# tests/test_hook_distribution.bats
# AC6: Bash PostToolUse hook is distributed via atdd-kit plugin standard mechanism

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOKS_JSON="$REPO_ROOT/hooks/hooks.json"
GLOBAL_SETTINGS="$HOME/.claude/settings.json"

@test "AC6: hooks.json has PostToolUse section" {
  run python3 -c "
import json, sys
with open('$HOOKS_JSON') as f:
    d = json.load(f)
assert 'PostToolUse' in d['hooks'], 'PostToolUse key missing from hooks.json'
print('OK')
"
  [ "$status" -eq 0 ]
}

@test "AC6: PostToolUse matcher is limited to Bash only" {
  run python3 -c "
import json, sys
with open('$HOOKS_JSON') as f:
    d = json.load(f)
post_hooks = d['hooks']['PostToolUse']
for entry in post_hooks:
    matcher = entry.get('matcher', '')
    assert 'Bash' in matcher, f'matcher must contain Bash, got: {matcher}'
    assert 'Read' not in matcher, f'matcher must not contain Read'
    assert 'Write' not in matcher, f'matcher must not contain Write'
    assert 'Edit' not in matcher, f'matcher must not contain Edit'
print('OK')
"
  [ "$status" -eq 0 ]
}

@test "AC6: PostToolUse hook references bash-output-normalizer.sh" {
  run python3 -c "
import json, sys
with open('$HOOKS_JSON') as f:
    d = json.load(f)
post_hooks = d['hooks']['PostToolUse']
found = False
for entry in post_hooks:
    for h in entry.get('hooks', []):
        cmd = h.get('command', '')
        if 'bash-output-normalizer' in cmd:
            found = True
            break
assert found, 'No hook referencing bash-output-normalizer.sh found in PostToolUse'
print('OK')
"
  [ "$status" -eq 0 ]
}

@test "AC6: PostToolUse hook has timeout of 10 seconds" {
  run python3 -c "
import json, sys
with open('$HOOKS_JSON') as f:
    d = json.load(f)
post_hooks = d['hooks']['PostToolUse']
for entry in post_hooks:
    for h in entry.get('hooks', []):
        if 'bash-output-normalizer' in h.get('command', ''):
            timeout = h.get('timeout')
            assert timeout is not None, 'timeout must be set'
            assert int(timeout) == 10, f'timeout must be 10, got {timeout}'
print('OK')
"
  [ "$status" -eq 0 ]
}

@test "AC6: existing PreToolUse hooks are preserved" {
  run python3 -c "
import json, sys
with open('$HOOKS_JSON') as f:
    d = json.load(f)
pre_hooks = d['hooks'].get('PreToolUse', [])
assert len(pre_hooks) > 0, 'PreToolUse hooks must still exist'
found = False
for entry in pre_hooks:
    for h in entry.get('hooks', []):
        if 'main-branch-guard' in h.get('command', ''):
            found = True
assert found, 'main-branch-guard.sh must still be in PreToolUse'
print('OK')
"
  [ "$status" -eq 0 ]
}

@test "AC6: chezmoi-managed global settings.json does not contain bash-output-normalizer PostToolUse" {
  if [ ! -f "$GLOBAL_SETTINGS" ]; then
    skip "Global settings.json not found"
  fi
  run python3 -c "
import json, sys
with open('$GLOBAL_SETTINGS') as f:
    d = json.load(f)
hooks = d.get('hooks', {})
post_hooks = hooks.get('PostToolUse', [])
for entry in post_hooks:
    for h in entry.get('hooks', []):
        cmd = h.get('command', '')
        if 'bash-output-normalizer' in cmd:
            print('FAIL: bash-output-normalizer found in global settings.json')
            sys.exit(1)
print('OK')
"
  [ "$status" -eq 0 ]
}
