#!/usr/bin/env bats
# @covers: skills/batch-discovery/SKILL.md
# AT-341-D/E: 実装順序制御 + 選別最終承認ゲート（FS-6 / FS-7 / CS-2）
# Issue #341
#
# D-tests: lightweight order-recording manifest and non-goal barrier exclusion.
# E-tests: selective final approval — overturnable findings → gate, zero findings → skip.
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
# AT-341-D: 実装順序の記録による軽量順序制御（FS-6）
# ---------------------------------------------------------------------------

@test "AT-341-D1: SKILL.md describes manifest file as shared source of implementation order" {
  grep -qiE 'manifest|implementation order|keystone.*manifest|order.*manifest' "$SKILL"
}

@test "AT-341-D1: SKILL.md states dispatcher reads the manifest to respect keystone order" {
  grep -qiE 'dispatcher.*manifest|manifest.*dispatcher|reads.*manifest|reads.*order' "$SKILL"
}

@test "AT-341-D1: SKILL.md Non-Goals excludes full barrier and dynamic dependency resolution" {
  grep -qiE 'Non.Goal|Non-Goal' "$SKILL"
  grep -qiE 'barrier|dynamic.*dep' "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-341-E: 選別ピックアップ式の最終承認ゲートと AL-1 整合（FS-7 / CS-2）
# ---------------------------------------------------------------------------

@test "AT-341-E1: SKILL.md promotes overturnable-finding kinds: tradeoff, intentional-cut, scope-exclusion" {
  grep -qiE 'tradeoff|trade-off' "$SKILL"
  grep -qiE 'intentional.cut|intentional.*割り切り' "$SKILL"
  grep -qiE 'scope.exclusion|scope-exclusion' "$SKILL"
}

@test "AT-341-E1: SKILL.md states zero overturnable findings causes Gate2 to be skipped" {
  grep -qiE 'zero.*finding.*skip|skip.*zero.*finding|zero.*findings.*skip|findings.*zero.*skip' "$SKILL"
}

@test "AT-341-E1: SKILL.md does not perform bulk approval of all deliverables" {
  # SKILL.md must NOT require approval of all deliverables at once (only overturnable findings)
  local count
  count=$(grep -ciE 'bulk.*approv|approv.*all.*deliverable' "$SKILL" || true)
  [ "$count" -eq 0 ]
}

@test "AT-341-E1: SKILL.md caps Gate2 at one session (max 1 round)" {
  grep -qiE '1 session|one session|maximum.*1|max.*1.*session|0 or 1' "$SKILL"
}

@test "AT-341-E2: SKILL.md contains AL-1 human gate map or gate alignment table" {
  grep -qiE 'Gate.*①|Gate.*①|Gate ①|AL-1' "$SKILL"
}

@test "AT-341-E2: SKILL.md states Gate3 merge is full-autopilot's responsibility (unchanged)" {
  grep -qiE 'Gate.*③.*full-autopilot|full-autopilot.*Gate.*③|merge.*full-autopilot.*own|full-autopilot.*merge.*unchanged' "$SKILL"
}

@test "AT-341-E2: SKILL.md confirms AL-1 three-gate invariant is unchanged after batch-discovery handoff" {
  grep -qiE 'AL-1.*unchanged|unchanged.*AL-1|three-gate.*unchanged|AL-1.*invariant' "$SKILL"
}
