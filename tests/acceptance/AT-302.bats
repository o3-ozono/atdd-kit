#!/usr/bin/env bats
# @covers: skills/session-start/SKILL.md, skills/express/SKILL.md
# Acceptance Tests for Issue #302: autopilot/express route determination step
# Corresponds to docs/issues/302-route-autopilot-express/acceptance-tests.md

# lifecycle: [regression]

SKILL_SESSION="skills/session-start/SKILL.md"
SKILL_EXPRESS="skills/express/SKILL.md"
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

@test "AT-002 AC2: Step 3 defines express-eligible signals (docs/README/typo/gitignore/version-bump)" {
  local section
  section=$(sed -n '/Step 3/,/Step 4\|^###\|^##[^#]/p' "$SKILL_SESSION")
  echo "$section" | grep -qiE 'docs|README|typo|gitignore|version.bump|version bump'
}

@test "AT-002 AC2: Step 3 defines autopilot signals (new feature/behavior change/CI/dependency/security)" {
  local section
  section=$(sed -n '/Step 3/,/Step 4\|^###\|^##[^#]/p' "$SKILL_SESSION")
  echo "$section" | grep -qiE 'new feature|behavior|CI|hooks|depend|security|新機能|挙動変更|依存|セキュリティ'
}

@test "AT-002 AC2: Step 3 specifies hybrid determination with labels, keywords, and LLM" {
  local section
  section=$(sed -n '/Step 3/,/Step 4\|^###\|^##[^#]/p' "$SKILL_SESSION")
  echo "$section" | grep -qi 'label'
  echo "$section" | grep -qiE 'keyword|キーワード'
  echo "$section" | grep -qi 'LLM'
}

# ---------------------------------------------------------------------------
# AT-003: AC3 -- Ambiguous cases fall back to autopilot
# ---------------------------------------------------------------------------

@test "AT-003 AC3: Step 3 documents fallback to autopilot when ambiguous" {
  local section
  section=$(sed -n '/Step 3/,/Step 4\|^###\|^##[^#]/p' "$SKILL_SESSION")
  echo "$section" | grep -qiE 'doubt|ambiguous|unclear|曖昧|不明'
  echo "$section" | grep -q 'autopilot'
}

# ---------------------------------------------------------------------------
# AT-004: AC4 -- Recommendation only, no auto-routing
# ---------------------------------------------------------------------------

@test "AT-004 AC4: Step 3 states recommendation is advisory only, no auto-routing" {
  local section
  section=$(sed -n '/Step 3/,/Step 4\|^###\|^##[^#]/p' "$SKILL_SESSION")
  echo "$section" | grep -qiE 'recommend.*only|only.*recommend|推奨.*のみ|のみ.*推奨|auto.route.*not|not.*auto.route|自動.*しない|しない.*自動'
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

@test "AT-006 AC6: skills/autopilot/SKILL.md is not modified in this branch" {
  # CI-safe: リモートブランチが未フェッチの場合も merge-base で安全に比較する
  local base changed
  base=$(git merge-base HEAD origin/main 2>/dev/null \
      || git merge-base HEAD main 2>/dev/null \
      || git rev-parse HEAD~1 2>/dev/null)
  changed=$(git diff --name-only "$base" HEAD 2>/dev/null)
  if echo "$changed" | grep -q 'skills/autopilot/SKILL.md'; then
    echo "FAIL: skills/autopilot/SKILL.md has been modified (descope violation)"
    return 1
  fi
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
