#!/usr/bin/env bats
# @covers: lib/spec_check.sh
# Issue #70 AC4/AC5: spec_check.sh — single source of truth for spec file detection and slug derivation.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/lib/spec_check.sh"

setup() {
  export SPECS_DIR="$BATS_TEST_TMPDIR/specs"
  mkdir -p "$SPECS_DIR"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR/specs"
}

_make_spec() {
  local path="$1" status="${2:-approved}"
  cat > "$path" <<EOF
---
title: "Sample spec"
issue: "#999"
status: $status
---

## User Story

**I want to** do X,
**so that** Y.

## Acceptance Criteria

### AC1: first

- **Given:** a
- **When:** b
- **Then:** c

### AC2: second

- **Given:** a
- **When:** b
- **Then:** c

### AC3: third

- **Given:** a
- **When:** b
- **Then:** c
EOF
}

# =============================================================================
# derive_slug — EN / JA Issue title
# =============================================================================

@test "derive_slug: EN title lowercases and kebab-cases main noun phrase" {
  export GH_CMD_OVERRIDE='echo Add login rate limiting'
  run bash "$SCRIPT" derive_slug 123
  [ "$status" -eq 0 ]
  [ "$output" = "add-login-rate-limiting" ]
}

@test "derive_slug: EN title strips conventional commit prefix" {
  export GH_CMD_OVERRIDE='echo feat: LLM US/AC auto-reference mechanism'
  run bash "$SCRIPT" derive_slug 70
  [ "$status" -eq 0 ]
  [ "$output" = "llm-us-ac-auto-reference-mechanism" ]
}

@test "derive_slug: JA title requires manual override via env" {
  export GH_CMD_OVERRIDE='echo 日本語のタイトル例'
  export SPEC_SLUG_OVERRIDE=japanese-title-sample
  run bash "$SCRIPT" derive_slug 456
  [ "$status" -eq 0 ]
  [ "$output" = "japanese-title-sample" ]
}

@test "derive_slug: JA title without override exits non-zero with guidance" {
  export GH_CMD_OVERRIDE='echo 日本語のタイトル例'
  unset SPEC_SLUG_OVERRIDE 2>/dev/null || true
  run bash -c "bash '$SCRIPT' derive_slug 457 2>&1"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi 'SPEC_SLUG_OVERRIDE\|english'
}

# =============================================================================
# spec_exists — checks docs/specs/<slug>.md existence
# =============================================================================

@test "spec_exists: file present returns 0" {
  _make_spec "$SPECS_DIR/foo.md"
  run bash "$SCRIPT" spec_exists foo "$SPECS_DIR"
  [ "$status" -eq 0 ]
}

@test "spec_exists: file missing returns non-zero" {
  run bash "$SCRIPT" spec_exists nothing "$SPECS_DIR"
  [ "$status" -ne 0 ]
}

# =============================================================================
# read_acs — extracts AC count
# =============================================================================

@test "read_acs: counts 3 ACs in sample" {
  _make_spec "$SPECS_DIR/foo.md"
  run bash "$SCRIPT" read_acs foo "$SPECS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "read_acs: missing spec returns non-zero" {
  run bash "$SCRIPT" read_acs missing "$SPECS_DIR"
  [ "$status" -ne 0 ]
}

# =============================================================================
# spec_status — frontmatter field
# (v1.0 #218: spec_persona subcommand was removed when persona was dropped.)
# =============================================================================

@test "spec_status: prints draft|approved|implemented|deprecated" {
  _make_spec "$SPECS_DIR/foo.md" approved
  run bash "$SCRIPT" spec_status foo "$SPECS_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "approved" ]
}

@test "spec_persona: subcommand is removed (returns usage error)" {
  run bash "$SCRIPT" spec_persona foo
  [ "$status" -ne 0 ]
}

# =============================================================================
# get_spec_load_message / get_spec_warn_message — canonical message formats
# =============================================================================

@test "get_spec_load_message: emits 'Loaded docs/specs/<slug>.md (AC count: N)' format" {
  run bash "$SCRIPT" get_spec_load_message foo 3
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'Loaded docs/specs/foo.md (AC count: 3)'
}

@test "get_spec_warn_message: uses [spec-warn] prefix" {
  run bash "$SCRIPT" get_spec_warn_message continuation-fallback foo
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '\[spec-warn\]'
}

# =============================================================================
# Dispatcher
# =============================================================================

@test "dispatcher: unknown subcommand exits non-zero with usage" {
  run bash "$SCRIPT" bogus_subcommand
  [ "$status" -ne 0 ]
}

@test "dispatcher: no argument exits non-zero with usage" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}
