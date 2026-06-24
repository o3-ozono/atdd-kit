#!/usr/bin/env bats
# @covers: skills/session-start/SKILL.md, skills/express/SKILL.md, docs/methodology/route-eligibility.md
# Acceptance Tests for Issue #302: autopilot/express route determination step
# Corresponds to docs/issues/302-route-autopilot-express/acceptance-tests.md
#
# #304 FS-1: 経路判定信号の本文は docs/methodology/route-eligibility.md へ移設され、
#   session-start Step 3 はその参照に置換された。信号 content を assert する pin は
#   削除・緩和せず grep ターゲットを route-eligibility.md へ振り替える（CS-2 参照先更新）。
#   session-start 本体に残る構造（Step 3 見出し・両経路への言及・推奨経路列）は不変のまま session-start を見る。

# lifecycle: [regression]

SKILL_SESSION="skills/session-start/SKILL.md"
SKILL_EXPRESS="skills/express/SKILL.md"
ROUTE_DOC="docs/methodology/route-eligibility.md"
PLUGIN_JSON=".claude-plugin/plugin.json"
CHANGELOG="CHANGELOG.md"

# ---------------------------------------------------------------------------
# AT-001: AC1 -- Recommended Tasks has recommended-route column
# ---------------------------------------------------------------------------

@test "AT-001 AC1: Recommended Tasks template has 'recommended route' column header in Japanese" {
  local section
  section=$(sed -n '/### Recommended Tasks/,/^###/p' "$SKILL_SESSION")
  echo "$section" | grep -q '推奨経路'
}

@test "AT-001 AC1: Recommended Tasks template header has 4 columns (Priority|Issue|Reason|route)" {
  local section
  section=$(sed -n '/### Recommended Tasks/,/^###/p' "$SKILL_SESSION")
  echo "$section" | grep -qE '\|\s*Priority\s*\|\s*Issue\s*\|\s*Reason\s*\|\s*推奨経路\s*\|'
}

# ---------------------------------------------------------------------------
# AT-002: AC2 -- Step 3 defines hybrid routing with both signals
# ---------------------------------------------------------------------------

@test "AT-002 AC2: Task Recommendation Rules has Step 3" {
  local section
  section=$(sed -n '/### Task Recommendation Rules/,/^##[^#]/p' "$SKILL_SESSION")
  echo "$section" | grep -qi 'Step 3'
}

@test "AT-002 AC2: Step 3 mentions both autopilot and express" {
  local section
  section=$(sed -n '/Step 3/,/Step 4\|^###\|^##[^#]/p' "$SKILL_SESSION")
  echo "$section" | grep -q 'autopilot'
  echo "$section" | grep -q 'express'
}

@test "AT-002 AC2: route-eligibility defines express-eligible signals (docs/README/typo/gitignore/version-bump)" {
  # #304 FS-1: 信号 content は route-eligibility.md へ移設（CS-2 参照先更新）
  grep -qiE 'docs|README|typo|gitignore|version.bump|version bump' "$ROUTE_DOC"
}

@test "AT-002 AC2: route-eligibility defines autopilot signals (new feature/behavior change/CI/dependency/security)" {
  # #304 FS-1: 信号 content は route-eligibility.md へ移設（CS-2 参照先更新）
  grep -qiE 'new feature|behavior|CI|hooks|depend|security|新機能|挙動変更|依存|セキュリティ' "$ROUTE_DOC"
}

@test "AT-002 AC2: route-eligibility specifies hybrid determination with labels, keywords, and LLM" {
  # #304 FS-1: 信号 content は route-eligibility.md へ移設（CS-2 参照先更新）
  grep -qi 'label' "$ROUTE_DOC"
  grep -qiE 'keyword|キーワード' "$ROUTE_DOC"
  grep -qi 'LLM' "$ROUTE_DOC"
}

# ---------------------------------------------------------------------------
# AT-003: AC3 -- Ambiguous cases fall back to autopilot
# ---------------------------------------------------------------------------

@test "AT-003 AC3: route-eligibility documents fallback to autopilot when ambiguous" {
  # #304 FS-1: 信号 content は route-eligibility.md へ移設（CS-2 参照先更新）
  grep -qiE 'doubt|ambiguous|unclear|曖昧|不明' "$ROUTE_DOC"
  grep -q 'autopilot' "$ROUTE_DOC"
}

# ---------------------------------------------------------------------------
# AT-004: AC4 -- Recommendation only, no auto-routing
# ---------------------------------------------------------------------------

@test "AT-004 AC4: route-eligibility states recommendation is advisory only, no auto-routing" {
  # #304 FS-1: 不変条件 content は route-eligibility.md へ移設（CS-2 参照先更新）
  grep -qiE 'recommend.*only|only.*recommend|推奨.*のみ|のみ.*推奨|auto.route.*not|not.*auto.route|自動.*しない|しない.*自動|never.*auto|auto.*never' "$ROUTE_DOC"
}

# ---------------------------------------------------------------------------
# AT-005: AC5 -- express existing triggers preserved
# ---------------------------------------------------------------------------

@test "AT-005 AC5: express SKILL.md still has APPROVAL-GATE" {
  grep -q 'APPROVAL-GATE' "$SKILL_EXPRESS"
}

@test "AT-005 AC5: express SKILL.md still has scope-overflow guard" {
  grep -qiE 'scope.overflow|scope overflow' "$SKILL_EXPRESS"
}

@test "AT-005 AC5: express SKILL.md still has OK/NG criteria" {
  grep -qiE '\*\*OK|OK.*applies|\*\*NG|NG.*does not apply|OK 基準|NG 基準' "$SKILL_EXPRESS"
}

# ---------------------------------------------------------------------------
# AT-006: AC6 -- Skills Changes Require Test Evidence + autopilot SKILL.md unchanged
# ---------------------------------------------------------------------------

@test "AT-006 AC6: skills/autopilot/SKILL.md exists and documents the objective-gate oracle" {
  # #302 の descope 遵守チェック（git diff ベース）は点時間依存であり regression に不適切。
  # #296 で autopilot SKILL.md 自体の修正（enum 制約化）が承認されたため、不変条件チェックへ置換していた。
  # #355/#359: 収束ループから LLM レビューを除去し、客観ゲート（redObserved/atGreen/coverageOk）の
  #   objective oracle に一本化。これに伴い VERDICT_SCHEMA は設計的に削除された。
  #   AC6 の趣旨「autopilot SKILL.md が存在し収束機構を文書化している」を維持するため、
  #   旧 VERDICT_SCHEMA の assert を現行の客観ゲート機構の assert に振り替える。
  [[ -f "skills/autopilot/SKILL.md" ]] || {
    echo "FAIL: skills/autopilot/SKILL.md が存在しない"
    return 1
  }
  grep -q "objective oracle" "skills/autopilot/SKILL.md" || {
    echo "FAIL: skills/autopilot/SKILL.md に objective oracle が存在しない"
    return 1
  }
  grep -q "redObserved" "skills/autopilot/SKILL.md" || {
    echo "FAIL: skills/autopilot/SKILL.md に redObserved が存在しない"
    return 1
  }
  grep -q "atGreen" "skills/autopilot/SKILL.md" || {
    echo "FAIL: skills/autopilot/SKILL.md に atGreen が存在しない"
    return 1
  }
  grep -q "coverageOk" "skills/autopilot/SKILL.md" || {
    echo "FAIL: skills/autopilot/SKILL.md に coverageOk が存在しない"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-007: AC7 -- version bump + CHANGELOG consistency (regression invariant)
# ---------------------------------------------------------------------------

@test "AT-007 AC7: plugin.json version matches CHANGELOG latest release heading" {
  local plugin_ver changelog_ver
  plugin_ver=$(jq -r '.version' "$PLUGIN_JSON")
  # [Unreleased] セクションをスキップし、最初のバージョン番号付き見出しを取得する
  changelog_ver=$(grep -E '^## \[[0-9]' "$CHANGELOG" | head -1 | sed 's/## \[//;s/\].*//')
  [[ "$plugin_ver" == "$changelog_ver" ]]
}
