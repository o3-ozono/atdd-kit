#!/usr/bin/env bats
# @covers: scripts/impact_map.sh
# Issue #323: platform adapter tests for impact_map.sh (other non-breaking / web / ios / unmatched fallback)

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  WORK="${BATS_TMPDIR}/impact-platform-$$"
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
    skill-e2e: discover plan atdd verify ship
    bats: "@covers skills"
  - path: scripts/**
    skill-e2e: discover plan
    bats: "@covers scripts"
EOF
  git -C "$WORK" add "$CONFIG"
  git -C "$WORK" commit -m "add config" -q
}

_make_web_config() {
  cat > "$CONFIG" <<'EOF'
rules:
  - path: src/**
    skill-e2e: unit integration e2e
  - path: components/**
    skill-e2e: unit integration
  - path: tests/**
    skill-e2e: unit
EOF
  git -C "$WORK" add "$CONFIG"
  git -C "$WORK" commit -m "add web config" -q
}

_make_ios_config() {
  cat > "$CONFIG" <<'EOF'
rules:
  - path: Sources/**
    skill-e2e: AppTests
  - path: Tests/**
    skill-e2e: AppTests
  - path: UITests/**
    skill-e2e: AppUITests
EOF
  git -C "$WORK" add "$CONFIG"
  git -C "$WORK" commit -m "add ios config" -q
}

_commit_changed_file() {
  local path="$1" content="${2:-changed}"
  mkdir -p "$(dirname "$WORK/$path")"
  printf '%s\n' "$content" > "$WORK/$path"
  git -C "$WORK" add "$WORK/$path"
  git -C "$WORK" commit -m "change $path" -q
}

# ---------------------------------------------------------------------------
# Platform option validation
# ---------------------------------------------------------------------------

@test "platform: --platform other is accepted (exit 0 on valid config + --all)" {
  _make_minimal_config
  run bash "$SCRIPT" --config "$CONFIG" --platform other --all --layer skill-e2e
  [ "$status" -eq 0 ]
}

@test "platform: --platform web is accepted (exit 0 on valid config + --all)" {
  _make_web_config
  run bash "$SCRIPT" --config "$CONFIG" --platform web --all --layer skill-e2e
  [ "$status" -eq 0 ]
}

@test "platform: --platform ios is accepted (exit 0 on valid config + --all)" {
  _make_ios_config
  run bash "$SCRIPT" --config "$CONFIG" --platform ios --all --layer skill-e2e
  [ "$status" -eq 0 ]
}

@test "platform: unknown --platform value exits non-zero with error on stderr" {
  _make_minimal_config
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --platform unknown --base HEAD --layer skill-e2e
  [ "$status" -ne 0 ]
  echo "$stderr" | grep -qi "platform"
}

@test "platform: omitting --platform defaults to other behavior" {
  _make_minimal_config
  _commit_changed_file "skills/foo/SKILL.md"
  run bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "discover"
}

# ---------------------------------------------------------------------------
# other platform: non-breaking preservation of bats/@covers
# ---------------------------------------------------------------------------

@test "other: --platform other --all --layer BATS matches --platform-omitted output" {
  _make_minimal_config
  echo "#!/usr/bin/env bats" > "$WORK/tests/test_alpha.bats"
  echo "#!/usr/bin/env bats" > "$WORK/tests/test_beta.bats"
  run bash "$SCRIPT" --config "$CONFIG" --platform other --all --layer BATS
  [ "$status" -eq 0 ]
  out_with="$output"
  run bash "$SCRIPT" --config "$CONFIG" --all --layer BATS
  [ "$status" -eq 0 ]
  [ "$output" = "$out_with" ]
}

@test "other: --platform other selects skill tests from path rules" {
  _make_minimal_config
  _commit_changed_file "skills/atdd/SKILL.md"
  run bash "$SCRIPT" --config "$CONFIG" --platform other --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "discover"
}

@test "other: --platform other selects bats via @covers scan" {
  _make_minimal_config
  {
    echo "#!/usr/bin/env bats"
    echo "# @covers: scripts"
    echo "@test \"x\" { true; }"
  } > "$WORK/tests/test_scripts.bats"
  _commit_changed_file "scripts/run.sh"
  run bash "$SCRIPT" --config "$CONFIG" --platform other --base HEAD~1 --layer BATS
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "test_scripts.bats"
}

# ---------------------------------------------------------------------------
# web platform: src/** glob → skill-e2e identifiers
# ---------------------------------------------------------------------------

@test "web: src/ change returns matching skill-e2e identifiers" {
  _make_web_config
  _commit_changed_file "src/app/index.ts"
  run bash "$SCRIPT" --config "$CONFIG" --platform web --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "unit"
  echo "$output" | grep -q "integration"
}

@test "web: components/ change returns matching identifiers" {
  _make_web_config
  _commit_changed_file "components/Button.tsx"
  run bash "$SCRIPT" --config "$CONFIG" --platform web --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "web: output is sorted and deduplicated" {
  _make_web_config
  # Both src/ and components/ changes — stage only the new files (not scripts/)
  mkdir -p "$WORK/src/app" "$WORK/components"
  printf 'a\n' > "$WORK/src/app/a.ts"
  printf 'b\n' > "$WORK/components/B.tsx"
  git -C "$WORK" add "$WORK/src/app/a.ts" "$WORK/components/B.tsx"
  git -C "$WORK" commit -m "change src and components" -q
  run bash "$SCRIPT" --config "$CONFIG" --platform web --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  [ "$output" = "$(echo "$output" | sort -u)" ]
}

# ---------------------------------------------------------------------------
# ios platform: Sources/*.swift → skill-e2e targets
# ---------------------------------------------------------------------------

@test "ios: Sources/ change returns matching XCTest target identifiers" {
  _make_ios_config
  _commit_changed_file "Sources/App/ViewController.swift"
  run bash "$SCRIPT" --config "$CONFIG" --platform ios --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "AppTests"
}

@test "ios: UITests/ change returns UI test target" {
  _make_ios_config
  _commit_changed_file "UITests/AppUITests.swift"
  run bash "$SCRIPT" --config "$CONFIG" --platform ios --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "AppUITests"
}

# ---------------------------------------------------------------------------
# Unmatched path: full-scan fallback for all platforms
# ---------------------------------------------------------------------------

@test "unmatched/other: unrecognized path triggers FALLBACK and full scan (exit 0)" {
  _make_minimal_config
  _commit_changed_file ".github/workflows/ci.yml"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --platform other --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "FALLBACK"
  # FALLBACK diagnostic names the config and platform so a consumer can tell
  # an intentional unmapped path apart from a misconfigured impact_rules.yml.
  echo "$stderr" | grep -q "impact_rules.yml"
  echo "$stderr" | grep -q "other"
  # Conservative fallback contract: output equals the FULL suite (not zero output).
  expected=$(bash "$SCRIPT" --config "$CONFIG" --all --layer skill-e2e)
  [ -n "$output" ]
  [ "$output" = "$expected" ]
}

@test "unmatched/web: unrecognized path triggers FALLBACK and full scan (exit 0)" {
  _make_web_config
  _commit_changed_file ".github/workflows/ci.yml"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --platform web --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "FALLBACK"
  echo "$stderr" | grep -q "impact_rules.yml"
  echo "$stderr" | grep -q "web"
  # Conservative fallback contract: output equals the FULL suite (not zero output).
  expected=$(bash "$SCRIPT" --config "$CONFIG" --platform web --all --layer skill-e2e)
  [ -n "$output" ]
  [ "$output" = "$expected" ]
}

@test "unmatched/ios: unrecognized path triggers FALLBACK and full scan (exit 0)" {
  _make_ios_config
  _commit_changed_file ".github/workflows/ci.yml"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --platform ios --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "FALLBACK"
  echo "$stderr" | grep -q "impact_rules.yml"
  echo "$stderr" | grep -q "ios"
  # Conservative fallback contract: output equals the FULL suite (not zero output).
  expected=$(bash "$SCRIPT" --config "$CONFIG" --platform ios --all --layer skill-e2e)
  [ -n "$output" ]
  [ "$output" = "$expected" ]
}
