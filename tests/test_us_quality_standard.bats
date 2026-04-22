#!/usr/bin/env bats
# @covers: docs/**
# Issue #68: User Story 品質基準の策定

# AC1: MUST criteria defined

@test "AC1: docs/methodology/us-quality-standard.md exists" {
  [ -f "docs/methodology/us-quality-standard.md" ]
}

@test "AC1: MUST section references docs/personas/ with a relative link" {
  grep -q "docs/personas/" docs/methodology/us-quality-standard.md
}

@test "AC1: MUST section prohibits 'As a user'" {
  grep -qi "As a user" docs/methodology/us-quality-standard.md
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

@test "AC4: LLM guidelines contains Issue #69 link" {
  grep -q "#69" docs/methodology/us-quality-standard.md
}

@test "AC4: LLM guidelines contains defer note" {
  grep -qi "defer\|deferred" docs/methodology/us-quality-standard.md
}

# AC5: Cross-reference consistency

@test "AC5: document references persona-guide.md" {
  grep -q "persona-guide.md" docs/methodology/us-quality-standard.md
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
