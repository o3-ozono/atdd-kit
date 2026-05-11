#!/usr/bin/env bats
# @covers: skills/defining-requirements/SKILL.md
# Skill Acceptance Test (structural) for the defining-requirements skill (#188 / #179 Step B1).
# Verifies the v1.0 contract: ~200 lines, persona-less, PRD 6 sections,
# upstream/downstream wiring, status output, no HARD-GATE remnants.

SKILL_FILE="skills/defining-requirements/SKILL.md"

# ---------------------------------------------------------------------------
# AC: file exists with correct frontmatter
# ---------------------------------------------------------------------------

@test "AC: skills/defining-requirements/SKILL.md exists and is non-empty" {
  [ -f "$SKILL_FILE" ]
  [ -s "$SKILL_FILE" ]
}

@test "AC: frontmatter contains name=defining-requirements" {
  awk '/^---$/{n++; next} n==1 && /^name: *defining-requirements$/{found=1} END{exit !found}' "$SKILL_FILE"
}

@test "AC: frontmatter contains non-empty description" {
  awk '/^---$/{n++; next} n==1 && /^description: *"[^"]+"/{found=1} END{exit !found}' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AC: file size is ≤ 200 lines
# ---------------------------------------------------------------------------

@test "AC: SKILL.md is at most 200 lines" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 200 ]
}

# ---------------------------------------------------------------------------
# AC: HARD-GATE skeleton block has been replaced with the real implementation
# ---------------------------------------------------------------------------

@test "AC: HARD-GATE block is not present (skeleton replaced)" {
  ! grep -q '<HARD-GATE>' "$SKILL_FILE"
}

@test "AC: skeleton 'not yet implemented' marker is not present" {
  ! grep -qi 'not yet implemented' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AC: PRD 6 sections from templates/docs/issues/prd.md are referenced verbatim
# ---------------------------------------------------------------------------

@test "AC: SKILL.md references the Problem section" {
  grep -q '^### Step 1: Problem' "$SKILL_FILE"
}

@test "AC: SKILL.md references the Why now section" {
  grep -q '^### Step 2: Why now' "$SKILL_FILE"
}

@test "AC: SKILL.md references the Outcome section" {
  grep -q '^### Step 3: Outcome' "$SKILL_FILE"
}

@test "AC: SKILL.md references the What section" {
  grep -q '^### Step 4: What' "$SKILL_FILE"
}

@test "AC: SKILL.md references the Non-Goals section" {
  grep -q '^### Step 5: Non-Goals' "$SKILL_FILE"
}

@test "AC: SKILL.md references the Open Questions section" {
  grep -q '^### Step 6: Open Questions' "$SKILL_FILE"
}

@test "AC: PRD 6 sections appear in template order in the SKILL.md flow" {
  local pos_problem pos_whynow pos_outcome pos_what pos_nongoals pos_openq
  pos_problem=$(grep -n '^### Step 1: Problem' "$SKILL_FILE" | head -1 | cut -d: -f1)
  pos_whynow=$(grep -n '^### Step 2: Why now' "$SKILL_FILE" | head -1 | cut -d: -f1)
  pos_outcome=$(grep -n '^### Step 3: Outcome' "$SKILL_FILE" | head -1 | cut -d: -f1)
  pos_what=$(grep -n '^### Step 4: What' "$SKILL_FILE" | head -1 | cut -d: -f1)
  pos_nongoals=$(grep -n '^### Step 5: Non-Goals' "$SKILL_FILE" | head -1 | cut -d: -f1)
  pos_openq=$(grep -n '^### Step 6: Open Questions' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ "$pos_problem" -lt "$pos_whynow" ]
  [ "$pos_whynow" -lt "$pos_outcome" ]
  [ "$pos_outcome" -lt "$pos_what" ]
  [ "$pos_what" -lt "$pos_nongoals" ]
  [ "$pos_nongoals" -lt "$pos_openq" ]
}

# ---------------------------------------------------------------------------
# AC: PRD artifact output path matches the template location
# ---------------------------------------------------------------------------

@test "AC: SKILL.md declares output at docs/issues/<NNN>/prd.md" {
  grep -q 'docs/issues/<NNN>/prd.md' "$SKILL_FILE"
}

@test "AC: SKILL.md references templates/docs/issues/prd.md as the source template" {
  grep -q 'templates/docs/issues/prd.md' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AC: v1.0 persona-less rule is preserved
# ---------------------------------------------------------------------------

@test "AC: SKILL.md uses persona-less Connextra form (I want to ..., so that ...)" {
  grep -q "I want to <goal>, so that <reason>" "$SKILL_FILE"
}

@test "AC: SKILL.md does NOT introduce 'As a [persona]' form (v1.0 #216 / #218)" {
  ! grep -qE 'As a \[persona\]' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AC: Integration section wires upstream and downstream skills
# ---------------------------------------------------------------------------

@test "AC: Integration section declares session-start as Upstream" {
  grep -qE '^- \*\*Upstream:\*\*[[:space:]]+`session-start`' "$SKILL_FILE"
}

@test "AC: Integration section declares extracting-user-stories as Downstream" {
  grep -qE '^- \*\*Downstream:\*\*[[:space:]]+`extracting-user-stories`' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AC: Status Output block matches the skill-status spec
# ---------------------------------------------------------------------------

@test "AC: Status Output section declares all 4 terminal values" {
  for v in COMPLETE PENDING BLOCKED FAILED; do
    grep -q "$v" "$SKILL_FILE" || {
      echo "missing terminal value: $v"
      return 1
    }
  done
}

@test "AC: skill-status fenced block has PHASE=defining-requirements" {
  grep -q '^PHASE: defining-requirements' "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# AC: SAT artifacts exist for the fast layer (#196 C1 will check the full 10-skill set)
# ---------------------------------------------------------------------------

@test "AC: tests/claude-code/samples/fast-defining-requirements.sh exists and is executable" {
  [ -f "tests/claude-code/samples/fast-defining-requirements.sh" ]
  [ -x "tests/claude-code/samples/fast-defining-requirements.sh" ]
}

@test "AC: tests/claude-code/fixtures/defining-requirements-keywords.txt exists and is non-empty" {
  [ -f "tests/claude-code/fixtures/defining-requirements-keywords.txt" ]
  [ -s "tests/claude-code/fixtures/defining-requirements-keywords.txt" ]
}
