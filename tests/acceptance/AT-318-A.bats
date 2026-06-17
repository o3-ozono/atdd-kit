#!/usr/bin/env bats
# @covers: skills/autopilot/SKILL.md skills/full-autopilot/SKILL.md docs/methodology/autopilot-iron-law.md
# =============================================================================
# AT-318-A: hand-off モード — Story 受け入れ（doc-grade）
# User Story F4（hand-off）/ C3（疎結合）。autopilot 本体の3ゲート不変を invariant
# として pin する（AT-318-A2 は regression 候補）。
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  AP="$ROOT/skills/autopilot/SKILL.md"
  FA="$ROOT/skills/full-autopilot/SKILL.md"
  IRON="$ROOT/docs/methodology/autopilot-iron-law.md"
}

# AT-318-A1: hand-off モードが定義され、②自動承認・merge-ready 手放しが記述される
@test "AT-318-A1: hand-off mode is documented (flag, gate2 auto-approve, merge-ready handoff)" {
  grep -q -- '--hand-off' "$AP"
  grep -q 'reviewer-oracle' "$AP"
  grep -q 'merge-ready' "$AP"
  # full-autopilot skill が存在し3 lib を束ねる
  [ -f "$FA" ]
  grep -q 'lib/lease-store.sh' "$FA"
  grep -q 'lib/full-autopilot-dispatch.sh' "$FA"
  grep -q 'lib/merge-coordinator.sh' "$FA"
}

# AT-318-A2: 通常起動（非 full-autopilot）の3ゲートは不変（invariant・regression 候補）
@test "AT-318-A2: normal autopilot keeps exactly three gates (invariant)" {
  # Iron Law が三ゲート固定を既定として保持
  grep -q 'Three User gates, fixed' "$IRON"
  grep -q '通常 autopilot（非 full-autopilot）では本 AL-1 は不変' "$IRON"
  # autopilot SKILL がフラグ無し起動の不変性を明記
  grep -q 'フラグ無し起動も当然 AL-1 のまま' "$AP"
  # hand-off の上書きは hand-off フラグに閉じる（通常モードへ波及しない）
  grep -q 'hand-off フラグの無い起動には一切影響しない' "$IRON"
}

# AT-318-A3: hand-off は FA_HANDOFF env マーカーが在るときだけ honored（誰でもバイパス不可）
@test "AT-318-A3: hand-off requires the FA_HANDOFF marker (not bypassable by a bare flag)" {
  grep -q 'FA_HANDOFF=1' "$AP"
  # 素の --hand-off では3ゲート維持（hard precondition の明文）
  grep -Eq 'マーカーが無い起動では.*--hand-off.*無視|無視され、厳密3ゲート|honor する.*前に必ず' "$AP"
  grep -q 'FA_HANDOFF=1' "$FA"
  # launcher は inline（process-scoped）で設定し永続 export しない（stray export 事故防止）
  RUN="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/lib/full-autopilot-run.sh"
  grep -q 'FA_HANDOFF=1 claude' "$RUN"
  ! grep -qE '^[[:space:]]*export[[:space:]]+FA_HANDOFF' "$RUN"
}
