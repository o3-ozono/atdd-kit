#!/usr/bin/env bats
# @covers: skills/full-autopilot/SKILL.md
# =============================================================================
# AT-318-E: epic 横断 — Story 受け入れ
# E2（暴走防止・C4）は doc-grade invariant として pin（regression 候補）。
# E1（フル無人ループ）は実 claude/gh を要する live E2E のため別途（[planned]）。
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FA="$ROOT/skills/full-autopilot/SKILL.md"
}

# AT-318-E2: 消化対象は ready-to-go（PRD 承認済み）に限定 — キュー外 issue に着手しない
@test "AT-318-E2: intake is restricted to ready-to-go / PRD-approved issues (safety valve)" {
  # キュー定義が ready-to-go ラベルに限定されている
  grep -q 'ready-to-go' "$FA"
  # PRD 未承認は着手しない安全弁が明記されている（C4）
  grep -Eq 'PRD 未承認.*着手しない|着手しない.*安全弁|暴走防止の安全弁' "$FA"
}
