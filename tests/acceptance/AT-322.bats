#!/usr/bin/env bats
# @covers: skills/fixing-flaky-tests/SKILL.md skills/autopilot/SKILL.md docs/methodology/route-eligibility.md docs/methodology/autopilot-iron-law.md docs/methodology/autopilot-design-gate.md commands/flaky-fix.md
# Acceptance Tests for Issue #322 — flaky-test-fix 専用の軽量ルート（bugfix ルートの兄弟）
# Corresponds to docs/issues/322-flaky-test-fix-route/acceptance-tests.md
#
# Anchor (AL-2): docs/issues/322-flaky-test-fix-route/acceptance-tests.md
# 不変条件をアサートする（version・日付・行数・反復回数 N の具体値を exact-pin しない, #289）。
#
# SCOPE NOTE (過剰主張防止): the deliverables here are skill / methodology-doc / command
# edits, so nearly every AT below is a STATIC grep (text-presence) over those files.
# The flaky 反復赤→N 回連続緑 convergence is an orchestration RUNTIME property and
# CANNOT be exercised by text-grep. This suite therefore pins the WIRING that produces
# iterative 赤→N 回連続緑 — it does NOT itself run a real fix loop and observe the
# runtime behavior. The actual convergence oracle behavior is verified by the wiring
# pins here PLUS the out-of-band autopilot replay/fixture path (the same no-runtime-suite
# policy AT-308 / AT-302 / AT-305 use to pin document structure).

FIXING="skills/fixing-flaky-tests/SKILL.md"
AUTO="skills/autopilot/SKILL.md"
ROUTE="docs/methodology/route-eligibility.md"
IRON="docs/methodology/autopilot-iron-law.md"
DGATE="docs/methodology/autopilot-design-gate.md"
CMD="commands/flaky-fix.md"
PLUGIN_JSON=".claude-plugin/plugin.json"
CHANGELOG="CHANGELOG.md"
BUG_FILE="skills/bug/SKILL.md"
DBG_FILE="skills/debugging/SKILL.md"
ATDD_FILE="skills/running-atdd-cycle/SKILL.md"
REV_FILE="skills/reviewing-deliverables/SKILL.md"
MERGE_FILE="skills/merging-and-deploying/SKILL.md"
FIXBUGS_FILE="skills/fixing-bugs/SKILL.md"

# ---------------------------------------------------------------------------
# AT-322-1 / AT-322-1b / AT-322-2 / AT-322-3 / AT-322-4 / AT-322-5 / AT-322-7
# / AT-322-8 / AT-322-9 / AT-322-12
# are owned by tests/test_fixing_flaky_tests_skill.bats (skill structural suite).
# This acceptance suite pins the cross-file / cross-doc invariants.
# ---------------------------------------------------------------------------

# AT-322-3: platform-aware reproduction, external refs only
@test "AT-322-3: SKILL.md wires 3-platform iterative reproduction (other/web/iOS) and records failure rate" {
  grep -qiE 'other|bats|loop' "$FIXING"
  grep -q 'playwright-cli' "$FIXING"
  grep -qiE 'Xcode|simulator' "$FIXING"
  grep -qiE 'failure rate|失敗率' "$FIXING"
  grep -qiE 'single.?run|単発' "$FIXING"
}

# AT-322-6: cause-agreement gate cross-doc consistency
@test "AT-322-6: cross-doc cause-agreement token present in BOTH iron-law.md and design-gate.md (#289 stable token)" {
  grep -qF 'cause-agreement' "$IRON"
  grep -qF 'cause-agreement' "$DGATE"
}

@test "AT-322-6: both docs name the flaky approval target (non-determinism classification + failure rate)" {
  grep -qiE 'non-determinism|非決定性' "$IRON"
  grep -qiE 'failure rate|失敗率' "$IRON"
  grep -qiE 'non-determinism|非決定性' "$DGATE"
  grep -qiE 'failure rate|失敗率' "$DGATE"
}

@test "AT-322-6: gate count stays three in iron-law.md (specialization, not removal/addition)" {
  grep -qiE 'gate count stays three|three gates|三のまま|stays three' "$IRON"
}

@test "AT-322-6: both docs have flaky-specific cause-agreement section" {
  grep -qiE 'flaky' "$IRON"
  grep -qiE 'flaky' "$DGATE"
}

# AT-322-8: flaky route determination lives in route-eligibility.md (SoT)
@test "AT-322-8: route-eligibility.md defines flaky route signals (type:flaky + 4 keywords)" {
  grep -q 'type:flaky' "$ROUTE"
  grep -q 'flaky' "$ROUTE"
  grep -q '不安定' "$ROUTE"
  grep -q '間欠的に失敗' "$ROUTE"
  grep -q 'intermittent' "$ROUTE"
}

@test "AT-322-8: route-eligibility.md defines flaky/bugfix boundary" {
  grep -qiE 'non-deterministic|非決定的|non-determinism' "$ROUTE"
}

@test "AT-322-8: route-eligibility.md keeps the No Auto-Routing invariant" {
  grep -qiE 'No Auto-Routing|Recommendation Only|推奨のみ' "$ROUTE"
}

@test "AT-322-8: route-eligibility.md has low-confidence fallback (#305 one-tap)" {
  grep -qiE 'low.?confidence|低確信' "$ROUTE"
  grep -qiE '#305|one-tap|AskUserQuestion|User confirmation' "$ROUTE"
}

@test "AT-322-8: autopilot SKILL.md references route-eligibility.md for the flaky route (no duplicated logic body)" {
  grep -q 'route-eligibility.md' "$AUTO"
  grep -qiE 'flaky' "$AUTO"
}

# AT-322-9: explicit command /atdd-kit:flaky-fix
@test "AT-322-9: commands/flaky-fix.md invokes the fixing-flaky-tests route with an issue argument" {
  grep -q 'fixing-flaky-tests' "$CMD"
  grep -qE '<issue>|issue-number|<issue-number>' "$CMD"
  grep -qE '/atdd-kit:flaky-fix' "$CMD"
}

# AT-322-10: flaky oracle wiring in autopilot-iron-law.md + autopilot SKILL.md loader stub
@test "AT-322-10: autopilot-iron-law.md defines flaky convergence oracle (N consecutive green + no regression + single green not convergence)" {
  grep -qiE 'N 回連続 green|N consecutive green|N consecutive' "$IRON"
  grep -qiE '既存テスト非破壊|既存回帰なし|no regressions|existing tests' "$IRON"
  grep -qiE '単発 green を収束としない|single.?run.*not.*convergence|single.?green.*not' "$IRON"
}

@test "AT-322-10: autopilot-iron-law.md flaky AL-3 coverage specialized to iterative failing anchor (not degraded to tests pass)" {
  grep -qiE 'specializ' "$IRON"
  grep -qiE 'failing アンカー|failing anchor|反復.*アンカー' "$IRON"
  # AL-3 の AND 4 条件構造が壊れていない
  grep -qE 'AND\(' "$IRON"
}

@test "AT-322-10: flaky merge stays a User gate (AL-1) — never auto-merge" {
  grep -qiE 'User merge gate|merge.*User gate' "$IRON"
  grep -qiE 'auto-merge|never auto' "$IRON"
}

@test "AT-322-10: autopilot SKILL.md has flaky oracle loader stub referencing autopilot-iron-law.md (wiring body not duplicated)" {
  grep -q 'autopilot-iron-law.md' "$AUTO"
  grep -qiE 'flaky oracle' "$AUTO"
}

@test "AT-322-10: autopilot SKILL.md line count is at most 280 (3rd budget raise forbidden)" {
  local n
  n=$(wc -l < "$AUTO" | tr -d ' ')
  [ "$n" -le 280 ]
}

# AT-322-12: existing skills and sibling route are unedited (CS-2)
@test "AT-322-12: bug / debugging / running-atdd-cycle / reviewing-deliverables / merging-and-deploying / fixing-bugs are unedited" {
  run git diff --quiet \
    "$BUG_FILE" "$DBG_FILE" "$ATDD_FILE" "$REV_FILE" "$MERGE_FILE" "$FIXBUGS_FILE"
  [ "$status" -eq 0 ]
}

# AT-322-13: version/CHANGELOG consistency guarded by invariant (#289)
@test "AT-322-13: plugin.json version matches CHANGELOG latest release heading (invariant, no exact-version pin)" {
  local plugin_ver changelog_ver
  plugin_ver=$(jq -r '.version' "$PLUGIN_JSON")
  changelog_ver=$(grep -E '^## \[[0-9]' "$CHANGELOG" | head -1 | sed 's/## \[//;s/\].*//')
  [ "$plugin_ver" = "$changelog_ver" ]
}

# ---------------------------------------------------------------------------
# WIRING-PIN scope assertion: this suite pins the existence of the
# 反復赤→N 回連続緑-producing wiring; the real fix loop is NOT owned here
# (out-of-band autopilot replay path owns it).
# ---------------------------------------------------------------------------
@test "AT-322: wiring pin -- fixing-flaky-tests encodes the iterative red-to-N-consecutive-green oracle anchor" {
  # 反復赤→N 回連続緑 を生む wiring が存在することを pin する
  grep -qiE 'failing anchor|反復.*アンカー|repeatedly.?failing' "$FIXING"
  grep -qiE 'N consecutive|N 回連続' "$FIXING"
  grep -qiE 'cause-agreement' "$FIXING"
}
