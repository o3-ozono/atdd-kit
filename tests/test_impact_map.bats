#!/usr/bin/env bats
# @covers: scripts/impact_map.sh
# @covers: config/impact_rules.yml
# Issue #135: test impact scope detection common infrastructure

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  WORK="${BATS_TMPDIR}/impact-map-$$"
  mkdir -p "$WORK/config" "$WORK/scripts" "$WORK/tests"
  git -C "$WORK" init -b main -q
  git -C "$WORK" config user.email "test@example.com"
  git -C "$WORK" config user.name "Test"
  git -C "$WORK" commit --allow-empty -m "base" -q
  cp "$REPO_ROOT/scripts/impact_map.sh" "$WORK/scripts/"
  SCRIPT="$WORK/scripts/impact_map.sh"
  CONFIG="$WORK/config/impact_rules.yml"
}

teardown() {
  rm -rf "$WORK" || true
}

_make_minimal_config() {
  cat > "$CONFIG" <<'EOF'
rules:
  - path: skills/**
    l4: discover plan atdd verify ship bug
    bats: "@covers skills"
  - path: lib/**
    l4: discover plan atdd verify ship bug
    bats: "@covers lib"
  - path: hooks/**
    l4: discover plan atdd verify ship
    bats: "@covers hooks"
  - path: agents/**
    l4: discover plan atdd verify ship
    bats: "@covers agents"
  - path: .claude-plugin/**
    l4: discover plan
    bats: "@covers .claude-plugin"
  - path: scripts/**
    l4: discover plan
    bats: "@covers scripts"
  - path: docs/**
    l4: discover
    bats: "@covers docs"
EOF
}

# --- AC6: invalid or missing required arguments produce clear errors ---

@test "AC6: no --layer and no --all exits non-zero with layer error on stderr and empty stdout" {
  _make_minimal_config
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  echo "$stderr" | grep -qi "layer"
}

@test "AC6: --layer XYZ unknown exits non-zero with valid layer list on stderr and empty stdout" {
  _make_minimal_config
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD --layer XYZ
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  echo "$stderr" | grep -qE "L4|BATS"
}

@test "AC6: --all without --layer exits non-zero with layer error on stderr and empty stdout" {
  _make_minimal_config
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --all
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  echo "$stderr" | grep -qi "layer"
}

@test "AC6: --layer BATS without --base and without --all exits non-zero with base error on stderr" {
  _make_minimal_config
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --layer BATS
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  echo "$stderr" | grep -qiE "base|--all"
}

# --- AC7: malformed config/impact_rules.yml produces clear errors ---

@test "AC7: config file does not exist exits non-zero with error on stderr" {
  run --separate-stderr bash "$SCRIPT" --config "$WORK/config/nonexistent.yml" --base HEAD --layer BATS
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  echo "$stderr" | grep -qi "not found\|config"
}

@test "AC7: YAML missing rules section exits non-zero with parse error on stderr" {
  cat > "$CONFIG" <<'EOF'
# no rules key here
foo: bar
EOF
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD --layer BATS
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  echo "$stderr" | grep -qiE "malformed|missing|rules"
}

@test "AC7: YAML rules section with zero entries exits non-zero with parse error on stderr" {
  cat > "$CONFIG" <<'EOF'
rules:
EOF
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD --layer BATS
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  echo "$stderr" | grep -qiE "malformed|no rules|entries"
}

@test "AC7: parse error exits with code 2" {
  cat > "$CONFIG" <<'EOF'
# malformed: no rules
not_rules: true
EOF
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD --layer BATS
  [ "$status" -eq 2 ]
}
