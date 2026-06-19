#!/usr/bin/env bats
# @covers: addons/web/addon.yml
# @covers: addons/web/config/impact_rules.yml
# Issue #323: web addon deploy entries and impact_rules template structure tests

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
WEB_ADDON="$REPO_ROOT/addons/web/addon.yml"
WEB_RULES="$REPO_ROOT/addons/web/config/impact_rules.yml"
IMPACT_SCRIPT="$REPO_ROOT/scripts/impact_map.sh"

# ---------------------------------------------------------------------------
# addon.yml schema validation
# ---------------------------------------------------------------------------

@test "web-addon: addon.yml exists" {
  [ -f "$WEB_ADDON" ]
}

@test "web-addon: addon.yml has name field" {
  grep -q "^name:" "$WEB_ADDON"
}

@test "web-addon: addon.yml has display_name field" {
  grep -q "^display_name:" "$WEB_ADDON"
}

@test "web-addon: addon.yml has deploy field" {
  grep -q "^deploy:" "$WEB_ADDON"
}

@test "web-addon: addon.yml has detect field" {
  grep -q "^detect:" "$WEB_ADDON"
}

@test "web-addon: addon.yml deploy includes impact_map.sh src entry" {
  grep -q "impact_map.sh" "$WEB_ADDON"
}

@test "web-addon: addon.yml deploy includes impact_rules.yml src entry" {
  grep -q "impact_rules.yml" "$WEB_ADDON"
}

@test "web-addon: detect patterns include package.json" {
  grep -q "package.json" "$WEB_ADDON"
}

# ---------------------------------------------------------------------------
# impact_rules.yml template structure
# ---------------------------------------------------------------------------

@test "web-rules: impact_rules.yml exists" {
  [ -f "$WEB_RULES" ]
}

@test "web-rules: template has rules: section" {
  grep -q "^rules:" "$WEB_RULES"
}

@test "web-rules: template contains src/ path rules (web project standard)" {
  grep -q "src/" "$WEB_RULES"
}

@test "web-rules: template contains tests/ or __tests__/ path rules" {
  grep -qE "tests/|__tests__/" "$WEB_RULES"
}

@test "web-rules: template is parseable by impact_map.sh (exit 0 under --all)" {
  run bash "$IMPACT_SCRIPT" --config "$WEB_RULES" --all --layer skill-e2e
  [ "$status" -eq 0 ]
}

@test "web-rules: template contains at least one skill-e2e entry" {
  grep -q "skill-e2e:" "$WEB_RULES"
}
