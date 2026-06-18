#!/usr/bin/env bats
# @covers: skills/skill-gate/SKILL.md docs/methodology/route-eligibility.md
# =============================================================================
# AT-329-skillgate: skill-gate が route-eligibility を必須チェックする（US-4 / 真因4）
# AT-329-4a: 必須チェックと override が記述されている
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SG="$ROOT/skills/skill-gate/SKILL.md"
  RE="$ROOT/docs/methodology/route-eligibility.md"
}

# AT-329-4a: skill-gate に route-eligibility 必須チェックセクションが存在する
@test "AT-329-4a: skill-gate has Route Eligibility mandatory pre-check section" {
  grep -q 'Route Eligibility' "$SG"
}

# AT-329-4a: route-eligibility.md への参照が存在する
@test "AT-329-4a: skill-gate references docs/methodology/route-eligibility.md" {
  grep -q 'route-eligibility' "$SG"
}

# AT-329-4a: 不適合モード（express on behavior-change Issue）の抑止が記述されている
@test "AT-329-4a: skill-gate documents suppression of non-compliant route mode" {
  # Should mention express + behavior-change mismatch or non-compliant
  grep -qiE 'non-compliant|不適切|不適合|挙動変更.*express|express.*挙動変更|express.*behavior.change|behavior.change.*express' "$SG"
}

# AT-329-4a: override 手段が明示されている
@test "AT-329-4a: skill-gate documents the override mechanism" {
  grep -qiE '[Oo]verride|オーバーライド' "$SG"
}

# AT-329-4a: route-eligibility.md 自体が存在する（参照先が壊れていない）
@test "AT-329-4a: docs/methodology/route-eligibility.md exists (reference target intact)" {
  [ -f "$RE" ]
}

# AT-329-4a: mandatory の語または「必須」が skill-gate に存在する
@test "AT-329-4a: skill-gate marks route eligibility check as mandatory" {
  grep -qiE 'mandatory|必須' "$SG"
}
