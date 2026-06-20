#!/usr/bin/env bats
# @covers: addons/ios/addon.yml
# @covers: addons/ios/config/impact_rules.yml
# Issue #323: iOS addon impact_rules template structure tests

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
IOS_ADDON="$REPO_ROOT/addons/ios/addon.yml"
IOS_RULES="$REPO_ROOT/addons/ios/config/impact_rules.yml"
IMPACT_SCRIPT="$REPO_ROOT/scripts/impact_map.sh"

# ---------------------------------------------------------------------------
# addon.yml deploy entries for impact runner
# ---------------------------------------------------------------------------

@test "ios-addon: addon.yml deploy includes impact_map.sh entry" {
  grep -q "impact_map.sh" "$IOS_ADDON"
}

@test "ios-addon: addon.yml deploy includes impact_rules.yml entry" {
  grep -q "impact_rules.yml" "$IOS_ADDON"
}

@test "ios-addon: addon.yml deploy impact_map.sh src is addon-relative (../../scripts/impact_map.sh)" {
  grep -qE "src:[[:space:]]*\.\./\.\./scripts/impact_map\.sh" "$IOS_ADDON"
}

@test "ios-addon: addon.yml deploy impact_rules.yml src is addon-relative (config/impact_rules.yml)" {
  grep -qE "src:[[:space:]]*config/impact_rules\.yml" "$IOS_ADDON"
}

# ---------------------------------------------------------------------------
# impact_rules.yml template structure
# ---------------------------------------------------------------------------

@test "ios-rules: impact_rules.yml exists" {
  [ -f "$IOS_RULES" ]
}

@test "ios-rules: template has rules: section" {
  grep -q "^rules:" "$IOS_RULES"
}

@test "ios-rules: template contains Sources/ path rules (iOS project standard)" {
  grep -q "Sources/" "$IOS_RULES"
}

@test "ios-rules: template contains Tests/ path rules" {
  grep -q "Tests/" "$IOS_RULES"
}

@test "ios-rules: template is parseable by impact_map.sh (exit 0 under --all)" {
  run bash "$IMPACT_SCRIPT" --config "$IOS_RULES" --all --layer skill-e2e
  [ "$status" -eq 0 ]
}

@test "ios-rules: template contains at least one skill-e2e entry" {
  grep -q "skill-e2e:" "$IOS_RULES"
}
