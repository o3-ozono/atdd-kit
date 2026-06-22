#!/usr/bin/env bats
# @covers: skills/batch-discovery/SKILL.md
# AT-341-A: batch-discovery を独立スキルとして起動できる（FS-1 / CS-2）
# Issue #341
#
# Asserts structural invariants of skills/batch-discovery/SKILL.md:
#   - name: batch-discovery
#   - explicit trigger /atdd-kit:batch-discovery
#   - auto-invoke guard (confirm before invoking)
#   - Input: Issue group + parallel K
#   - Responsibility Boundary table with full-autopilot non-modification
#
# lifecycle: [green]

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

setup() {
  REPO="$(repo_root)"
  SKILL="${REPO}/skills/batch-discovery/SKILL.md"
}

# ---------------------------------------------------------------------------
# AT-341-A1: SKILL.md 独立スキル契約（Trigger / Input / boundary / 本体非改変）
# ---------------------------------------------------------------------------

@test "AT-341-A1: skills/batch-discovery/SKILL.md exists" {
  test -f "$SKILL"
}

@test "AT-341-A1: SKILL.md frontmatter contains name: batch-discovery" {
  grep -q 'name: batch-discovery' "$SKILL"
}

@test "AT-341-A1: SKILL.md contains explicit trigger /atdd-kit:batch-discovery" {
  grep -q '/atdd-kit:batch-discovery' "$SKILL"
}

@test "AT-341-A1: SKILL.md forbids auto-invocation without confirmation" {
  grep -qiE 'auto-invoc|confirm.*before|auto-invoke.*forbidden' "$SKILL"
}

@test "AT-341-A1: SKILL.md contains Input section describing Issue group" {
  grep -qiE 'Input|issue.*number|Issue group' "$SKILL"
}

@test "AT-341-A1: SKILL.md documents parallel K parameter" {
  grep -qiE 'parallel|--parallel' "$SKILL"
}

@test "AT-341-A1: SKILL.md Responsibility Boundary table mentions full-autopilot non-modification (C3)" {
  grep -qiE 'full-autopilot.*C3|C3.*full-autopilot|not rewrite.*full-autopilot|full-autopilot.*unmodified' "$SKILL"
}

@test "AT-341-A1: SKILL.md states this skill does not rewrite full-autopilot or flow skills" {
  grep -qiE 'does not rewrite|non-rewrite|batch-discovery.*preparation' "$SKILL"
}
