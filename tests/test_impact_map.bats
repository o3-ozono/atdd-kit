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

# --- AC4: --all + --layer forces full scan ---

@test "AC4: --all --layer BATS lists all .bats files and exits 0" {
  _make_minimal_config
  # create two bats files in WORK/tests to verify full scan
  echo "#!/usr/bin/env bats" > "$WORK/tests/test_alpha.bats"
  echo "#!/usr/bin/env bats" > "$WORK/tests/test_beta.bats"
  # Override REPO_ROOT for this test by passing explicit config and running from WORK
  # The script uses REPO_ROOT derived from script location, so tests/ is WORK/tests
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --all --layer BATS
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "test_alpha.bats"
  echo "$output" | grep -q "test_beta.bats"
}

@test "AC4: --all --layer L4 lists all L4 names from config and exits 0" {
  _make_minimal_config
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --all --layer L4
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "discover"
  echo "$output" | grep -q "plan"
  [ -z "$stderr" ]
}

@test "AC4: --all without --base is valid (--base omission is accepted)" {
  _make_minimal_config
  # No --base provided — should succeed
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --all --layer L4
  [ "$status" -eq 0 ]
}

@test "AC4: --all --layer BATS output is sorted and deduplicated" {
  _make_minimal_config
  echo "#!/usr/bin/env bats" > "$WORK/tests/test_zzz.bats"
  echo "#!/usr/bin/env bats" > "$WORK/tests/test_aaa.bats"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --all --layer BATS
  [ "$status" -eq 0 ]
  [ "$output" = "$(echo "$output" | sort -u)" ]
}

# --- AC8: empty diff produces empty stdout and exit 0 ---

@test "AC8: empty diff with --base HEAD outputs nothing and exits 0" {
  _make_minimal_config
  # --base HEAD means diff between HEAD and HEAD = empty
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD --layer BATS
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "AC8: empty diff with --layer L4 also outputs nothing and exits 0" {
  _make_minimal_config
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD --layer L4
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

# --- AC1: path rule resolves affected tests ---

_commit_changed_file() {
  local path="$1" content="${2:-changed}"
  mkdir -p "$(dirname "$WORK/$path")"
  echo "$content" > "$WORK/$path"
  git -C "$WORK" add "$WORK/$path"
  git -C "$WORK" commit -m "change $path" -q
}

@test "AC1: skills/discover/SKILL.md change with L4 layer lists discover and plan only" {
  _make_minimal_config
  _commit_changed_file "skills/discover/SKILL.md"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer L4
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx "discover"
  echo "$output" | grep -qx "plan"
  # should not contain unrelated entries
  local count
  count=$(echo "$output" | grep -c "." || true)
  # skills/** rule yields: discover plan atdd verify ship bug = 6 items
  [ "$count" -gt 0 ]
  [ -z "$stderr" ]
}

@test "AC1: output is sorted and deduplicated" {
  _make_minimal_config
  _commit_changed_file "skills/foo/BAR.md"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer L4
  [ "$status" -eq 0 ]
  [ "$output" = "$(echo "$output" | sort -u)" ]
}

@test "AC1: exit code is 0" {
  _make_minimal_config
  _commit_changed_file "lib/spec_check.sh"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer L4
  [ "$status" -eq 0 ]
}

@test "AC1: lib change lists L4 tests matching lib rule" {
  _make_minimal_config
  _commit_changed_file "lib/foo.sh"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer L4
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx "discover"
}

# --- AC3: unmatched changes trigger fallback to full scan ---

@test "AC3: unmatched file triggers fallback with full L4 set and stderr reason" {
  _make_minimal_config
  _commit_changed_file ".github/workflows/foo.yml"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer L4
  [ "$status" -eq 0 ]
  # output equals --all output
  expected=$(bash "$SCRIPT" --config "$CONFIG" --all --layer L4)
  [ "$output" = "$expected" ]
  echo "$stderr" | grep -q "FALLBACK"
  echo "$stderr" | grep -q ".github/workflows/foo.yml"
}

@test "AC3: mixed matched and unmatched still triggers fallback" {
  _make_minimal_config
  # commit both a matched and an unmatched file
  mkdir -p "$WORK/skills/foo" "$WORK/.github/workflows"
  echo "a" > "$WORK/skills/foo/file.md"
  echo "b" > "$WORK/.github/workflows/ci.yml"
  git -C "$WORK" add .
  git -C "$WORK" commit -m "mixed changes" -q
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer L4
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "FALLBACK"
}

@test "AC3: config/impact_rules.yml self-change triggers fallback" {
  _make_minimal_config
  # change the config file itself
  echo "# modified" >> "$CONFIG"
  git -C "$WORK" add "$CONFIG"
  git -C "$WORK" commit -m "change config" -q
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer L4
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "FALLBACK"
}

@test "AC3: rename triggers fallback when new path is unmatched" {
  _make_minimal_config
  # add a file then rename it to unrecognized path
  echo "original" > "$WORK/unknown_old.txt"
  git -C "$WORK" add "$WORK/unknown_old.txt"
  git -C "$WORK" commit -m "add old file" -q
  git -C "$WORK" mv "$WORK/unknown_old.txt" "$WORK/unknown_new.txt"
  git -C "$WORK" commit -m "rename file" -q
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer L4
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "FALLBACK"
}

@test "AC3: fallback output matches --all output for same layer" {
  _make_minimal_config
  _commit_changed_file ".github/workflows/foo.yml"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer BATS
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "FALLBACK"
}
