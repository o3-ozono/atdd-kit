#!/usr/bin/env bats
# @covers: addons/ios/**
# AC5: addon.yml guidance includes Device Set isolation info.

ADDON_YML="addons/ios/addon.yml"

# --- AC5.1: addon.yml mentions SIM_GOLDEN_SET ---

@test "AC5.1: addon.yml mentions SIM_GOLDEN_SET environment variable" {
  grep -q 'SIM_GOLDEN_SET' "$ADDON_YML"
}

# --- AC5.2: addon.yml mentions Device Set ---

@test "AC5.2: addon.yml mentions Device Set isolation" {
  grep -qi 'Device Set' "$ADDON_YML"
}

# --- AC5.3: addon.yml guidance mentions SIM_DEFAULT_SET ---

@test "AC5.3: addon.yml mentions SIM_DEFAULT_SET environment variable" {
  grep -q 'SIM_DEFAULT_SET' "$ADDON_YML"
}

# --- AC5.4: addon.yml guidance explains cross-set clone ---

@test "AC5.4: addon.yml guidance mentions cross-set clone" {
  grep -qi 'cross.set.*clone\|clone.*Device Set' "$ADDON_YML"
}
