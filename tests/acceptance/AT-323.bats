#!/usr/bin/env bats
# @covers: scripts/impact_map.sh
# @covers: addons/web
# @covers: addons/ios
# @covers: skills/running-atdd-cycle
# @covers: skills/merging-and-deploying
# @covers: docs/methodology/test-execution-policy.md
# Acceptance Tests for Issue #323: impact_map.sh platform adapter generalization + addon deploy + flow-skill wiring
# Corresponds to docs/issues/323-impact-based-test-selection-for-consumers/acceptance-tests.md

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
  WORK="${BATS_TMPDIR}/at323-$$"
  mkdir -p "$WORK/config" "$WORK/scripts" "$WORK/tests"
  git -C "$WORK" init -b main -q
  git -C "$WORK" config user.email "test@example.com"
  git -C "$WORK" config user.name "Test"
  git -C "$WORK" commit --allow-empty -m "base" -q
  cp "$REPO_ROOT/scripts/impact_map.sh" "$WORK/scripts/"
  SCRIPT="$WORK/scripts/impact_map.sh"
  CONFIG_OTHER="$WORK/config/impact_rules_other.yml"
  CONFIG_WEB="$WORK/config/impact_rules_web.yml"
  CONFIG_IOS="$WORK/config/impact_rules_ios.yml"
}

teardown() {
  rm -rf "$WORK" || true
}

_make_other_config() {
  cat > "$CONFIG_OTHER" <<'EOF'
rules:
  - path: skills/**
    skill-e2e: discover plan atdd verify ship
    bats: "@covers skills"
  - path: scripts/**
    skill-e2e: discover plan
    bats: "@covers scripts"
EOF
  git -C "$WORK" add "$CONFIG_OTHER"
  git -C "$WORK" commit -m "add other config" -q
}

_make_web_config() {
  cp "$REPO_ROOT/addons/web/config/impact_rules.yml" "$CONFIG_WEB"
  git -C "$WORK" add "$CONFIG_WEB"
  git -C "$WORK" commit -m "add web config" -q
}

_make_ios_config() {
  cp "$REPO_ROOT/addons/ios/config/impact_rules.yml" "$CONFIG_IOS"
  git -C "$WORK" add "$CONFIG_IOS"
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
# AT-001: platform adapter generalization
# Given: --platform {web|ios|other} implemented, platform-specific impact_rules.yml given
# When:  same changed-path set is run with --platform web / ios / other
# Then:  each platform returns identifiers via common contract (stdout 1 item per line)
# ---------------------------------------------------------------------------

@test "AT-323-001a: --platform other produces same output as omitting --platform (non-breaking)" {
  _make_other_config
  _commit_changed_file "skills/foo/SKILL.md"
  run bash "$SCRIPT" --config "$CONFIG_OTHER" --platform other --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  local out_with="$output"
  run bash "$SCRIPT" --config "$CONFIG_OTHER" --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  [ "$output" = "$out_with" ]
}

@test "AT-323-001b: --platform web with src/ change returns web test identifiers" {
  _make_web_config
  _commit_changed_file "src/app/main.ts"
  run bash "$SCRIPT" --config "$CONFIG_WEB" --platform web --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  # content assert (#347): not merely non-empty — must contain the expected
  # identifiers declared by the web template's src/** rule.
  echo "$output" | grep -q "unit"
  echo "$output" | grep -q "integration"
}

@test "AT-323-001c: --platform ios with Sources/*.swift change returns iOS test target identifiers" {
  _make_ios_config
  _commit_changed_file "Sources/App/ViewController.swift"
  run bash "$SCRIPT" --config "$CONFIG_IOS" --platform ios --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  # content assert (#347): not merely non-empty — must contain the expected
  # identifier declared by the ios template's Sources/** rule.
  echo "$output" | grep -q "AppTests"
}

@test "AT-323-001d: unknown --platform value exits non-zero with platform error on stderr" {
  _make_other_config
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG_OTHER" --platform unknown --base HEAD~1 --layer skill-e2e
  [ "$status" -ne 0 ]
  echo "$stderr" | grep -qi "platform"
}

# ---------------------------------------------------------------------------
# AT-002: platform-specific impact_rules.yml template distribution
# Given: addons/web/config/impact_rules.yml and addons/ios/config/impact_rules.yml exist
# When:  loaded with --config <tmpl> --all
# Then:  exits 0 without parse errors
# ---------------------------------------------------------------------------

@test "AT-323-002a: addons/web/config/impact_rules.yml template parses and exits 0 under --all" {
  WEB_TMPL="$REPO_ROOT/addons/web/config/impact_rules.yml"
  [ -f "$WEB_TMPL" ]
  run bash "$SCRIPT" --config "$WEB_TMPL" --all --layer skill-e2e
  [ "$status" -eq 0 ]
}

@test "AT-323-002b: addons/ios/config/impact_rules.yml template parses and exits 0 under --all" {
  IOS_TMPL="$REPO_ROOT/addons/ios/config/impact_rules.yml"
  [ -f "$IOS_TMPL" ]
  run bash "$SCRIPT" --config "$IOS_TMPL" --all --layer skill-e2e
  [ "$status" -eq 0 ]
}

@test "AT-323-002c: web template contains src/ path rules (web project structure)" {
  WEB_TMPL="$REPO_ROOT/addons/web/config/impact_rules.yml"
  grep -q "src/" "$WEB_TMPL"
}

@test "AT-323-002d: ios template contains Sources/ or Tests/ path rules (iOS project structure)" {
  IOS_TMPL="$REPO_ROOT/addons/ios/config/impact_rules.yml"
  grep -qE "Sources/|Tests/" "$IOS_TMPL"
}

# ---------------------------------------------------------------------------
# AT-003: addon distribution and setup wiring
# Given: addons/web/addon.yml (new) and addons/ios/addon.yml (updated) with deploy: entries
# When:  addon.yml deploy entries and setup command descriptions are cross-checked
# Then:  required schema fields satisfied, deploy entries consistent
# ---------------------------------------------------------------------------

@test "AT-323-003a: addons/web/addon.yml has required schema fields (name / display_name / deploy / detect)" {
  WEB_ADDON="$REPO_ROOT/addons/web/addon.yml"
  [ -f "$WEB_ADDON" ]
  grep -q "^name:" "$WEB_ADDON"
  grep -q "^display_name:" "$WEB_ADDON"
  grep -q "^deploy:" "$WEB_ADDON"
  grep -q "^detect:" "$WEB_ADDON"
}

@test "AT-323-003b: addons/web/addon.yml deploy block declares impact runner + rules with src/dest" {
  WEB_ADDON="$REPO_ROOT/addons/web/addon.yml"
  # Scope the assertion to the deploy: block (up to the next top-level key) so a
  # stray mention in guidance cannot satisfy it — a deleted deploy entry fails.
  deploy_block=$(awk '/^deploy:/{f=1;next} /^[a-zA-Z]/{f=0} f' "$WEB_ADDON")
  [ -n "$deploy_block" ]
  # src is addon-relative (resolved against addons/web/); impact_map.sh is the
  # shared top-level script (../../scripts/), impact_rules.yml is config/.
  echo "$deploy_block" | grep -qE "src:[[:space:]]*\.\./\.\./scripts/impact_map\.sh"
  echo "$deploy_block" | grep -qE "dest:[[:space:]]*scripts/impact_map\.sh"
  echo "$deploy_block" | grep -qE "src:[[:space:]]*config/impact_rules\.yml"
  echo "$deploy_block" | grep -qE "dest:[[:space:]]*config/impact_rules\.yml"
}

@test "AT-323-003c: addons/ios/addon.yml deploy block declares impact runner + rules with src/dest" {
  IOS_ADDON="$REPO_ROOT/addons/ios/addon.yml"
  deploy_block=$(awk '/^deploy:/{f=1;next} /^[a-zA-Z]/{f=0} f' "$IOS_ADDON")
  [ -n "$deploy_block" ]
  # src is addon-relative (resolved against addons/ios/); impact_map.sh is the
  # shared top-level script (../../scripts/), impact_rules.yml is config/.
  echo "$deploy_block" | grep -qE "src:[[:space:]]*\.\./\.\./scripts/impact_map\.sh"
  echo "$deploy_block" | grep -qE "dest:[[:space:]]*scripts/impact_map\.sh"
  echo "$deploy_block" | grep -qE "src:[[:space:]]*config/impact_rules\.yml"
  echo "$deploy_block" | grep -qE "dest:[[:space:]]*config/impact_rules\.yml"
}

@test "AT-323-003d: commands/setup-web.md no longer contains placeholder text" {
  SETUP_WEB="$REPO_ROOT/commands/setup-web.md"
  ! grep -qi "placeholder" "$SETUP_WEB"
  ! grep -qi "not yet available" "$SETUP_WEB"
}

@test "AT-323-003e: commands/setup-ios.md Deploy Scripts table includes impact runner row" {
  SETUP_IOS="$REPO_ROOT/commands/setup-ios.md"
  grep -q "impact_map" "$SETUP_IOS"
}

# ---------------------------------------------------------------------------
# AT-004: flow skills default to impact-scope test execution
# Given: running-atdd-cycle / autopilot AT gate / merging-and-deploying exist
# When:  test execution commands in each skill are checked
# Then:  inner loop and post-deploy regression default to --impact
# ---------------------------------------------------------------------------

@test "AT-323-004a: running-atdd-cycle SKILL.md references --impact execution path" {
  SKILL="$REPO_ROOT/skills/running-atdd-cycle/SKILL.md"
  grep -qE "\-\-impact" "$SKILL"
}

@test "AT-323-004b: merging-and-deploying SKILL.md post-deploy section references --impact (#347: --base alone no longer satisfies this)" {
  SKILL="$REPO_ROOT/skills/merging-and-deploying/SKILL.md"
  grep -qE -- "--impact" "$SKILL"
}

@test "AT-323-004c: autopilot SKILL.md documents AT_COMMAND should use impact-scope command (--impact)" {
  # AT_COMMAND は caller-provided だが、autopilot は impact-scope コマンドを推奨例として文書化する必要がある
  # (PRD Non-Goal: CI YAML の自動改変なし; 設計「ゲートはフル」との非対称はコメントで明示)
  SKILL="$REPO_ROOT/skills/autopilot/SKILL.md"
  grep -qE "\-\-impact|impact.scope|impact-scope" "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-005: "run narrow / gate full" principle in methodology docs
# Given: docs/methodology/test-execution-policy.md exists
# When:  document is read
# Then:  #323 completion reflected, "owned by #323" pending text removed
# ---------------------------------------------------------------------------

@test "AT-323-005a: test-execution-policy.md no longer contains 'owned by #323' or 'out of scope here' pending text" {
  POLICY="$REPO_ROOT/docs/methodology/test-execution-policy.md"
  ! grep -q "owned by.*#323\|out of scope here.*#323\|is owned by Issue #323" "$POLICY"
}

@test "AT-323-005b: test-execution-policy.md describes platform-agnostic principle (web/ios/platform)" {
  POLICY="$REPO_ROOT/docs/methodology/test-execution-policy.md"
  grep -qiE "web|ios|platform" "$POLICY"
}

# ---------------------------------------------------------------------------
# AT-006: other (atdd-kit itself) non-breaking preservation
# Given: adapter-separated impact_map.sh
# When:  --platform other and no --platform for --all / --base <ref>
# Then:  output is equivalent; atdd-kit's own test selection is unbroken
# ---------------------------------------------------------------------------

@test "AT-323-006a: --all --layer BATS with --platform other equals output with no --platform" {
  _make_other_config
  mkdir -p "$WORK/tests"
  echo "#!/usr/bin/env bats" > "$WORK/tests/test_alpha.bats"
  echo "#!/usr/bin/env bats" > "$WORK/tests/test_beta.bats"
  run bash "$SCRIPT" --config "$CONFIG_OTHER" --platform other --all --layer BATS
  [ "$status" -eq 0 ]
  local out_with="$output"
  run bash "$SCRIPT" --config "$CONFIG_OTHER" --all --layer BATS
  [ "$status" -eq 0 ]
  [ "$output" = "$out_with" ]
}

@test "AT-323-006b: --platform other with scripts/** change returns bats file with @covers scripts" {
  _make_other_config
  mkdir -p "$WORK/tests"
  {
    echo "#!/usr/bin/env bats"
    echo "# @covers: scripts"
    echo "@test \"x\" { true; }"
  } > "$WORK/tests/test_scripts.bats"
  _commit_changed_file "scripts/foo.sh"
  run bash "$SCRIPT" --config "$CONFIG_OTHER" --platform other --base HEAD~1 --layer BATS
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "test_scripts.bats"
}

# ---------------------------------------------------------------------------
# AT-007: full suite enforced at merge/CI gate
# Given: merging-and-deploying and autopilot merge-gate execution paths
# When:  merge-gate test execution command is checked
# Then:  --all (full suite) is enforced; not narrowed to impact scope
# ---------------------------------------------------------------------------

@test "AT-323-007: merging-and-deploying SKILL.md merge gate explicitly uses --all" {
  SKILL="$REPO_ROOT/skills/merging-and-deploying/SKILL.md"
  grep -qE "run-tests\.sh.*--all|--all.*pre-merge|pre-merge.*--all" "$SKILL"
}

# ---------------------------------------------------------------------------
# AT-008: unmatched path falls back to full execution (all platforms)
# Given: changed path matches no rule in any platform's impact_rules.yml
# When:  run with --platform web / ios / other
# Then:  full test set output and exit 0 (conservative fallback maintained)
# ---------------------------------------------------------------------------

@test "AT-323-008a: --platform web with unmatched path triggers fallback (exit 0)" {
  _make_web_config
  _commit_changed_file "completely/unknown/path/file.xyz"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG_WEB" --platform web --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "FALLBACK"
  # Conservative fallback contract: full test set output (not zero output).
  expected=$(bash "$SCRIPT" --config "$CONFIG_WEB" --all --layer skill-e2e)
  [ -n "$output" ]
  [ "$output" = "$expected" ]
}

@test "AT-323-008b: --platform ios with unmatched path triggers fallback (exit 0)" {
  _make_ios_config
  _commit_changed_file "completely/unknown/path/file.xyz"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG_IOS" --platform ios --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "FALLBACK"
  expected=$(bash "$SCRIPT" --config "$CONFIG_IOS" --all --layer skill-e2e)
  [ -n "$output" ]
  [ "$output" = "$expected" ]
}

@test "AT-323-008c: --platform other with unmatched path triggers fallback (exit 0)" {
  _make_other_config
  _commit_changed_file "completely/unknown/path/file.xyz"
  run --separate-stderr bash "$SCRIPT" --config "$CONFIG_OTHER" --platform other --base HEAD~1 --layer skill-e2e
  [ "$status" -eq 0 ]
  echo "$stderr" | grep -q "FALLBACK"
  expected=$(bash "$SCRIPT" --config "$CONFIG_OTHER" --all --layer skill-e2e)
  [ -n "$output" ]
  [ "$output" = "$expected" ]
}

# ---------------------------------------------------------------------------
# AT-009: version / CHANGELOG consistency (regression invariant)
# Given: plugin.json version and CHANGELOG.md topmost release heading
# When:  both are compared
# Then:  they match (invariant — not pinned to a specific version string)
# ---------------------------------------------------------------------------

@test "AT-323-009: plugin.json version matches CHANGELOG.md topmost release heading" {
  PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
  CHANGELOG="$REPO_ROOT/CHANGELOG.md"
  version=$(grep '"version"' "$PLUGIN_JSON" | sed 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/')
  changelog_version=$(grep -m1 '^## \[[0-9]' "$CHANGELOG" | sed 's/## \[\([^]]*\)\].*/\1/')
  [ "$version" = "$changelog_version" ]
}
