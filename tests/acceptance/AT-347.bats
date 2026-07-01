#!/usr/bin/env bats
# @covers: scripts/impact_map.sh
# @covers: commands/setup-web.md
# @covers: commands/setup-ios.md
# @covers: addons/web/addon.yml
# @covers: addons/ios/addon.yml
# @covers: addons/README.md
# @covers: addons/web/README.md
# @covers: scripts/README.md
# @covers: DEVELOPMENT.md
# @covers: skills/merging-and-deploying/SKILL.md
# Acceptance Tests for Issue #347: impact_map / addon deploy の堅牢化（#323 レビュー由来の非ブロッキング所見対応）
# Corresponds to docs/issues/347-impact-map-addon-hardening/acceptance-tests.md

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
  WORK="${BATS_TMPDIR}/at347-$$"
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

_commit_changed_file() {
  local path="$1" content="${2:-changed}"
  mkdir -p "$(dirname "$WORK/$path")"
  printf '%s\n' "$content" > "$WORK/$path"
  git -C "$WORK" add "$WORK/$path"
  git -C "$WORK" commit -m "change $path" -q
}

# ---------------------------------------------------------------------------
# AT-347-1: parse_impact_rules の診断可能なエラー化（US-1）
# ---------------------------------------------------------------------------

@test "AT-347-1a: trailing-whitespace path glob is trimmed and fnmatch-matches" {
  # path: に末尾空白があっても glob として一致すること
  printf 'rules:\n  - path: src/**  \n    skill-e2e: unit\n' > "$CONFIG"
  git -C "$WORK" add "$CONFIG"
  git -C "$WORK" commit -m "add config" -q
  _commit_changed_file "src/app/main.ts"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --platform web --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx "unit"
  ! echo "$stderr" | grep -q "FALLBACK"
}

@test "AT-347-1b: trailing-whitespace 'rules: ' key is recognized as section start" {
  printf 'rules: \n  - path: src/**\n    skill-e2e: unit\n' > "$CONFIG"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --all --layer skill-e2e
  [ "$status" -eq 0 ]
  ! echo "$stderr" | grep -qi "missing 'rules:' section"
  echo "$output" | grep -qx "unit"
}

@test "AT-347-1c: misindented (4-space) '- path:' entries produce indentation-convention diagnostic, distinct from empty-rules error" {
  printf 'rules:\n    - path: src/**\n      skill-e2e: unit\n' > "$CONFIG"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --all --layer skill-e2e
  [ "$status" -ne 0 ]
  # must mention the 2-space indentation convention
  echo "$stderr" | grep -qiE "2.space|indent"
  # must NOT be conflated with the truly-empty-rules error
  ! echo "$stderr" | grep -q "no rules entries found"
}

@test "AT-347-1c-tab: misindented (tab) '- path:' entries produce indentation-convention diagnostic" {
  printf 'rules:\n\t- path: src/**\n\t  skill-e2e: unit\n' > "$CONFIG"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --all --layer skill-e2e
  [ "$status" -ne 0 ]
  echo "$stderr" | grep -qiE "2.space|indent"
  ! echo "$stderr" | grep -q "no rules entries found"
}

@test "AT-347-1: truly empty rules block still reports the distinguishable 'no rules entries found' error" {
  printf 'rules:\n' > "$CONFIG"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --all --layer skill-e2e
  [ "$status" -ne 0 ]
  echo "$stderr" | grep -q "no rules entries found"
}

@test "AT-347-1a-bats: trailing-whitespace bats: tag and skill-e2e: value are trimmed" {
  printf 'rules:\n  - path: src/**\n    skill-e2e: unit  \n    bats: "@covers src"  \n' > "$CONFIG"
  _commit_changed_file "src/app/main.ts"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  # no extra trailing whitespace in the emitted identifier
  [ "$output" = "unit" ]
}

# ---------------------------------------------------------------------------
# AT-347-2: --base 入力の fail-closed 検証（CS-1）
# ---------------------------------------------------------------------------

@test "AT-347-2a: --base starting with '-' (pickaxe-like short option) is rejected fail-closed" {
  printf 'rules:\n  - path: src/**\n    skill-e2e: unit\n' > "$CONFIG"
  git -C "$WORK" add "$CONFIG"
  git -C "$WORK" commit -m "add config" -q
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base -Spattern --layer skill-e2e
  [ "$status" -ne 0 ]
  echo "$stderr" | grep -qiE "invalid.*base|base.*invalid|base.*-"
  # must not silently succeed with empty output (CI-bypass-equivalent)
  [ -z "$output" ]
}

@test "AT-347-2b: --base '--output=<existing file>' adversarial value does not truncate the target file" {
  printf 'rules:\n  - path: src/**\n    skill-e2e: unit\n' > "$CONFIG"
  git -C "$WORK" add "$CONFIG"
  git -C "$WORK" commit -m "add config" -q
  local_target="$WORK/watched_file.txt"
  printf 'important content\n' > "$local_target"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG" --base "--output=$local_target" --layer skill-e2e
  [ "$status" -ne 0 ]
  # file must retain its original content (not truncated)
  [ "$(cat "$local_target")" = "important content" ]
}

# ---------------------------------------------------------------------------
# AT-347-3: setup-web / setup-ios 再実行時の config 上書き保護（US-2）
# ---------------------------------------------------------------------------

@test "AT-347-3a: setup-web.md documents existing-config detection, overwrite warning, and preservation" {
  SETUP_WEB="$REPO_ROOT/commands/setup-web.md"
  grep -qi "config/impact_rules.yml" "$SETUP_WEB"
  grep -qiE "already exists|既存|overwrite|上書き" "$SETUP_WEB"
  grep -qiE "skip|preserve|keep|保持" "$SETUP_WEB"
}

@test "AT-347-3b: setup-ios.md documents equivalent config protection and mentions loss prevention for required iOS customization" {
  SETUP_IOS="$REPO_ROOT/commands/setup-ios.md"
  grep -qi "config/impact_rules.yml" "$SETUP_IOS"
  grep -qiE "already exists|既存|overwrite|上書き" "$SETUP_IOS"
  grep -qiE "skip|preserve|keep|保持" "$SETUP_IOS"
}

# ---------------------------------------------------------------------------
# AT-347-4: addon.yml スキーマへの冪等保護フィールド予約（US-3）
# ---------------------------------------------------------------------------

@test "AT-347-4a: web and ios addon.yml declare if_not_exists / merge_strategy reserved fields in deploy context" {
  WEB_ADDON="$REPO_ROOT/addons/web/addon.yml"
  IOS_ADDON="$REPO_ROOT/addons/ios/addon.yml"
  grep -q "if_not_exists" "$WEB_ADDON"
  grep -q "merge_strategy" "$WEB_ADDON"
  grep -q "if_not_exists" "$IOS_ADDON"
  grep -q "merge_strategy" "$IOS_ADDON"
}

@test "AT-347-4b: addons/README.md addon.yml Schema table documents if_not_exists / merge_strategy as reserved" {
  README="$REPO_ROOT/addons/README.md"
  grep -q "if_not_exists" "$README"
  grep -q "merge_strategy" "$README"
  grep -qiE "reserved|future|予約|将来" "$README"
}

# ---------------------------------------------------------------------------
# AT-347-5: FALLBACK 検出手順・addon ドキュメントの整備（US-4）
# ---------------------------------------------------------------------------

@test "AT-347-5a: setup-web.md documents FALLBACK detection (stderr retention, grep FALLBACK, CI fail step)" {
  SETUP_WEB="$REPO_ROOT/commands/setup-web.md"
  grep -q "FALLBACK" "$SETUP_WEB"
  grep -q "grep FALLBACK" "$SETUP_WEB"
  grep -qiE "CI.*fail|fail.*CI" "$SETUP_WEB"
}

@test "AT-347-5b: addons/README.md has a Required / Optional column" {
  README="$REPO_ROOT/addons/README.md"
  grep -qi "Required" "$README"
  grep -qi "Optional" "$README"
}

@test "AT-347-5c: addons/web/README.md exists and documents deploy content and usage" {
  README="$REPO_ROOT/addons/web/README.md"
  [ -f "$README" ]
  grep -qi "impact_map" "$README"
}

@test "AT-347-5d: scripts/README.md documents the 4 scripts and --layer platform constraint" {
  README="$REPO_ROOT/scripts/README.md"
  grep -q "bats_runner.sh" "$README"
  grep -q "check_bats_covers.sh" "$README"
  grep -q "run-skill-e2e.sh" "$README"
  grep -q "test-skills-headless.sh" "$README"
  grep -qi -- "--layer" "$README"
  grep -qi "platform" "$README"
}

@test "AT-347-5e: DEVELOPMENT.md documents the mcp_servers Zero Dependencies carve-out" {
  DEV="$REPO_ROOT/DEVELOPMENT.md"
  grep -q "mcp_servers" "$DEV"
  grep -qiE "Zero Dependencies" "$DEV"
}

# ---------------------------------------------------------------------------
# AT-347-6: 重複実装の統合と AT の厳格化（US-5）
# ---------------------------------------------------------------------------

@test "AT-347-6a: select_web / select_ios are consolidated into select_path_rules_only" {
  SCRIPT_SRC="$REPO_ROOT/scripts/impact_map.sh"
  grep -q "select_path_rules_only" "$SCRIPT_SRC"
  ! grep -qE "^select_web\(\)|^select_ios\(\)" "$SCRIPT_SRC"
}

@test "AT-347-6b: web/ios classification is unchanged after consolidation (regression)" {
  printf 'rules:\n  - path: src/**\n    skill-e2e: unit integration\n' > "$CONFIG"
  git -C "$WORK" add "$CONFIG"
  git -C "$WORK" commit -m "add web config" -q
  _commit_changed_file "src/app/main.ts"
  run bash "$SCRIPT" --config "$CONFIG" --platform web --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  web_out="$output"

  CONFIG_IOS="$WORK/config/impact_rules_ios.yml"
  printf 'rules:\n  - path: Sources/**\n    skill-e2e: AppTests\n' > "$CONFIG_IOS"
  git -C "$WORK" add "$CONFIG_IOS"
  git -C "$WORK" commit -m "add ios config" -q
  _commit_changed_file "Sources/App/ViewController.swift"
  run bash "$SCRIPT" --config "$CONFIG_IOS" --platform ios --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  ios_out="$output"

  [ "$web_out" = "integration
unit" ]
  [ "$ios_out" = "AppTests" ]
}

@test "AT-347-6c: AT-323-004b is tightened to require --impact (--base alone no longer passes)" {
  AT323="$REPO_ROOT/tests/acceptance/AT-323.bats"
  start=$(grep -n 'AT-323-004b' "$AT323" | head -1 | cut -d: -f1)
  end=$((start + 5))
  block=$(sed -n "${start},${end}p" "$AT323")
  # must assert --impact
  echo "$block" | grep -qE -- "--impact"
  # must NOT be satisfiable via the loose --impact|--base alternation (the current
  # body is: grep -qE "\-\-impact|\-\-base" "$SKILL" — a literal alternation pipe)
  ! echo "$block" | grep -F -- '\-\-impact|\-\-base'
}

@test "AT-347-6d: AT-323-001b / AT-323-001c assert web/iOS identifier content, not just non-empty output" {
  AT323="$REPO_ROOT/tests/acceptance/AT-323.bats"
  start_b=$(grep -n 'AT-323-001b' "$AT323" | head -1 | cut -d: -f1)
  block_b=$(sed -n "${start_b},$((start_b + 6))p" "$AT323")
  start_c=$(grep -n 'AT-323-001c' "$AT323" | head -1 | cut -d: -f1)
  block_c=$(sed -n "${start_c},$((start_c + 6))p" "$AT323")
  echo "$block_b" | grep -qE "grep -q \"(unit|integration)\""
  echo "$block_c" | grep -qE "grep -q \"(AppTests|CoreTests)\""
}

@test "AT-347-6e: DEVELOPMENT.md 'Skill Changes Require Test Evidence' section records BATS evidence for SKILL.md files changed in this PR" {
  DEV="$REPO_ROOT/DEVELOPMENT.md"
  section=$(awk '/Skill Changes Require Test Evidence/{f=1} f{print} f&&/^## /&&!/Skill Changes/{exit}' "$DEV")
  echo "$section" | grep -q "merging-and-deploying"
}
