#!/usr/bin/env bats

# Test file for Issue #162: autopilot Agent Teams worktree isolation
# Validates AC1-AC5 against commands/autopilot.md and skills/session-start/SKILL.md

AUTOPILOT="commands/autopilot.md"
SESSION_START="skills/session-start/SKILL.md"

# ---------------------------------------------------------------------------
# AC1: PO enters worktree via EnterWorktree
# ---------------------------------------------------------------------------

@test "AC1: Phase 0.9 Tools annotation includes EnterWorktree" {
  grep -A 3 "## Phase 0.9" "$AUTOPILOT" | grep -q "EnterWorktree"
}

@test "AC1: Phase 0.9 calls EnterWorktree with autopilot-{issue_number} name" {
  grep -A 30 "## Phase 0.9" "$AUTOPILOT" | grep -q "EnterWorktree"
  grep -A 30 "## Phase 0.9" "$AUTOPILOT" | grep -q "autopilot-{issue_number}"
}

# ---------------------------------------------------------------------------
# AC2: All Agent spawns include isolation: "worktree"
# ---------------------------------------------------------------------------

@test "AC2: AC Review Round Agent spawn includes isolation worktree" {
  grep -A 10 "## AC Review Round" "$AUTOPILOT" | grep -q 'isolation.*worktree\|isolation: "worktree"'
}

@test "AC2: Phase 2-4 use SendMessage (no new Agent spawn, isolation established at AC Review)" {
  # Phase 2, Plan Review, Phase 3, Phase 4 use SendMessage, not Agent tool
  # Isolation is established once at AC Review Round Agent generation
  grep -A 15 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'SendMessage'
  grep -A 15 "## Plan Review Round" "$AUTOPILOT" | grep -q 'SendMessage'
  grep -A 15 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q 'SendMessage'
  grep -A 15 "## Phase 4: PR Review" "$AUTOPILOT" | grep -q 'SendMessage'
}

@test "AC2: All Agent spawns include isolation parameter" {
  # Count Agent tool lines that include team_name (spawn sites — now only AC Review Round + resume)
  total=$(grep -c 'Agent.*tool.*team_name\|Agent tool.*team_name' "$AUTOPILOT") || total=0
  # Count Agent tool lines that include both team_name and isolation
  isolated=$(grep 'Agent.*tool.*team_name\|Agent tool.*team_name' "$AUTOPILOT" | grep -c 'isolation') || isolated=0
  # All spawn sites must have isolation, and there must be at least 1
  [ "$total" -gt 0 ]
  [ "$total" -eq "$isolated" ]
}

# ---------------------------------------------------------------------------
# AC3: ExitWorktree cleanup in Phase 5
# ---------------------------------------------------------------------------

@test "AC3: Phase 5 Tools annotation includes ExitWorktree" {
  grep -A 3 "## Phase 5" "$AUTOPILOT" | grep -q "ExitWorktree"
}

@test "AC3: Phase 5 calls ExitWorktree with action remove" {
  grep -A 40 "## Phase 5" "$AUTOPILOT" | grep -q 'ExitWorktree.*remove\|ExitWorktree.*action.*remove'
}

# ---------------------------------------------------------------------------
# AC4: Stale worktree cleanup in session-start
# ---------------------------------------------------------------------------

@test "AC4: session-start Phase 0 includes worktree cleanup step" {
  grep -q "worktree" "$SESSION_START"
  grep -q "prune\|cleanup\|clean" "$SESSION_START"
}

@test "AC4: session-start references git worktree list" {
  grep -q "git worktree list" "$SESSION_START"
}

@test "AC4: session-start references git worktree prune" {
  grep -q "git worktree prune" "$SESSION_START"
}

@test "AC4: session-start Phase 3 report includes worktree status section" {
  grep -q "Worktree" "$SESSION_START"
}

# ---------------------------------------------------------------------------
# AC5: Concurrent session independence (design verification)
# AC5 is satisfied by AC1 (PO in separate worktree per issue_number)
# + AC2 (Dev/QA in isolation worktree). Verify the naming guarantees uniqueness.
# ---------------------------------------------------------------------------

@test "AC5: EnterWorktree name includes issue_number for uniqueness" {
  grep -A 30 "## Phase 0.9" "$AUTOPILOT" | grep "EnterWorktree" | grep -q "issue_number\|{issue_number}"
}
