#!/usr/bin/env bats

# Issue #2: session-start Agent Teams environment variable auto-configuration

# ---------------------------------------------------------------------------
# AC1: Every-session auto-configuration in Phase 1-G
# ---------------------------------------------------------------------------

@test "AC1: session-start mentions CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" {
  grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' skills/session-start/SKILL.md
}

@test "AC1: session-start targets settings.local.json for env var" {
  grep -q 'settings\.local\.json' skills/session-start/SKILL.md
}

@test "AC1: Agent Teams env check is in Phase 1 parallel section" {
  awk '/^## Phase 1/,/^## Phase 2/' skills/session-start/SKILL.md | grep -q 'Agent Teams Environment Check'
}

@test "AC1: Agent Teams env check is Phase 1-G (separate from Phase 1-D)" {
  grep -q '### G\. Agent Teams Environment Check' skills/session-start/SKILL.md
}

# ---------------------------------------------------------------------------
# AC2: Existing settings preserved
# ---------------------------------------------------------------------------

@test "AC2: session-start instructs to preserve existing env entries" {
  grep -q 'preserv' skills/session-start/SKILL.md
}

# ---------------------------------------------------------------------------
# AC3: settings.local.json non-existence handled
# ---------------------------------------------------------------------------

@test "AC3: session-start handles missing settings.local.json" {
  # The Phase 1-G block describes the Missing case explicitly with the word
  # "Missing →" (see settings.local.json branch table).
  awk '/^### G\. Agent Teams Environment Check/,/^## /' skills/session-start/SKILL.md \
    | grep -qE 'Missing →|Missing -'
}

# ---------------------------------------------------------------------------
# AC4: autopilot Prerequisites Check fallback guidance
# ---------------------------------------------------------------------------

@test "AC4: autopilot error message mentions CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" {
  grep -A 3 'not found' commands/autopilot.md | grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
}

@test "AC4: autopilot error message references settings.local.json" {
  grep -A 3 'not found' commands/autopilot.md | grep -q 'settings\.local\.json'
}

@test "AC4: autopilot error message instructs to restart session" {
  grep -A 3 'not found' commands/autopilot.md | grep -q 'restart\|new session'
}

# ---------------------------------------------------------------------------
# AC5: Documentation includes prerequisite
# ---------------------------------------------------------------------------

@test "AC5: autopilot Prerequisites lists env var" {
  grep -A 5 '## Prerequisites' commands/autopilot.md | grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
}

@test "AC5: workflow-detail.md mentions settings.local.json for env var" {
  grep -q 'settings\.local\.json' docs/workflow/workflow-detail.md
}

# ---------------------------------------------------------------------------
# Regression: no env var in committed settings.json
# ---------------------------------------------------------------------------

@test "Regression: settings.json does not contain CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" {
  ! grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' .claude/settings.json
}

@test "Regression: settings.local.json is gitignored" {
  grep -q 'settings\.local\.json' .gitignore
}

# ---------------------------------------------------------------------------
# Regression: Phase 3 report includes Agent Teams status
# ---------------------------------------------------------------------------

@test "Regression: Phase 3 report template includes Agent Teams line" {
  awk '/^## Phase 3: Summary Report/,/^### Task Recommendation/' skills/session-start/SKILL.md | grep -q 'Agent Teams'
}

# ---------------------------------------------------------------------------
# Regression: invalid JSON handling
# ---------------------------------------------------------------------------

@test "Regression: session-start handles invalid JSON in settings.local.json" {
  grep -q 'invalid JSON' skills/session-start/SKILL.md
}

# ---------------------------------------------------------------------------
# Regression: CHANGELOG and version
# ---------------------------------------------------------------------------

@test "Regression: CHANGELOG mentions Issue #2" {
  grep -q '#2' CHANGELOG.md
}

@test "Regression: plugin version is bumped from 1.0.0" {
  ! grep -q '"version": "1.0.0"' .claude-plugin/plugin.json
}
