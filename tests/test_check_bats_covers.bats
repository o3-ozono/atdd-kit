#!/usr/bin/env bats
# @covers: scripts/check_bats_covers.sh

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/check_bats_covers.sh"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/impact"

@test "check_bats_covers: valid file exits 0 with OK message" {
  run "$SCRIPT" "$FIXTURE_DIR/valid.bats"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
}

@test "check_bats_covers: missing @covers exits non-zero with violation listed" {
  run "$SCRIPT" "$FIXTURE_DIR/missing.bats"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing.bats"* ]]
}

@test "check_bats_covers: empty @covers value exits non-zero" {
  run "$SCRIPT" "$FIXTURE_DIR/empty_covers.bats"
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty_covers.bats"* ]]
}

@test "check_bats_covers: scans multiple files and reports all violations" {
  run "$SCRIPT" "$FIXTURE_DIR/valid.bats" "$FIXTURE_DIR/missing.bats"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing.bats"* ]]
}

@test "check_bats_covers: all real BATS files pass (integration gate)" {
  run "$SCRIPT" \
    "$REPO_ROOT"/tests/*.bats \
    "$REPO_ROOT"/addons/ios/tests/*.bats
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
}
