#!/usr/bin/env bats
# @covers: .claude-plugin/**
# AC3: Document consistency -- ready-for-user-approval
@test "workflow-detail.md contains ready-for-user-approval in Issue flow" {
  grep -q 'ready-for-user-approval' docs/workflow/workflow-detail.md
}

@test "workflow-detail.md contains in-progress in Issue labels" {
  grep -q 'in-progress' docs/workflow/workflow-detail.md
}

@test "rules/atdd-kit.md default flow skips ready-for-user-approval" {
  ! grep -q 'ready-for-user-approval' rules/atdd-kit.md
}

@test "rules/atdd-kit.md contains in-progress" {
  grep -q 'in-progress' rules/atdd-kit.md
}

@test "README.md contains in-progress" {
  grep -q 'in-progress' README.md
}

@test "README.ja.md contains in-progress" {
  grep -q 'in-progress' README.ja.md
}

@test "workflow-detail.md references in-progress label" {
  grep -q 'in-progress' docs/workflow/workflow-detail.md
}

# (label flow is now managed by PO in autopilot.md end-to-end)

@test "issue-ready-flow.md default flow skips ready-for-user-approval" {
  ! grep -q 'ready-for-user-approval' docs/workflow/issue-ready-flow.md
}

# AC6: init skill no longer exists (labels managed by session-start auto-setup)
@test "init skill directory no longer exists" {
  [[ ! -d skills/init ]]
}

@test "autopilot does not use review-approved label" {
  ! grep -q 'review-approved' commands/autopilot.md
}

@test "workflow-detail PR flow does not mention standalone review-approved" {
  ! grep -q 'review-approved' docs/workflow/workflow-detail.md
}

@test "rules/atdd-kit.md PR flow does not mention standalone review-approved" {
  ! grep -q 'review-approved' rules/atdd-kit.md
}

@test "init skill no longer manages labels" {
  [[ ! -f skills/init/SKILL.md ]]
}

# AC: session-start no longer lists ready-for-user-approval as top priority (default flow skips it)
@test "session-start SKILL.md does not list ready-for-user-approval as highest priority" {
  ! grep -q 'ready-for-user-approval.*highest' skills/session-start/SKILL.md
}
