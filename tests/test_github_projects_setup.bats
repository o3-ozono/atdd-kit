#!/usr/bin/env bats
# Tests for Issue #168: GitHub Projects v2 Kanban Board setup scripts and docs
# @covers: scripts/setup-project.sh, scripts/verify-project.sh, docs/methodology/scrumban.md

SETUP_SCRIPT="scripts/setup-project.sh"
VERIFY_SCRIPT="scripts/verify-project.sh"
SCRUMBAN_DOC="docs/methodology/scrumban.md"

# ---------------------------------------------------------------------------
# AC1: Board view has Status columns — setup-project.sh creates Status field
# ---------------------------------------------------------------------------

@test "AC1: setup-project.sh exists" {
    [ -f "$SETUP_SCRIPT" ]
}

@test "AC1: setup-project.sh is executable" {
    [ -x "$SETUP_SCRIPT" ]
}

@test "AC1: setup-project.sh creates Status field with 8 single-select options" {
    grep -q 'field-create' "$SETUP_SCRIPT"
    grep -q 'Status' "$SETUP_SCRIPT"
    grep -q 'SINGLE_SELECT' "$SETUP_SCRIPT"
}

@test "AC1: setup-project.sh includes all 4 in-progress Status values" {
    grep -q 'In Discover' "$SETUP_SCRIPT"
    grep -q 'In Plan' "$SETUP_SCRIPT"
    grep -q 'In ATDD' "$SETUP_SCRIPT"
    grep -q 'In Review (PR)' "$SETUP_SCRIPT"
}

# ---------------------------------------------------------------------------
# AC2: All Open Issues tracked with required fields — bulk-set and verify
# ---------------------------------------------------------------------------

@test "AC2: setup-project.sh contains item-add loop for all Open Issues" {
    grep -q 'item-add' "$SETUP_SCRIPT"
    grep -q 'state open' "$SETUP_SCRIPT"
}

@test "AC2: setup-project.sh uses --single-select-option-id for SINGLE_SELECT fields" {
    grep -q 'single-select-option-id' "$SETUP_SCRIPT"
}

@test "AC2: setup-project.sh uses GraphQL node ID (PROJECT_ID with .id) for --project-id" {
    # Must not use raw $PROJECT_NUM for --project-id; must use a separate ID variable
    grep -q 'PROJECT_ID' "$SETUP_SCRIPT"
    grep -q '\.id' "$SETUP_SCRIPT"
}

@test "AC2: verify-project.sh exists" {
    [ -f "$VERIFY_SCRIPT" ]
}

@test "AC2: verify-project.sh is executable" {
    [ -x "$VERIFY_SCRIPT" ]
}

@test "AC2: verify-project.sh checks PROJECT_COUNT == OPEN_COUNT" {
    grep -q 'item-list' "$VERIFY_SCRIPT"
    grep -q 'issue list' "$VERIFY_SCRIPT"
}

@test "AC2: verify-project.sh checks Status Skill Impact non-null" {
    grep -q 'Status' "$VERIFY_SCRIPT"
    grep -q 'Skill' "$VERIFY_SCRIPT"
    grep -q 'Impact' "$VERIFY_SCRIPT"
}

@test "AC2: setup-project.sh documents PR-merge-time re-run requirement in comments" {
    # Step 5+6 must be re-run at PR merge time
    grep -q 'merge' "$SETUP_SCRIPT"
}

# ---------------------------------------------------------------------------
# AC3: Board view groups by Status with Skill on cards — setup creates Skill field
# ---------------------------------------------------------------------------

@test "AC3: setup-project.sh creates Skill field as SINGLE_SELECT" {
    grep -q 'Skill' "$SETUP_SCRIPT"
}

@test "AC3: setup-project.sh includes skill option values (discover/plan/atdd)" {
    grep -q 'discover' "$SETUP_SCRIPT"
    grep -q 'plan' "$SETUP_SCRIPT"
    grep -q 'atdd' "$SETUP_SCRIPT"
}

# ---------------------------------------------------------------------------
# AC4: Roadmap view — Iteration field note in setup script
# ---------------------------------------------------------------------------

@test "AC4: setup-project.sh documents Iteration field Web UI requirement" {
    grep -q 'Iteration' "$SETUP_SCRIPT"
    grep -q 'Web UI' "$SETUP_SCRIPT"
}

@test "AC4: setup-project.sh uses --iteration-id for Iteration field bulk-set" {
    grep -q 'iteration-id' "$SETUP_SCRIPT"
}

# ---------------------------------------------------------------------------
# AC5: scrumban.md has GitHub Project section with URL / fields / mapping
# ---------------------------------------------------------------------------

@test "AC5: scrumban.md contains GitHub Project section header" {
    grep -q '## GitHub Project' "$SCRUMBAN_DOC"
}

@test "AC5: scrumban.md contains live Project URL" {
    grep -qE 'github\.com/users/o3-ozono/projects/[0-9]+' "$SCRUMBAN_DOC"
}

@test "AC5: scrumban.md lists all 7 fields including Iteration" {
    grep -q 'Iteration' "$SCRUMBAN_DOC"
    grep -q 'Skill' "$SCRUMBAN_DOC"
    grep -q 'Phase' "$SCRUMBAN_DOC"
    grep -q 'Size' "$SCRUMBAN_DOC"
    grep -q 'Impact' "$SCRUMBAN_DOC"
    grep -q 'Epic' "$SCRUMBAN_DOC"
}

@test "AC5: scrumban.md notes Iteration as Web UI only" {
    grep -q 'Web UI' "$SCRUMBAN_DOC"
}

@test "AC5: scrumban.md references Autopilot Label Correspondence section (no duplicate table)" {
    grep -q 'Autopilot Label Correspondence' "$SCRUMBAN_DOC"
}

@test "AC5: scrumban.md documents intentional gap for Shaped status" {
    grep -qi 'intentional gap\|Intentional gap' "$SCRUMBAN_DOC"
}
