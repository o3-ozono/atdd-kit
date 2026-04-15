#!/usr/bin/env bats

# AC1: Plan Review -> ready-to-go direct (PO-led flow)
@test "autopilot Plan Review transitions to ready-to-go" {
  grep -q 'ready-to-go' commands/autopilot.md
}

# AC2: in-progress label flow
@test "autopilot adds in-progress label in Phase 1" {
  grep -q 'in-progress' commands/autopilot.md
}

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

@test "auto-sweep.md monitors in-progress Issues" {
  grep -q 'in-progress' commands/auto-sweep.md
}

# (label flow is now managed by PO in autopilot.md end-to-end)

@test "issue-ready-flow.md default flow skips ready-for-user-approval" {
  ! grep -q 'ready-for-user-approval' docs/workflow/issue-ready-flow.md
}

# AC4: plan SKILL.md adds ready-for-plan-review and stops
@test "plan SKILL.md adds ready-for-plan-review label" {
  grep -q 'ready-for-plan-review' skills/plan/SKILL.md
}

@test "plan SKILL.md stops after posting plan" {
  grep -qi 'STOP\|stop here' skills/plan/SKILL.md
}

# AC6: init skill no longer exists (labels managed by session-start auto-setup)
@test "init skill directory no longer exists" {
  [[ ! -d skills/init ]]
}

# AC7: PO merges directly after QA review PASS
@test "autopilot PO merges with squash after QA PASS" {
  grep -q 'merge.*squash\|squash.*merge' commands/autopilot.md
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
