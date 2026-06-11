#!/usr/bin/env bats
# @covers: tests/e2e/*.bats, tests/test_skill_test_coverage.bats, tests/README.md
# Issue #278: Skill E2E tests specify --model sonnet for claude invocations
#
# AT lifecycle: draft -> green -> regression
# Current state: [regression]
#
# Machine-verifiable ATs: AT-001 / AT-002 / AT-004 / AT-005 / AT-006 / AT-008
# AT-003 (regression pin FAIL check) and AT-007 (CHANGELOG + version bump)
# are verified by their respective test files.

E2E_DIR="tests/e2e"
E2E_GLOB="${E2E_DIR}/*.bats"
EXPECTED_FILE_COUNT=11

# --- AT-001: All E2E files' claude invocations explicitly specify a model (US-1) ---
#
# Given: tests/e2e/*.bats all 11 files
# When:  Inspect the _run_claude function's claude -p invocation lines in each file
# Then:  All 11 files pass --model "${E2E_MODEL}" to claude -p; no unspecified invocations exist

@test "#278 AT-001: all E2E files contain --model \"\${E2E_MODEL}\"" {
  local count
  count=$(grep -rl -e '--model "\${E2E_MODEL}"' ${E2E_GLOB} 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -ne "$EXPECTED_FILE_COUNT" ]; then
    echo "Expected: ${EXPECTED_FILE_COUNT} files, got: ${count} files"
    echo "Missing files:"
    for f in ${E2E_GLOB}; do
      grep -q -e '--model "\${E2E_MODEL}"' "$f" || echo "  $f"
    done
    return 1
  fi
}

@test "#278 AT-001: no unspecified claude -p invocation exists (all branches have --model)" {
  local failed=()
  for f in ${E2E_GLOB}; do
    local launch_count model_count
    # CLAUDE_BIN の -p 起動行数（grep -c は 0 件でも "0" を stdout に出力して exit 1）
    launch_count=$(grep -c 'CLAUDE_BIN.*-p' "$f" 2>/dev/null; true)
    model_count=$(grep -c 'model.*E2E_MODEL' "$f" 2>/dev/null; true)
    launch_count=$(echo "$launch_count" | tail -1 | tr -d ' ')
    model_count=$(echo "$model_count" | tail -1 | tr -d ' ')
    if [ "$launch_count" -ne "$model_count" ]; then
      failed+=("$f (launch: ${launch_count}, --model: ${model_count})")
    fi
  done
  if [ "${#failed[@]}" -gt 0 ]; then
    echo "Files where launch count != --model count:"
    printf '  %s\n' "${failed[@]}"
    return 1
  fi
}

# --- AT-002: Model can be overridden via env var; default is sonnet (US-2) ---
#
# Given: Config section at top of each e2e file
# When:  Inspect model variable definition
# Then:  All 11 files define E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"

@test "#278 AT-002: all E2E files define E2E_MODEL=\"\${SKILL_E2E_MODEL:-sonnet}\"" {
  local count
  count=$(grep -rl 'E2E_MODEL="\${SKILL_E2E_MODEL:-sonnet}"' ${E2E_GLOB} 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -ne "$EXPECTED_FILE_COUNT" ]; then
    echo "Expected: ${EXPECTED_FILE_COUNT} files, got: ${count} files"
    echo "Missing files:"
    for f in ${E2E_GLOB}; do
      grep -q 'E2E_MODEL="\${SKILL_E2E_MODEL:-sonnet}"' "$f" || echo "  $f"
    done
    return 1
  fi
}

# --- AT-004: Model policy is documented in README (US-4) ---
#
# Given: tests/README.md "## Skill E2E Tests (tests/e2e/)" section
# When:  Inspect model policy description
# Then:  Default model sonnet and SKILL_E2E_MODEL override method are readable from that section

@test "#278 AT-004: tests/README.md mentions SKILL_E2E_MODEL" {
  grep -q 'SKILL_E2E_MODEL' tests/README.md
}

@test "#278 AT-004: tests/README.md model policy includes sonnet as default" {
  grep -q 'sonnet' tests/README.md
}

# --- AT-005: Model specification is consistent across all timeout branches (CS-1) ---
#
# Given: _run_claude in each e2e file (3-branch structure)
# When:  Inspect --model occurrence per branch
# Then:  All 11 files have exactly 3 occurrences of --model "${E2E_MODEL}" (= claude -p count)

@test "#278 AT-005: all E2E files have --model specified in all 3 branches" {
  local failed=()
  for f in ${E2E_GLOB}; do
    local launch_count model_count
    launch_count=$(grep -c 'CLAUDE_BIN.*-p' "$f" 2>/dev/null; true)
    model_count=$(grep -c 'model.*E2E_MODEL' "$f" 2>/dev/null; true)
    launch_count=$(echo "$launch_count" | tail -1 | tr -d ' ')
    model_count=$(echo "$model_count" | tail -1 | tr -d ' ')
    # 3 分岐の起動行数と --model 数が一致すること（= 3）
    if [ "$model_count" -ne "$launch_count" ] || [ "$model_count" -ne 3 ]; then
      failed+=("$f (--model count: ${model_count}, launch count: ${launch_count})")
    fi
  done
  if [ "${#failed[@]}" -gt 0 ]; then
    echo "Files missing --model in all 3 branches:"
    printf '  %s\n' "${failed[@]}"
    return 1
  fi
}

# --- AT-006: Consistent with existing env var conventions (CS-2) ---
#
# Given: Config section of each e2e file (TIMEOUT_SECS="${SKILL_E2E_TIMEOUT_SECS:-120}")
# When:  Inspect format and placement of E2E_MODEL definition
# Then:  All 11 files define E2E_MODEL immediately after the TIMEOUT_SECS line

@test "#278 AT-006: E2E_MODEL is defined immediately after TIMEOUT_SECS line" {
  local failed=()
  for f in ${E2E_GLOB}; do
    if ! grep -A1 'TIMEOUT_SECS=' "$f" | grep -q 'E2E_MODEL="\${SKILL_E2E_MODEL:-sonnet}"'; then
      failed+=("$f")
    fi
  done
  if [ "${#failed[@]}" -gt 0 ]; then
    echo "Files where E2E_MODEL is not immediately after TIMEOUT_SECS:"
    printf '  %s\n' "${failed[@]}"
    return 1
  fi
}

# --- AT-008: Change scope does not encroach on Non-Goals ---
#
# Given: Diff between working branch and main
# When:  Inspect changed file list
# Then:  No changes to tests/fixtures/headless/, scripts/run-skill-e2e.sh,
#        or docs/guides/headless-skill-testing.md

@test "#278 AT-008: tests/fixtures/headless/ has no changes" {
  local changed
  changed=$(git diff main --name-only 2>/dev/null | grep '^tests/fixtures/headless/' || true)
  if [ -n "$changed" ]; then
    echo "Non-Goals files changed:"
    echo "$changed"
    return 1
  fi
}

@test "#278 AT-008: scripts/run-skill-e2e.sh has no changes" {
  ! git diff main --name-only 2>/dev/null | grep -q '^scripts/run-skill-e2e.sh$'
}

@test "#278 AT-008: docs/guides/headless-skill-testing.md has no changes" {
  ! git diff main --name-only 2>/dev/null | grep -q '^docs/guides/headless-skill-testing.md$'
}
