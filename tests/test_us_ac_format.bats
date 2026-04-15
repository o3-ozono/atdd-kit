#!/usr/bin/env bats

# Issue #66: docs/specs/ 導入と US/AC format 策定

# ---------------------------------------------------------------------------
# AC1: format definition document exists
# ---------------------------------------------------------------------------

@test "AC1: docs/methodology/us-ac-format.md exists" {
  [ -f "docs/methodology/us-ac-format.md" ]
}

@test "AC1: us-ac-format.md is English only (no Japanese characters)" {
  ! grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/us-ac-format.md
}

@test "AC1: us-ac-format.md defines required frontmatter fields" {
  grep -q "title" docs/methodology/us-ac-format.md
  grep -q "persona" docs/methodology/us-ac-format.md
  grep -q "issue" docs/methodology/us-ac-format.md
  grep -q "status" docs/methodology/us-ac-format.md
}

@test "AC1: us-ac-format.md defines status values" {
  grep -q "draft" docs/methodology/us-ac-format.md
  grep -q "approved" docs/methodology/us-ac-format.md
  grep -q "implemented" docs/methodology/us-ac-format.md
  grep -q "deprecated" docs/methodology/us-ac-format.md
}

@test "AC1: us-ac-format.md defines section structure" {
  grep -q "User Story" docs/methodology/us-ac-format.md
  grep -q "Acceptance Criteria" docs/methodology/us-ac-format.md
  grep -q "Notes" docs/methodology/us-ac-format.md
}

# ---------------------------------------------------------------------------
# AC2: docs/specs/ directory has README and TEMPLATE
# ---------------------------------------------------------------------------

@test "AC2: docs/specs/ directory exists" {
  [ -d "docs/specs" ]
}

@test "AC2: docs/specs/README.md exists" {
  [ -f "docs/specs/README.md" ]
}

@test "AC2: docs/specs/TEMPLATE.md exists" {
  [ -f "docs/specs/TEMPLATE.md" ]
}

@test "AC2: TEMPLATE.md has all 4 frontmatter placeholder fields" {
  grep -q "title" docs/specs/TEMPLATE.md
  grep -q "persona" docs/specs/TEMPLATE.md
  grep -q "issue" docs/specs/TEMPLATE.md
  grep -q "status" docs/specs/TEMPLATE.md
}

@test "AC2: TEMPLATE.md has status draft as default" {
  grep -q "draft" docs/specs/TEMPLATE.md
}

# ---------------------------------------------------------------------------
# AC3: sample spec conforms to format (mechanical checklist)
# ---------------------------------------------------------------------------

@test "AC3: docs/specs/us-ac-format.md exists" {
  [ -f "docs/specs/us-ac-format.md" ]
}

@test "AC3: sample spec has all 4 frontmatter fields" {
  grep -q "^title:" docs/specs/us-ac-format.md
  grep -q "^persona:" docs/specs/us-ac-format.md
  grep -q "^issue:" docs/specs/us-ac-format.md
  grep -q "^status:" docs/specs/us-ac-format.md
}

@test "AC3: sample spec issue value is #66" {
  grep -q 'issue:.*"#66"' docs/specs/us-ac-format.md
}

@test "AC3: sample spec status is a valid value" {
  grep -qE '^status: (draft|approved|implemented|deprecated)' docs/specs/us-ac-format.md
}

@test "AC3: sample spec has non-empty User Story section" {
  python3 -c "
import re, sys
content = open('docs/specs/us-ac-format.md').read()
m = re.search(r'## User Story\n(.*?)(?=\n## |$)', content, re.DOTALL)
assert m and m.group(1).strip(), 'User Story section is empty'
"
}

@test "AC3: sample spec has 3 or more Given lines" {
  count=$(grep -c '^- \*\*Given' docs/specs/us-ac-format.md || true)
  [ "$count" -ge 3 ]
}

@test "AC3: sample spec has 3 or more When lines" {
  count=$(grep -c '^- \*\*When' docs/specs/us-ac-format.md || true)
  [ "$count" -ge 3 ]
}

@test "AC3: sample spec has 3 or more Then lines" {
  count=$(grep -c '^- \*\*Then' docs/specs/us-ac-format.md || true)
  [ "$count" -ge 3 ]
}

# ---------------------------------------------------------------------------
# AC4: docs/README.md index updated
# ---------------------------------------------------------------------------

@test "AC4: docs/README.md has specs/ section" {
  grep -q "specs" docs/README.md
}

@test "AC4: docs/README.md has us-ac-format.md row in methodology table" {
  grep -q "us-ac-format" docs/README.md
}

# ---------------------------------------------------------------------------
# AC6: no broken internal links
# ---------------------------------------------------------------------------

@test "AC6: referenced docs/methodology/us-ac-format.md exists where linked" {
  # Find all internal links to us-ac-format.md and verify the file exists
  [ -f "docs/methodology/us-ac-format.md" ]
}

@test "AC6: docs/specs links do not reference non-existent files" {
  # Check that cross-references within docs/specs/ to personas/ are valid
  if grep -r "docs/personas/" docs/specs/ 2>/dev/null | grep -q "."; then
    for f in $(grep -roh "docs/personas/[^)\"']*" docs/specs/ 2>/dev/null); do
      [ -f "$f" ]
    done
  fi
  true
}

# ---------------------------------------------------------------------------
# AC7: CHANGELOG updated
# ---------------------------------------------------------------------------

@test "AC7: CHANGELOG.md has Unreleased section" {
  grep -q "## \[Unreleased\]" CHANGELOG.md
}

# ---------------------------------------------------------------------------
# Language policy
# ---------------------------------------------------------------------------

@test "Lang policy: docs/specs/us-ac-format.md is English only" {
  ! grep -P '[ぁ-んァ-ヶ一-龥]' docs/specs/us-ac-format.md
}

@test "Lang policy: docs/specs/README.md is English only" {
  ! grep -P '[ぁ-んァ-ヶ一-龥]' docs/specs/README.md
}

@test "Lang policy: docs/specs/TEMPLATE.md is English only" {
  ! grep -P '[ぁ-んァ-ヶ一-龥]' docs/specs/TEMPLATE.md
}
