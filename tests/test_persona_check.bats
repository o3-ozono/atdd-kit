#!/usr/bin/env bats
# Issue #108: persona_check.sh — single source of truth for valid persona detection
# AC5 boundary cases covered: README/TEMPLATE excluded, hidden files, subdir,
# empty .md, placeholder unchanged, symlink follow.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/lib/persona_check.sh"

setup() {
  export PERSONAS_DIR="$BATS_TEST_TMPDIR/personas"
  mkdir -p "$PERSONAS_DIR"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR/personas"
}

# Build a valid persona file — Name header and a non-placeholder frontmatter-style first line
_make_valid_persona() {
  local path="$1" name="${2:-Kenji Tanaka}"
  cat > "$path" <<EOF
# $name

## Role / Job Title

Senior Data Analyst at a mid-size logistics company.

## Goals

### Primary Goal

Load exported CSVs into Excel dashboards without manual cleanup.

### Secondary Goal

Share dashboards with non-technical stakeholders.

## Context

| Dimension | Detail |
|-----------|--------|
| Technical level | Intermediate |
| Environment | Desktop, corporate network |
| Constraints | Time-pressed, no admin rights |

## Quote

> "I just need the data in a format Excel can open."
EOF
}

# =============================================================================
# count_valid_personas
# =============================================================================

@test "count_valid_personas: missing directory returns 0 and exit 0" {
  rm -rf "$PERSONAS_DIR"
  run bash "$SCRIPT" count_valid_personas "$PERSONAS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "count_valid_personas: README.md and TEMPLATE.md only returns 0" {
  cat "$REPO_ROOT/docs/personas/README.md" > "$PERSONAS_DIR/README.md"
  cat "$REPO_ROOT/docs/personas/TEMPLATE.md" > "$PERSONAS_DIR/TEMPLATE.md"
  run bash "$SCRIPT" count_valid_personas "$PERSONAS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "count_valid_personas: single valid persona returns 1" {
  _make_valid_persona "$PERSONAS_DIR/kenji-analyst.md"
  run bash "$SCRIPT" count_valid_personas "$PERSONAS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "count_valid_personas: multiple valid personas returns count" {
  _make_valid_persona "$PERSONAS_DIR/kenji-analyst.md" "Kenji"
  _make_valid_persona "$PERSONAS_DIR/sarah-manager.md" "Sarah"
  run bash "$SCRIPT" count_valid_personas "$PERSONAS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "count_valid_personas: hidden files are excluded" {
  _make_valid_persona "$PERSONAS_DIR/.hidden.md" "Hidden"
  touch "$PERSONAS_DIR/.DS_Store"
  run bash "$SCRIPT" count_valid_personas "$PERSONAS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "count_valid_personas: subdirectory .md files are excluded" {
  mkdir -p "$PERSONAS_DIR/sub"
  _make_valid_persona "$PERSONAS_DIR/sub/nested.md" "Nested"
  run bash "$SCRIPT" count_valid_personas "$PERSONAS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "count_valid_personas: empty .md file is invalid" {
  touch "$PERSONAS_DIR/empty.md"
  run bash "$SCRIPT" count_valid_personas "$PERSONAS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "count_valid_personas: TEMPLATE placeholder unchanged is invalid" {
  # Copy TEMPLATE.md content but rename to a persona-like filename
  cp "$REPO_ROOT/docs/personas/TEMPLATE.md" "$PERSONAS_DIR/bob.md"
  run bash "$SCRIPT" count_valid_personas "$PERSONAS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "count_valid_personas: symlink to valid persona is followed" {
  _make_valid_persona "$BATS_TEST_TMPDIR/target.md" "Linked"
  ln -s "$BATS_TEST_TMPDIR/target.md" "$PERSONAS_DIR/linked.md"
  run bash "$SCRIPT" count_valid_personas "$PERSONAS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "count_valid_personas: mix of valid + malformed returns only valid count" {
  _make_valid_persona "$PERSONAS_DIR/kenji-analyst.md" "Kenji"
  cp "$REPO_ROOT/docs/personas/TEMPLATE.md" "$PERSONAS_DIR/placeholder.md"
  touch "$PERSONAS_DIR/empty.md"
  mkdir -p "$PERSONAS_DIR/sub"
  _make_valid_persona "$PERSONAS_DIR/sub/nested.md" "Nested"
  cat "$REPO_ROOT/docs/personas/README.md" > "$PERSONAS_DIR/README.md"
  run bash "$SCRIPT" count_valid_personas "$PERSONAS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# =============================================================================
# is_valid_persona
# =============================================================================

@test "is_valid_persona: valid persona returns 0" {
  _make_valid_persona "$PERSONAS_DIR/kenji-analyst.md"
  run bash "$SCRIPT" is_valid_persona "$PERSONAS_DIR/kenji-analyst.md"
  [ "$status" -eq 0 ]
}

@test "is_valid_persona: README.md returns non-zero" {
  cat "$REPO_ROOT/docs/personas/README.md" > "$PERSONAS_DIR/README.md"
  run bash "$SCRIPT" is_valid_persona "$PERSONAS_DIR/README.md"
  [ "$status" -ne 0 ]
}

@test "is_valid_persona: TEMPLATE.md returns non-zero" {
  cat "$REPO_ROOT/docs/personas/TEMPLATE.md" > "$PERSONAS_DIR/TEMPLATE.md"
  run bash "$SCRIPT" is_valid_persona "$PERSONAS_DIR/TEMPLATE.md"
  [ "$status" -ne 0 ]
}

@test "is_valid_persona: empty file returns non-zero" {
  touch "$PERSONAS_DIR/empty.md"
  run bash "$SCRIPT" is_valid_persona "$PERSONAS_DIR/empty.md"
  [ "$status" -ne 0 ]
}

@test "is_valid_persona: file with TEMPLATE placeholder returns non-zero" {
  cp "$REPO_ROOT/docs/personas/TEMPLATE.md" "$PERSONAS_DIR/bob.md"
  run bash "$SCRIPT" is_valid_persona "$PERSONAS_DIR/bob.md"
  [ "$status" -ne 0 ]
}

@test "is_valid_persona: nonexistent file returns non-zero" {
  run bash "$SCRIPT" is_valid_persona "$PERSONAS_DIR/no-such.md"
  [ "$status" -ne 0 ]
}

# =============================================================================
# get_persona_guidance_message
# =============================================================================

@test "get_persona_guidance_message: references persona-guide.md" {
  run bash "$SCRIPT" get_persona_guidance_message
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'docs/methodology/persona-guide.md'
}

@test "get_persona_guidance_message: references Anti-Pattern 1 and 2" {
  run bash "$SCRIPT" get_persona_guidance_message
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi 'Anti-Pattern 1'
  echo "$output" | grep -qi 'Anti-Pattern 2'
}

@test "get_persona_guidance_message: instructs to create persona before autopilot" {
  run bash "$SCRIPT" get_persona_guidance_message
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi 'docs/personas/'
  echo "$output" | grep -qi 'before running autopilot'
}

# =============================================================================
# Dispatcher
# =============================================================================

@test "dispatcher: unknown subcommand exits non-zero with usage" {
  run bash "$SCRIPT" nonexistent_subcommand
  [ "$status" -ne 0 ]
}

@test "dispatcher: no argument exits non-zero with usage" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}
