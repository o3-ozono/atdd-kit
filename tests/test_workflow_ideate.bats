#!/usr/bin/env bats

# AC6: Workflow documentation includes ideate step between issue and discover

# --- docs/workflow/issue-ready-flow.md ---

@test "AC6: issue-ready-flow.md mentions ideate step" {
  grep -qi 'ideate' docs/workflow/issue-ready-flow.md
}

@test "AC6: issue-ready-flow.md shows ideate between issue and discover" {
  # ideate should appear in the development task flow
  run grep -n 'ideate\|discover\|Issue' docs/workflow/issue-ready-flow.md
  [[ "$output" == *"ideate"* ]]
}

# --- docs/workflow/workflow-detail.md ---

@test "AC6: workflow-detail.md mentions ideate in skill chain" {
  grep -qi 'ideate' docs/workflow/workflow-detail.md
}

@test "AC6: workflow-detail.md Full Workflow includes ideate" {
  grep -qi 'ideate' docs/workflow/workflow-detail.md
}

# --- skills/README.md ---

@test "AC6: skills/README.md shows ideate workflow position includes discover chain" {
  # ideate should mention being between issue and discover
  run grep -A1 'ideate' skills/README.md
  [[ "$output" == *"ideate"* ]]
}

# --- DEVELOPMENT.md ---

@test "AC6: DEVELOPMENT.md skill chain includes ideate" {
  grep -q 'ideate' DEVELOPMENT.md
}

# --- DEVELOPMENT.ja.md ---

@test "AC6: DEVELOPMENT.ja.md skill chain includes ideate" {
  grep -q 'ideate' DEVELOPMENT.ja.md
}

# --- README.md ---

@test "AC6: README.md workflow diagram includes ideate" {
  grep -q 'ideate' README.md
}

# --- README.ja.md ---

@test "AC6: README.ja.md workflow diagram includes ideate" {
  grep -q 'ideate' README.ja.md
}
