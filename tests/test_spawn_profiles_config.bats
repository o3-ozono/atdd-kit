#!/usr/bin/env bats

# Issue #109 — config/spawn-profiles.yml schema validation.
#
# Scope:
#   AC13: profiles.light / profiles.heavy に developer/qa/tester/reviewer/
#         researcher/writer の 6 role が揃い、各エントリに model キーが存在し、
#         かつ effortLevel キーが存在しない
#   AC8 (partial, runtime side): sonnet / opus リテラルが本ファイルに出現する
#
# Note: Plan では python3 + pyyaml 前提だったが pyyaml は pre-installed ではない
# ため、YAML の構造チェックは grep/awk で実施する。本ファイルの形式は matrix
# フラット構造に固定されており、インデント依存しないキー存在確認で要件を満たす。

CONFIG="${BATS_TEST_DIRNAME}/../config/spawn-profiles.yml"
ROLES=(developer qa tester reviewer researcher writer)

extract_profile_block() {
  # Print lines between `<profile>:` (indented 2 spaces under profiles:) and
  # the next profile heading (exclusive). If <profile> is the last one, print
  # to EOF.
  awk -v name="$1" '
    $0 ~ "^  " name ":" { in_block=1; next }
    in_block && /^  [a-z]+:/ { exit }
    in_block { print }
  ' "$CONFIG"
}

@test "config/spawn-profiles.yml exists" {
  [ -f "$CONFIG" ]
}

@test "AC13: top-level profiles key exists" {
  grep -q '^profiles:' "$CONFIG"
}

@test "AC13: profiles.light block exists" {
  grep -qE '^  light:' "$CONFIG"
}

@test "AC13: profiles.heavy block exists" {
  grep -qE '^  heavy:' "$CONFIG"
}

@test "AC13: profiles.light has all 6 roles with model key" {
  block="$(extract_profile_block light)"
  for role in "${ROLES[@]}"; do
    echo "$block" | grep -qE "^    ${role}:.*model:[[:space:]]*sonnet" \
      || { echo "light.$role missing or not sonnet"; return 1; }
  done
}

@test "AC13: profiles.heavy has all 6 roles with model key" {
  block="$(extract_profile_block heavy)"
  for role in "${ROLES[@]}"; do
    echo "$block" | grep -qE "^    ${role}:.*model:[[:space:]]*opus" \
      || { echo "heavy.$role missing or not opus"; return 1; }
  done
}

@test "AC13: effortLevel key is absent from the entire config" {
  # Regression guard — effort control is out of scope for this release.
  ! grep -q 'effortLevel' "$CONFIG"
}

@test "AC13: effort dimension references absent" {
  # Stronger guard — no effort/effort_level/effortlevel variations anywhere.
  ! grep -qiE 'effort[_-]?level' "$CONFIG"
}

@test "AC8: sonnet literal appears in config/spawn-profiles.yml" {
  grep -q 'sonnet' "$CONFIG"
}

@test "AC8: opus literal appears in config/spawn-profiles.yml" {
  grep -q 'opus' "$CONFIG"
}

# ---------------------------------------------------------------------------
# AC8 — Single source of truth: preset literals must NOT leak into
# commands/autopilot.md, agents/*.md, or other skill markdown (outside of
# explicitly-marked NL example blocks).
# ---------------------------------------------------------------------------

REPO_ROOT="${BATS_TEST_DIRNAME}/.."

strip_nl_examples() {
  # Remove blocks between <!-- nl-example start --> and <!-- nl-example end -->
  awk '
    /<!-- nl-example start -->/ { skip=1; next }
    /<!-- nl-example end -->/   { skip=0; next }
    !skip { print }
  ' "$1"
}

@test "AC8: commands/autopilot.md has no sonnet literal outside nl-example blocks" {
  file="$REPO_ROOT/commands/autopilot.md"
  [ -f "$file" ]
  ! strip_nl_examples "$file" | grep -qE '\bsonnet\b'
}

@test "AC8: commands/autopilot.md has no opus literal outside nl-example blocks" {
  file="$REPO_ROOT/commands/autopilot.md"
  [ -f "$file" ]
  ! strip_nl_examples "$file" | grep -qE '\bopus\b'
}

@test "AC8: agents/*.md have no sonnet/opus literals" {
  for f in "$REPO_ROOT"/agents/*.md; do
    [ -f "$f" ] || continue
    ! grep -qE '\b(sonnet|opus)\b' "$f" \
      || { echo "preset literal leaked into $f"; return 1; }
  done
}

@test "AC8: skills/**/SKILL.md have no sonnet/opus literals" {
  for f in "$REPO_ROOT"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    ! grep -qE '\b(sonnet|opus)\b' "$f" \
      || { echo "preset literal leaked into $f"; return 1; }
  done
}
