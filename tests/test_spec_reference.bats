#!/usr/bin/env bats
# Issue #70: LLM US/AC auto-reference structural tests.
#
# Groups:
#   Group 1 — SKILL.md spec-load step grep (atdd/verify/bug + persona↔spec order)
#   Group 2 — lib/spec_check.sh function exports
#   Group 3 — rules/atdd-kit.md invariant
#   Group 4 — EN-only reference convention
#   Group 5 — docs/methodology/us-ac-format.md (slug / 1-Issue-1-spec / rename run-book / divergence matrix)

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# =============================================================================
# Group 1 — SKILL.md spec-load step grep
# =============================================================================

@test "Group 1 / atdd: SKILL.md has spec-load step invoking lib/spec_check.sh" {
  grep -q 'bash lib/spec_check.sh' "$REPO_ROOT/skills/atdd/SKILL.md"
}

@test "Group 1 / atdd: SKILL.md documents 'Loaded docs/specs/<slug>.md (AC count: N)' format" {
  grep -q 'Loaded docs/specs/.*AC count' "$REPO_ROOT/skills/atdd/SKILL.md"
}

@test "Group 1 / atdd: persona check precedes spec check (order grep)" {
  local f="$REPO_ROOT/skills/atdd/SKILL.md"
  local persona_line spec_line
  persona_line=$(grep -n 'persona_check\.sh\|persona check\|Persona Prerequisite' "$f" | head -1 | cut -d: -f1)
  spec_line=$(grep -n 'spec_check\.sh\|spec-load\|spec load' "$f" | head -1 | cut -d: -f1)
  [ -n "$persona_line" ]
  [ -n "$spec_line" ]
  [ "$persona_line" -lt "$spec_line" ]
}

@test "Group 1 / verify: SKILL.md has spec-authority-check step invoking lib/spec_check.sh" {
  grep -q 'bash lib/spec_check.sh' "$REPO_ROOT/skills/verify/SKILL.md"
}

@test "Group 1 / verify: SKILL.md references status tiebreak (approved/implemented vs draft)" {
  local f="$REPO_ROOT/skills/verify/SKILL.md"
  grep -qi 'status.*approved.*implemented\|approved.*implemented.*spec.*authoritative\|tiebreak' "$f"
}

@test "Group 1 / verify: SKILL.md references divergence matrix" {
  grep -qi 'Divergence Matrix\|divergence' "$REPO_ROOT/skills/verify/SKILL.md"
}

# =============================================================================
# Group 3 — rules/atdd-kit.md invariant
# =============================================================================

@test "Group 3 / rules invariant: atdd-kit.md contains spec reference invariant" {
  grep -qi 'docs/specs/\|spec reference\|US/AC spec' "$REPO_ROOT/rules/atdd-kit.md"
}

@test "Group 3 / rules invariant: atdd-kit.md stays at or below 40 lines" {
  local n
  n=$(wc -l < "$REPO_ROOT/rules/atdd-kit.md" | tr -d ' ')
  [ "$n" -le 40 ]
}

# =============================================================================
# Group 2 — lib/spec_check.sh function exports
# =============================================================================

@test "Group 2 / helper: lib/spec_check.sh dispatches derive_slug" {
  grep -q 'derive_slug)' "$REPO_ROOT/lib/spec_check.sh"
}

@test "Group 2 / helper: lib/spec_check.sh dispatches spec_exists" {
  grep -q 'spec_exists)' "$REPO_ROOT/lib/spec_check.sh"
}

@test "Group 2 / helper: lib/spec_check.sh dispatches read_acs" {
  grep -q 'read_acs)' "$REPO_ROOT/lib/spec_check.sh"
}

@test "Group 2 / helper: lib/spec_check.sh dispatches get_spec_load_message" {
  grep -q 'get_spec_load_message)' "$REPO_ROOT/lib/spec_check.sh"
}

@test "Group 2 / helper: lib/spec_check.sh dispatches get_spec_warn_message" {
  grep -q 'get_spec_warn_message)' "$REPO_ROOT/lib/spec_check.sh"
}

# =============================================================================
# Group 5 — docs/methodology/us-ac-format.md
# =============================================================================

@test "Group 5 / doc: us-ac-format.md has Slug Derivation Rule section" {
  grep -qi '## Slug Derivation Rule' "$REPO_ROOT/docs/methodology/us-ac-format.md"
}

@test "Group 5 / doc: us-ac-format.md declares 1 Issue = 1 spec policy" {
  grep -qi '1 Issue = 1 spec\|1 Issue/1 spec' "$REPO_ROOT/docs/methodology/us-ac-format.md"
}

@test "Group 5 / doc: us-ac-format.md cross-links to Rename Run-Book" {
  grep -q '#rename-run-book\|## Rename Run-Book' "$REPO_ROOT/docs/methodology/us-ac-format.md"
}

@test "Group 5 / doc: us-ac-format.md has Spec ↔ Issue Divergence Matrix" {
  grep -qi 'Divergence Matrix' "$REPO_ROOT/docs/methodology/us-ac-format.md"
}

@test "Group 5 / doc: divergence matrix lists all 5 patterns" {
  local f="$REPO_ROOT/docs/methodology/us-ac-format.md"
  grep -qi 'Added ' "$f"
  grep -qi 'Removed ' "$f"
  grep -qi 'Modified ' "$f"
  grep -qi 'Reordered ' "$f"
  grep -qi 'Status drift\|status-drift' "$f"
}

# =============================================================================
# Group 4 — EN-only reference convention
# =============================================================================

@test "Group 4 / EN-only: SKILL.md spec-load steps reference docs/specs not docs-ja" {
  ! grep -rq 'docs-ja/specs\|docs\.ja/specs' \
      "$REPO_ROOT/skills/atdd/SKILL.md" \
      "$REPO_ROOT/skills/verify/SKILL.md" \
      "$REPO_ROOT/skills/bug/SKILL.md"
}

@test "Group 4 / EN-only: lib/spec_check.sh references English docs path only" {
  ! grep -q 'docs-ja/specs\|docs\.ja/specs' "$REPO_ROOT/lib/spec_check.sh"
}
