#!/usr/bin/env bash
# test-helpers.sh -- Fast-test harness for skill content comprehension tests
#
# Fast convention: single-turn claude -p call, no fixture, no skill chain.
# LLM non-determinism: limit to deterministic questions (Yes/No, name references,
# counts). assert_contains accepts regex for flexibility.
#
# Usage: source this file in your test script or BATS test file.
#
# Env overrides:
#   SKILL_TEST_CLAUDE_BIN  -- override claude binary path (default: PATH lookup)

set -u
set -o pipefail

SKILL_TEST_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_TEST_REPO_ROOT="$(cd "${SKILL_TEST_HELPERS_DIR}/../.." && pwd)"

# Resolve claude binary: env override > PATH
_claude_bin() {
  if [ -n "${SKILL_TEST_CLAUDE_BIN:-}" ]; then
    echo "$SKILL_TEST_CLAUDE_BIN"
  elif command -v claude > /dev/null 2>&1; then
    echo "claude"
  else
    echo ""
  fi
}

# run_claude <prompt>
# Runs claude -p with the given prompt, captures output into $OUTPUT.
# Uses SKILL_TEST_CLAUDE_BIN if set.
run_claude() {
  local prompt="$1"
  local bin
  bin=$(_claude_bin)
  if [ -z "$bin" ]; then
    echo "Error: claude binary not found; set SKILL_TEST_CLAUDE_BIN or install claude" >&2
    return 3
  fi
  OUTPUT=$("$bin" -p "$prompt" 2>/dev/null)
}

# assert_contains <pattern>
# Asserts that $OUTPUT contains the given literal string or regex pattern.
# Exits 0 on match, 1 on mismatch (with diagnostic output).
assert_contains() {
  local pattern="$1"
  if echo "$OUTPUT" | grep -qE "$pattern"; then
    return 0
  else
    echo "Expected pattern not found in output:" >&2
    echo "  Pattern: $pattern" >&2
    echo "  Output:  $OUTPUT" >&2
    return 1
  fi
}

# assert_order <substring1> [substring2 ...]
# Asserts that substrings appear in $OUTPUT in the given order.
# Exits 0 if all substrings found in order, 1 otherwise.
assert_order() {
  local remaining="$OUTPUT"
  local prev=""
  for pattern in "$@"; do
    local after
    after=$(echo "$remaining" | grep -oE "${pattern}.*" | head -1)
    if [ -z "$after" ]; then
      echo "assert_order: '$pattern' not found after '$prev' in output" >&2
      echo "  Output: $OUTPUT" >&2
      return 1
    fi
    # Advance remaining to after the first match
    local match_pos
    match_pos=$(echo "$remaining" | grep -bE "$pattern" | head -1 | cut -d: -f1)
    if [ -n "$match_pos" ]; then
      local match_len=${#pattern}
      remaining="${remaining:$(( match_pos + match_len ))}"
    fi
    prev="$pattern"
  done
  return 0
}

# assert_count <pattern> <n>
# Asserts that pattern appears exactly n times in $OUTPUT.
# Exits 0 on match, 1 otherwise.
assert_count() {
  local pattern="$1"
  local expected="$2"
  local actual
  actual=$(echo "$OUTPUT" | grep -oE "$pattern" | wc -l | tr -d ' ')
  if [ "$actual" -eq "$expected" ]; then
    return 0
  else
    echo "assert_count: expected $expected occurrences of '$pattern', got $actual" >&2
    echo "  Output: $OUTPUT" >&2
    return 1
  fi
}

# create_test_project [dir]
# Creates a minimal fixture project dir with README.md and .claude/CLAUDE.md.
# Prints the project dir path to stdout.
# Caller is responsible for cleanup (rm -rf).
create_test_project() {
  local base_dir="${1:-}"
  local project_dir
  if [ -n "$base_dir" ]; then
    project_dir="$base_dir"
    mkdir -p "$project_dir"
  else
    project_dir=$(mktemp -d)
  fi
  mkdir -p "${project_dir}/.claude"
  echo "# Test Project" > "${project_dir}/README.md"
  touch "${project_dir}/.claude/CLAUDE.md"
  echo "$project_dir"
}
