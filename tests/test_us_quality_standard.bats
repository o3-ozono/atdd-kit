#!/usr/bin/env bats
# @covers: docs/**
# Issue #68: User Story 品質基準の策定

# AC1: MUST criteria defined

@test "AC1: docs/methodology/us-quality-standard.md exists" {
  [ -f "docs/methodology/us-quality-standard.md" ]
}

@test "AC1: MUST section does NOT reference removed docs/personas/ (v1.0 #218)" {
  ! grep -q "docs/personas/" docs/methodology/us-quality-standard.md
}

@test "AC1: MUST section does NOT reintroduce 'As a [persona]' (v1.0 #218)" {
  ! grep -qE 'As a \[persona\]|As a user' docs/methodology/us-quality-standard.md
}

@test "AC1: MUST section contains GWT AC count rule (3+)" {
  grep -qE "3\s*\+|3 or more|at least 3|minimum.*3" docs/methodology/us-quality-standard.md
}

@test "AC1: MUST section contains independent verifiability rule" {
  grep -qi "independent.*verif\|verif.*independent" docs/methodology/us-quality-standard.md
}

@test "AC1: MUST section has Pass example" {
  grep -qF "**Pass:**" docs/methodology/us-quality-standard.md
}

@test "AC1: MUST section has Fail example" {
  grep -qF "**Fail:**" docs/methodology/us-quality-standard.md
}

# AC2: SHOULD criteria defined (QUS-based)

@test "AC2: SHOULD section contains well-formed criterion" {
  grep -qi "well-formed\|well formed" docs/methodology/us-quality-standard.md
}

@test "AC2: SHOULD section contains atomic criterion" {
  grep -qi "atomic" docs/methodology/us-quality-standard.md
}

@test "AC2: SHOULD section contains minimal criterion" {
  grep -qi "minimal" docs/methodology/us-quality-standard.md
}

@test "AC2: SHOULD section contains problem-oriented criterion" {
  grep -qi "problem-oriented\|problem oriented" docs/methodology/us-quality-standard.md
}

@test "AC2: SHOULD section contains unambiguous criterion" {
  grep -qi "unambiguous" docs/methodology/us-quality-standard.md
}

@test "AC2: document contains MUST/SHOULD classification rationale note" {
  grep -qi "MUST.*existing\|existing.*format.*MUST\|SHOULD.*QUS\|QUS.*SHOULD" docs/methodology/us-quality-standard.md
}

# AC3: Anti-pattern list defined (Requirements Smells)

@test "AC3: Anti-pattern section contains subjective expressions category" {
  grep -qi "subjective" docs/methodology/us-quality-standard.md
}

@test "AC3: Anti-pattern section contains unverifiable terms category" {
  grep -qi "unverifiable\|unverifiable terms" docs/methodology/us-quality-standard.md
}

@test "AC3: Anti-pattern section contains incomplete references category" {
  grep -qi "incomplete.*ref\|incomplete reference" docs/methodology/us-quality-standard.md
}

@test "AC3: Anti-pattern section has at least 6 bad-word/phrase examples with rewrites" {
  count=$(grep -c "Fix\|Rewrite\|Replace\|Instead\|Better\|Use" docs/methodology/us-quality-standard.md || true)
  [ "$count" -ge 6 ]
}

# AC4: LLM prompt guidelines documented

@test "AC4: LLM guidelines section exists" {
  grep -qi "LLM\|llm.*guideline\|guideline.*llm" docs/methodology/us-quality-standard.md
}

@test "AC4: LLM guidelines contains defer note (deferred to a future Issue)" {
  grep -qi "defer\|deferred" docs/methodology/us-quality-standard.md
}

@test "AC4: LLM guidelines retains historical #69 reference for traceability (v1.0 #218 note)" {
  # The original deferral target #69 is mentioned in the note that explains why
  # it became irrelevant in v1.0 — keeping the link satisfies traceability.
  grep -q "#69" docs/methodology/us-quality-standard.md
}

# AC5: Cross-reference consistency

@test "AC5: document does NOT reference removed persona-guide.md (v1.0 #218)" {
  ! grep -q "persona-guide.md" docs/methodology/us-quality-standard.md
}

@test "AC5: document references atdd-guide.md" {
  grep -q "atdd-guide.md" docs/methodology/us-quality-standard.md
}

@test "AC5: document has no YAML frontmatter" {
  first_line=$(head -1 docs/methodology/us-quality-standard.md)
  [ "$first_line" != "---" ]
}

@test "AC5: document references us-ac-format.md" {
  grep -q "us-ac-format.md" docs/methodology/us-quality-standard.md
}

# AC6: Directory README created or updated

@test "AC6: docs/methodology/README.md exists" {
  [ -f "docs/methodology/README.md" ]
}

@test "AC6: README.md contains entry for us-quality-standard.md" {
  grep -q "us-quality-standard" docs/methodology/README.md
}

@test "AC6: README.md entry for us-quality-standard has a description" {
  grep -qE "us-quality-standard.*[a-zA-Z]{5,}|[a-zA-Z]{5,}.*us-quality-standard" docs/methodology/README.md
}

# Language policy

@test "Language policy: us-quality-standard.md is English only (no Japanese characters)" {
  [ -f "docs/methodology/us-quality-standard.md" ]
  ! grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/us-quality-standard.md
}

@test "Language policy: docs/methodology/README.md is English only (no Japanese characters)" {
  [ -f "docs/methodology/README.md" ]
  ! grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/README.md
}

# --- Issue #156: MUST-3 US Traceability ---

@test "#156-AC4: MUST-3 section exists with h3 heading" {
  grep -q '^### MUST-3:' docs/methodology/us-quality-standard.md
}

@test "#156-AC4: MUST-3 section contains Why paragraph" {
  sed -n '/^### MUST-3:/,/^### /p' docs/methodology/us-quality-standard.md | grep -qF '**Why:**'
}

@test "#156-AC4: MUST-3 section contains Pass example" {
  sed -n '/^### MUST-3:/,/^### /p' docs/methodology/us-quality-standard.md | grep -qF '**Pass:**'
}

@test "#156-AC4: MUST-3 section contains Fail example" {
  sed -n '/^### MUST-3:/,/^### /p' docs/methodology/us-quality-standard.md | grep -qF '**Fail:**'
}

@test "#156-AC4: MUST-3 Why/Pass/Fail appear in correct order" {
  local must4_line why_line pass_line fail_line
  must4_line=$(grep -n '^### MUST-3:' docs/methodology/us-quality-standard.md | cut -d: -f1)
  why_line=$(awk -v start="$must4_line" 'NR>start && /^\*\*Why:\*\*/{print NR; exit}' docs/methodology/us-quality-standard.md)
  pass_line=$(awk -v start="$must4_line" 'NR>start && /^\*\*Pass:\*\*/{print NR; exit}' docs/methodology/us-quality-standard.md)
  fail_line=$(awk -v start="$must4_line" 'NR>start && /^\*\*Fail:\*\*/{print NR; exit}' docs/methodology/us-quality-standard.md)
  [ -n "$why_line" ] && [ -n "$pass_line" ] && [ -n "$fail_line" ]
  [ "$why_line" -lt "$pass_line" ]
  [ "$pass_line" -lt "$fail_line" ]
}

@test "#156-AC4: MUST-3 section mentions exclusion categories (project conventions)" {
  sed -n '/^### MUST-3:/,/^### /p' docs/methodology/us-quality-standard.md | grep -qi 'project.*convent\|CI.*green\|lint\|warning\|coverage'
}

@test "#156-AC4: MUST-3 section mentions exclusion categories (implementation guard)" {
  sed -n '/^### MUST-3:/,/^### /p' docs/methodology/us-quality-standard.md | grep -qi 'implementation.*guard\|impl.*guard'
}

@test "#156-AC4: MUST-3 section notes no retroactive application to existing specs" {
  sed -n '/^### MUST-3:/,/^### /p' docs/methodology/us-quality-standard.md | grep -qi 'retroactive\|existing.*spec\|new.*discover\|not.*apply.*existing'
}

@test "#156-AC4: MUST-3 (US Traceability) appears after MUST-2 (Independent Verifiability)" {
  local must2_line must3_line
  must2_line=$(grep -n '^### MUST-2:' docs/methodology/us-quality-standard.md | cut -d: -f1)
  must3_line=$(grep -n '^### MUST-3:' docs/methodology/us-quality-standard.md | cut -d: -f1)
  [ -n "$must2_line" ] && [ -n "$must3_line" ]
  [ "$must2_line" -lt "$must3_line" ]
}

@test "Language policy: MUST-3 section is English only (no Japanese characters)" {
  [ -f "docs/methodology/us-quality-standard.md" ]
  ! grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/us-quality-standard.md
}
