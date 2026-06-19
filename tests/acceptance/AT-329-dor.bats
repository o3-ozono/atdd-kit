#!/usr/bin/env bats
# @covers: skills/full-autopilot/SKILL.md docs/methodology/definition-of-ready.md
# =============================================================================
# AT-329-dor: full-autopilot SKILL.md が DoR 整合（US-5 / doc 整合）
# AT-329-5a: ready-to-go 前提が正典 DoR に一致
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FA="$ROOT/skills/full-autopilot/SKILL.md"
  DOR="$ROOT/docs/methodology/definition-of-ready.md"
}

# AT-329-5a: full-autopilot SKILL.md が DoR（definition-of-ready.md）を参照している
@test "AT-329-5a: full-autopilot SKILL.md references definition-of-ready.md" {
  grep -q 'definition-of-ready' "$FA"
}

# AT-329-5a: ready-to-go = DoR + plan review PASS の記述が存在する
@test "AT-329-5a: full-autopilot SKILL.md states ready-to-go = DoR + plan review PASS" {
  grep -qE 'ready-to-go.*DoR|DoR.*ready-to-go|DoR.*plan review PASS|plan review PASS.*DoR' "$FA"
}

# AT-329-5a: 「PRD が承認済み」のみを ready-to-go の前提とする旧記述が残っていない
@test "AT-329-5a: old PRD-only prerequisite is no longer the sole prerequisite" {
  # The old wording was "PRD が承認済み（壁打ち済み）であることが ready-to-go の前提"
  # It must NOT appear as the sole prerequisite (old pattern); the new text includes DoR + plan
  ! grep -q 'PRD が承認済み（壁打ち済み）であることが .ready-to-go. の前提' "$FA"
}

# AT-329-5a: definition-of-ready.md 自体が存在する
@test "AT-329-5a: docs/methodology/definition-of-ready.md exists" {
  [ -f "$DOR" ]
}

# AT-329-5a: definition-of-ready.md に ready-to-go = DoR + plan review PASS の定義がある
@test "AT-329-5a: definition-of-ready.md defines ready-to-go as DoR + plan review PASS" {
  grep -qiE 'ready-to-go.*plan review PASS|plan review PASS.*ready-to-go' "$DOR"
}
