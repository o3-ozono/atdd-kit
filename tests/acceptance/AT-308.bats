#!/usr/bin/env bats
# @covers: skills/fixing-bugs/SKILL.md skills/autopilot/SKILL.md docs/methodology/route-eligibility.md docs/methodology/autopilot-iron-law.md docs/methodology/autopilot-design-gate.md commands/autofix.md
# Acceptance Tests for Issue #308 — bugfix 専用の軽量ルート（フル機能ルートと分離）
# Corresponds to docs/issues/308-category-specific-routes/acceptance-tests.md
#
# Anchor (AL-2): docs/issues/308-category-specific-routes/acceptance-tests.md
# 不変条件をアサートする（version・日付・行数を exact-pin しない, #289）。
#
# SCOPE NOTE (finding priority-3, 過剰主張防止): the deliverables here are skill /
# methodology-doc / command edits, so nearly every AT below is a STATIC grep
# (text-presence) over those files. The bugfix 赤→緑 convergence is an
# orchestration RUNTIME property and CANNOT be exercised by text-grep. This suite
# therefore pins the WIRING that produces a repro 赤→緑 — it does NOT itself run a
# real fix loop and observe 赤→緑. The actual 赤→緑 oracle behavior is verified by
# the wiring pins here PLUS the out-of-band autopilot replay/fixture path (the same
# no-runtime-suite policy AT-302 / AT-305 use to pin document structure).

FIXING="skills/fixing-bugs/SKILL.md"
AUTO="skills/autopilot/SKILL.md"
ROUTE="docs/methodology/route-eligibility.md"
IRON="docs/methodology/autopilot-iron-law.md"
DGATE="docs/methodology/autopilot-design-gate.md"
AUTOFIX="commands/autofix.md"
PLUGIN_JSON=".claude-plugin/plugin.json"
CHANGELOG="CHANGELOG.md"
PLAN="docs/issues/308-category-specific-routes/plan.md"

# ---------------------------------------------------------------------------
# AT-308-1 / AT-308-1b / AT-308-2 / AT-308-3 / AT-308-4 / AT-308-8 / AT-308-9
# are owned by tests/test_fixing_bugs_skill.bats (skill structural suite).
# This acceptance suite pins the cross-file / cross-doc invariants.
# ---------------------------------------------------------------------------

# AT-308-5: bugfix route determination lives in route-eligibility.md (SoT);
#           autopilot only references it (no duplicated logic); No Auto-Routing kept.
@test "AT-308-5: route-eligibility.md defines bugfix route signals (label + keyword + low-confidence fallback)" {
  grep -qiE 'bugfix' "$ROUTE"
  grep -q 'type:bug' "$ROUTE"
  grep -qiE 'low.?confidence|低確信' "$ROUTE"
  # #305 ワンタップ整合 / User 確認フォールバック
  grep -qiE '#305|one-tap|AskUserQuestion|User confirmation' "$ROUTE"
}

@test "AT-308-5: route-eligibility.md keeps the No Auto-Routing invariant" {
  grep -qiE 'No Auto-Routing|Recommendation Only|推奨のみ' "$ROUTE"
}

@test "AT-308-5: autopilot SKILL.md references route-eligibility.md for the bugfix route (no duplicated logic body)" {
  # autopilot は判定ロジック本体を持たず route-eligibility.md を参照する
  grep -q 'route-eligibility.md' "$AUTO"
  grep -qiE 'bugfix' "$AUTO"
}

# AT-308-6: explicit command /atdd-kit:autofix wires to the fixing-bugs route.
@test "AT-308-6: commands/autofix.md invokes the fixing-bugs route with an issue argument" {
  grep -q 'fixing-bugs' "$AUTOFIX"
  grep -qE '<issue|<issue-number>|issue-number' "$AUTOFIX"
  grep -qE '/atdd-kit:autofix' "$AUTOFIX"
}

# AT-308-7: bugfix convergence oracle + AL-3 coverage specialization.
@test "AT-308-7: autopilot-iron-law.md defines the bugfix oracle (regression green + no existing regression + repro red-to-green)" {
  grep -qiE '回帰テスト green|回帰.*green' "$IRON"
  grep -qiE '既存回帰なし|既存テスト非破壊' "$IRON"
  grep -qiE '赤.?→.?緑|赤→緑' "$IRON"
}

@test "AT-308-7: AL-3 AC->AT coverage term is SPECIALIZED to failing-repro coverage (not degraded to 'tests pass')" {
  grep -qiE 'specializ' "$IRON"
  grep -qiE 'coverage' "$IRON"
  grep -qiE 'reproduction test|失敗再現テスト|repro' "$IRON"
  # AL-3 の AND 4 条件構造が壊れていない
  grep -qE 'AND\(' "$IRON"
}

@test "AT-308-7: bugfix merge stays a User gate (AL-1) — never auto-merge" {
  grep -qiE 'User merge gate|merge.*User gate|User gate' "$IRON"
  grep -qiE 'auto-merge|never auto' "$IRON"
}

@test "AT-308-7: autopilot SKILL.md references the bugfix oracle in autopilot-iron-law.md (loader stub, no wiring body duplicated)" {
  grep -q 'autopilot-iron-law.md' "$AUTO"
  grep -qiE 'bugfix oracle' "$AUTO"
}

# AT-308-7b: AL-1 three-gate invariant satisfied via cause-agreement, consistent
#            across BOTH iron-law.md and design-gate.md (no stale doc).
@test "AT-308-7b: cross-doc cause-agreement token present in BOTH iron-law.md and design-gate.md (#289 stable token, not full-sentence pin)" {
  grep -qF 'cause-agreement' "$IRON"
  grep -qF 'cause-agreement' "$DGATE"
}

@test "AT-308-7b: both docs name the same approval target (root-cause classification + failing reproduction test)" {
  grep -qiE 'root.?cause classification|根本原因分類' "$IRON"
  grep -qiE 'reproduction test|失敗再現テスト' "$IRON"
  grep -qiE 'root.?cause classification|根本原因分類' "$DGATE"
  grep -qiE 'reproduction test|失敗再現テスト' "$DGATE"
}

@test "AT-308-7b: gate count stays three (specialization, not removal/addition)" {
  grep -qiE 'gate count stays three|three gates|三のまま|stays three' "$IRON"
}

# AT-308-9b: half-scope explicit confirmation + flaky follow-up Issue created.
@test "AT-308-9b: plan documents the bugfix-only / flaky-next half-scope and links a created follow-up Issue" {
  grep -qiE 'half-scope|half scope|半スコープ' "$PLAN"
  grep -qiE 'flaky' "$PLAN"
  # cause-agreement ゲートで half-scope を明示提示する旨
  grep -qiE 'cause-agreement|原因合意' "$PLAN"
  # フォローアップ Issue が「作成済み」かつ番号付きで参照されている
  grep -qiE '作成済み|created' "$PLAN"
  grep -qE '#[0-9]+' "$PLAN"
}

# AT-308-10: version/CHANGELOG consistency guarded by INVARIANT, never an exact
#            version pin (#289: literal pins turned post-merge regression red).
@test "AT-308-10: plugin.json version matches CHANGELOG latest release heading (invariant, no exact-version pin)" {
  local plugin_ver changelog_ver
  plugin_ver=$(jq -r '.version' "$PLUGIN_JSON")
  changelog_ver=$(grep -E '^## \[[0-9]' "$CHANGELOG" | head -1 | sed 's/## \[//;s/\].*//')
  [ "$plugin_ver" = "$changelog_ver" ]
}

# ---------------------------------------------------------------------------
# WIRING-PIN scope assertion (finding priority-3): this suite pins the existence
# of the 赤→緑-producing wiring; the real fix loop is NOT owned here (out-of-band
# autopilot replay path owns it). Asserted by the scope note at the top of file
# and by the presence of the repro-test anchor wiring in the skill, below.
# ---------------------------------------------------------------------------
@test "AT-308: wiring pin -- fixing-bugs encodes the repro red-to-green oracle anchor (suite does NOT run a real fix loop)" {
  # 赤→緑 を生む wiring が存在することを pin する (ランタイム fix loop は AT が own しない)
  grep -qiE 'failing test|失敗再現テスト' "$FIXING"
  grep -qiE 'anchor' "$FIXING"
}
