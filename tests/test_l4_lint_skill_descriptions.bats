#!/usr/bin/env bats
# test_l4_lint_skill_descriptions.bats -- AC4: description anti-pattern linter

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LINTER="${REPO_ROOT}/scripts/lint_skill_descriptions.sh"
GOOD_FIXTURE="${REPO_ROOT}/tests/fixtures/claude-code/lint_skill_descriptions/good"
BAD_FIXTURE="${REPO_ROOT}/tests/fixtures/claude-code/lint_skill_descriptions/bad"

@test "linter script exists and is executable" {
  [ -x "$LINTER" ]
}

@test "linter exits 0 in warn-only mode" {
  run bash "$LINTER"
  [ "$status" -eq 0 ]
}

@test "linter outputs OK for good fixture description" {
  run bash "$LINTER" --dir "$GOOD_FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
  [[ "$output" != *"VIOLATION"* ]]
}

@test "linter outputs VIOLATION for step-chain bad fixture" {
  run bash "$LINTER" --dir "$BAD_FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VIOLATION"* ]]
}

@test "linter outputs path: reason format for violations" {
  run bash "$LINTER" --dir "$BAD_FIXTURE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "VIOLATION".*"SKILL.md" ]]
}

@test "linter detects step-chain keyword (then)" {
  tmp_dir=$(mktemp -d)
  cat > "$tmp_dir/SKILL.md" <<'EOF'
---
name: test-skill
description: "Creates tests, then writes implementation, then ships"
---
EOF
  run bash "$LINTER" --dir "$tmp_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VIOLATION"* ]]
  rm -rf "$tmp_dir"
}

@test "linter detects description length > 200 chars" {
  tmp_dir=$(mktemp -d)
  long_desc="Use when you need to do something very specific that requires a long description because it summarizes the entire workflow process in great detail and exceeds the allowed character limit for trigger conditions"
  cat > "$tmp_dir/SKILL.md" <<EOF
---
name: test-skill
description: "$long_desc"
---
EOF
  run bash "$LINTER" --dir "$tmp_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VIOLATION"* ]]
  rm -rf "$tmp_dir"
}

@test "linter detects dash-separated verb list pattern" {
  tmp_dir=$(mktemp -d)
  cat > "$tmp_dir/SKILL.md" <<'EOF'
---
name: test-skill
description: "Session report -- git status, PR/CI, Issue list, recommended tasks"
---
EOF
  run bash "$LINTER" --dir "$tmp_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VIOLATION"* ]]
  rm -rf "$tmp_dir"
}

@test "linter skips non-SKILL.md files" {
  tmp_dir=$(mktemp -d)
  cat > "$tmp_dir/README.md" <<'EOF'
This is not a skill file.
EOF
  run bash "$LINTER" --dir "$tmp_dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"VIOLATION"* ]]
  rm -rf "$tmp_dir"
}
