#!/usr/bin/env bats

# Issue #34 AC4: ready-to-go label (replacing ready-to-implement)

@test "AC4: autopilot.md uses ready-to-go instead of ready-to-implement" {
  grep -q 'ready-to-go' commands/autopilot.md
  ! grep -Eq 'ready.to.implement' commands/autopilot.md
}

@test "AC4: atdd SKILL.md uses ready-to-go" {
  grep -q 'ready-to-go' skills/atdd/SKILL.md
  ! grep -Eq 'ready.to.implement' skills/atdd/SKILL.md
}

@test "AC4: setup-github creates ready-to-go label" {
  grep -q 'ready-to-go' commands/setup-github.md
  ! grep -Eq 'ready.to.implement' commands/setup-github.md
}

@test "AC4: rules/atdd-kit.md uses ready-to-go" {
  grep -q 'ready-to-go' rules/atdd-kit.md
  ! grep -Eq 'ready.to.implement' rules/atdd-kit.md
}

@test "AC4: workflow-detail.md uses ready-to-go" {
  grep -q 'ready-to-go' docs/workflow/workflow-detail.md
  ! grep -Eq 'ready.to.implement' docs/workflow/workflow-detail.md
}

@test "AC4: issue-ready-flow.md uses ready-to-go" {
  grep -q 'ready-to-go' docs/workflow/issue-ready-flow.md
  ! grep -Eq 'ready.to.implement' docs/workflow/issue-ready-flow.md
}

@test "AC4: skills/README.md uses ready-to-go" {
  grep -q 'ready-to-go' skills/README.md
  ! grep -Eq 'ready.to.implement' skills/README.md
}
