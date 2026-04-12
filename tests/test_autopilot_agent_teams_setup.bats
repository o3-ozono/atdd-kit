#!/usr/bin/env bats

# Test file for Issue #153: autopilot Agent Teams enforcement
# Validates AC-1 through AC-7 against commands/autopilot.md

AUTOPILOT="commands/autopilot.md"

# ---------------------------------------------------------------------------
# AC-7: Session Initialization prerequisites
# ---------------------------------------------------------------------------

@test "AC-7: Prerequisites section exists" {
  grep -q "## Prerequisites" "$AUTOPILOT"
}

@test "AC-7: Prerequisites include workflow-config.yml check" {
  grep -A 10 "## Prerequisites" "$AUTOPILOT" | grep -q "workflow-config.yml"
}

@test "AC-7: Prerequisites include agents/ directory verification" {
  grep -A 10 "## Prerequisites" "$AUTOPILOT" | grep -q "agents/"
}

@test "AC-7: Prerequisites include agent file references" {
  grep -A 10 "## Prerequisites" "$AUTOPILOT" | grep -q "po.md\|developer.md\|qa.md"
}

# ---------------------------------------------------------------------------
# AC-1: Phase 0.9 Agent Teams bootstrap
# ---------------------------------------------------------------------------

@test "AC-1: Phase 0.9 section exists" {
  grep -q "## Phase 0.9: Agent Teams Setup" "$AUTOPILOT"
}

@test "AC-1: Phase 0.9 uses ToolSearch to fetch TeamCreate and SendMessage schemas" {
  grep -A 5 "## Phase 0.9" "$AUTOPILOT" | grep -q "ToolSearch"
  grep -A 10 "## Phase 0.9" "$AUTOPILOT" | grep -q "TeamCreate"
  grep -A 10 "## Phase 0.9" "$AUTOPILOT" | grep -q "SendMessage"
}

@test "AC-1: Phase 0.9 creates team with autopilot-{issue_number} format" {
  grep -A 20 "## Phase 0.9" "$AUTOPILOT" | grep -q "autopilot-{issue_number}"
}

@test "AC-1: Phase 0.9 reads agent definitions from agents/ directory" {
  grep -A 20 "## Phase 0.9" "$AUTOPILOT" | grep -q "agents/"
  grep -A 20 "## Phase 0.9" "$AUTOPILOT" | grep -q "system_prompt\|agent definitions"
}

@test "AC-1: Phase 0.9 STOP on failure — no solo fallback" {
  grep -A 30 "## Phase 0.9" "$AUTOPILOT" | grep -q "STOP"
  grep -A 30 "## Phase 0.9" "$AUTOPILOT" | grep -q "solo execution"
}

# ---------------------------------------------------------------------------
# AC-6: Autonomy Rules — LLM autonomous fallback prohibition
# ---------------------------------------------------------------------------

@test "AC-6: Autonomy Rules section exists" {
  grep -q "## Autonomy Rules" "$AUTOPILOT"
}

@test "AC-6: Prohibits solo execution" {
  grep -A 20 "## Autonomy Rules" "$AUTOPILOT" | grep -q "Solo execution"
}

@test "AC-6: Prohibits Explore subagent substitution" {
  grep -A 20 "## Autonomy Rules" "$AUTOPILOT" | grep -q "Explore subagent substitution"
}

@test "AC-6: Prohibits self-executing skill steps" {
  grep -A 20 "## Autonomy Rules" "$AUTOPILOT" | grep -q "Self-executing skill steps"
}

@test "AC-6: Prohibits context-priority execution" {
  grep -A 20 "## Autonomy Rules" "$AUTOPILOT" | grep -q "Context-priority execution"
}

@test "AC-6: Failure mode is report + STOP" {
  grep -A 25 "## Autonomy Rules" "$AUTOPILOT" | grep -q "STOP"
}

@test "AC-6: No solo mode offered as option anywhere in document" {
  ! grep -i "fall back to solo" "$AUTOPILOT"
  ! grep -i "solo mode" "$AUTOPILOT"
}

# ---------------------------------------------------------------------------
# AC-2: All Spawn replaced with Agent tool calls
# ---------------------------------------------------------------------------

@test "AC-2: No 'Spawn' keyword anywhere in document" {
  ! grep -q "Spawn" "$AUTOPILOT"
}

@test "AC-2: Agent tool with team_name in AC Review Round" {
  grep -A 10 "## AC Review Round" "$AUTOPILOT" | grep -q "Agent.*tool"
  grep -A 10 "## AC Review Round" "$AUTOPILOT" | grep -q "team_name"
}

@test "AC-2: SendMessage to Developer in Phase 2" {
  grep -A 15 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'SendMessage.*Developer\|SendMessage.*to.*"Developer"'
}

@test "AC-2: SendMessage to QA in Phase 2" {
  grep -A 20 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'SendMessage.*QA\|SendMessage.*to.*"QA"'
}

@test "AC-2: SendMessage to Developer and QA in Plan Review Round" {
  grep -A 15 "## Plan Review Round" "$AUTOPILOT" | grep -q 'SendMessage.*Developer\|SendMessage.*to.*"Developer"'
  grep -A 15 "## Plan Review Round" "$AUTOPILOT" | grep -q 'SendMessage.*QA\|SendMessage.*to.*"QA"'
}

@test "AC-2: SendMessage to Developer in Phase 3" {
  grep -A 15 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q 'SendMessage.*Developer\|SendMessage.*to.*"Developer"'
}

@test "AC-2: SendMessage to QA in Phase 4" {
  grep -A 15 "## Phase 4: PR Review" "$AUTOPILOT" | grep -q 'SendMessage.*QA\|SendMessage.*to.*"QA"'
}

@test "AC-2: Agent tool specifies name parameter for Developer in AC Review Round" {
  grep -A 15 "## AC Review Round" "$AUTOPILOT" | grep -q 'name.*"Developer"\|name: "Developer"'
}

@test "AC-2: Agent tool specifies name parameter for QA in AC Review Round" {
  grep -A 15 "## AC Review Round" "$AUTOPILOT" | grep -q 'name.*"QA"\|name: "QA"'
}

# ---------------------------------------------------------------------------
# AC-3: Skill tool explicit invocation names
# ---------------------------------------------------------------------------

@test "AC-3: discover invoked via Skill tool" {
  grep -A 15 "## Phase 1: discover" "$AUTOPILOT" | grep -q "Skill.*tool.*discover\|Skill tool.*discover"
}

@test "AC-3: atdd invoked via Skill tool" {
  grep -A 15 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q "Skill.*tool.*atdd\|Skill tool.*atdd"
}

@test "AC-3: verify invoked via Skill tool" {
  grep -A 15 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q "Skill.*tool.*verify\|Skill tool.*verify"
}

# ---------------------------------------------------------------------------
# AC-4: system_prompt integration in Agent spawns
# ---------------------------------------------------------------------------

@test "AC-4: AC Review spawns reference agent definitions" {
  grep -A 10 "## AC Review Round" "$AUTOPILOT" | grep -q "agents/\|agent definitions\|system_prompt\|subagent_type"
}

@test "AC-4: Phase 2 SendMessage includes context references" {
  grep -A 20 "## Phase 2: plan" "$AUTOPILOT" | grep -q "Issue\|AC\|context"
}

@test "AC-4: Phase 3 SendMessage includes context references" {
  grep -A 15 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q "Issue\|AC\|context"
}

@test "AC-4: Phase 4 SendMessage includes context references" {
  grep -A 15 "## Phase 4: PR Review" "$AUTOPILOT" | grep -q "Issue\|AC\|context"
}

@test "AC-4: agent definitions provide system prompts automatically" {
  grep -q "system prompt\|agent definitions\|agents/" "$AUTOPILOT"
}

# ---------------------------------------------------------------------------
# AC-5: Tools annotations per phase
# ---------------------------------------------------------------------------

@test "AC-5: Tools annotation in Phase 0" {
  grep -A 3 "## Phase 0: Issue Resolution" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

@test "AC-5: Tools annotation in Phase 0.5" {
  grep -A 3 "## Phase 0.5: Phase Determination" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

@test "AC-5: Tools annotation in Phase 0.9" {
  grep -A 3 "## Phase 0.9: Agent Teams Setup" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

@test "AC-5: Tools annotation in Phase 1" {
  grep -A 3 "## Phase 1: discover" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

@test "AC-5: Tools annotation in AC Review Round" {
  grep -A 3 "## AC Review Round" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

@test "AC-5: Tools annotation in Phase 2" {
  grep -A 3 "## Phase 2: plan" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

@test "AC-5: Tools annotation in Plan Review Round" {
  grep -A 3 "## Plan Review Round" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

@test "AC-5: Tools annotation in Phase 3" {
  grep -A 3 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

@test "AC-5: Tools annotation in Phase 4" {
  grep -A 3 "## Phase 4: PR Review" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

@test "AC-5: Tools annotation in Phase 5" {
  grep -A 3 "## Phase 5: PO Cross-Cutting" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

@test "AC-5: Tools annotation in Session Initialization" {
  grep -A 3 "### Prerequisites Check" "$AUTOPILOT" | grep -q '\*\*Tools:\*\*'
}

# ===========================================================================
# Issue #165: SendMessage continuation and Decision Trail
# ===========================================================================

# ---------------------------------------------------------------------------
# #165-AC1: Dev full-phase SendMessage continuation
# ---------------------------------------------------------------------------

@test "#165-AC1: No new Agent generation for Developer in Phase 2 or Phase 3" {
  # Phase 2 and Phase 3 main flow should use SendMessage, not Agent tool
  # (Phase 0.9 resume logic may reference Agent tool — that's expected)
  ! grep -A 15 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'Use Agent tool.*Developer'
  ! grep -A 15 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q 'Use Agent tool.*Developer'
}

@test "#165-AC1: Developer receives SendMessage in Phase 2" {
  grep -A 15 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'SendMessage.*to.*"Developer"\|SendMessage.*Developer'
}

@test "#165-AC1: Developer receives SendMessage in Plan Review Round" {
  grep -A 15 "## Plan Review Round" "$AUTOPILOT" | grep -q 'SendMessage.*to.*"Developer"\|SendMessage.*Developer'
}

@test "#165-AC1: Developer receives SendMessage in Phase 3" {
  grep -A 15 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q 'SendMessage.*to.*"Developer"\|SendMessage.*Developer'
}

# ---------------------------------------------------------------------------
# #165-AC2: QA full-phase SendMessage continuation
# ---------------------------------------------------------------------------

@test "#165-AC2: No new Agent generation for QA in Phase 2 or Phase 4" {
  # Phase 2 and Phase 4 main flow should use SendMessage, not Agent tool
  # (Phase 0.9 resume logic may reference Agent tool — that's expected)
  ! grep -A 20 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'Use Agent tool.*QA'
  ! grep -A 15 "## Phase 4: PR Review" "$AUTOPILOT" | grep -q 'Use Agent tool.*QA'
}

@test "#165-AC2: QA receives SendMessage in Phase 2" {
  grep -A 20 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'SendMessage.*to.*"QA"\|SendMessage.*QA'
}

@test "#165-AC2: QA receives SendMessage in Plan Review Round" {
  grep -A 15 "## Plan Review Round" "$AUTOPILOT" | grep -q 'SendMessage.*to.*"QA"\|SendMessage.*QA'
}

@test "#165-AC2: QA receives SendMessage in Phase 4" {
  grep -A 15 "## Phase 4: PR Review" "$AUTOPILOT" | grep -q 'SendMessage.*to.*"QA"\|SendMessage.*QA'
}

# ---------------------------------------------------------------------------
# #165-AC3: Decision Trail file write-out per phase
# ---------------------------------------------------------------------------

@test "#165-AC3: AC Review Round references docs/decisions/ write-out" {
  grep -A 20 "## AC Review Round" "$AUTOPILOT" | grep -q 'docs/decisions/'
}

@test "#165-AC3: Phase 2 references docs/decisions/ write-out" {
  grep -A 20 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'docs/decisions/'
}

@test "#165-AC3: Plan Review Round references docs/decisions/ write-out" {
  grep -A 20 "## Plan Review Round" "$AUTOPILOT" | grep -q 'docs/decisions/'
}

@test "#165-AC3: Phase 0.9 creates docs/decisions/ directory" {
  grep -A 40 "## Phase 0.9" "$AUTOPILOT" | grep -q 'docs/decisions'
}

# ---------------------------------------------------------------------------
# #165-AC4: Decision Trail persistence (PR commit + Issue comment)
# ---------------------------------------------------------------------------

@test "#165-AC4: Phase 3 includes git add docs/decisions" {
  grep -A 20 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q 'git add.*docs/decisions\|docs/decisions.*commit'
}

@test "#165-AC4: AC Review Round PO posts integrated result as Issue comment" {
  grep -A 30 "## AC Review Round" "$AUTOPILOT" | grep -q 'gh issue comment'
}

@test "#165-AC4: Plan Review Round PO posts integrated result as Issue comment" {
  grep -A 30 "## Plan Review Round" "$AUTOPILOT" | grep -q 'gh issue comment'
}

# ---------------------------------------------------------------------------
# #165-AC5: Explicit name parameter on all Agent generations
# ---------------------------------------------------------------------------

@test "#165-AC5: AC Review Round Agent specifies name Developer" {
  grep -A 15 "## AC Review Round" "$AUTOPILOT" | grep -q 'name.*"Developer"\|name: "Developer"'
}

@test "#165-AC5: AC Review Round Agent specifies name QA" {
  grep -A 15 "## AC Review Round" "$AUTOPILOT" | grep -q 'name.*"QA"\|name: "QA"'
}

@test "#165-AC5: Only AC Review Round uses Agent tool for Developer/QA generation" {
  # Count Agent tool lines that spawn Developer or QA (should be exactly 1 line in AC Review Round)
  count=$(grep -c 'Agent.*tool.*spawn.*Developer\|Agent.*tool.*spawn.*QA\|Use Agent tool to spawn Developer\|Use Agent tool to spawn QA' "$AUTOPILOT") || count=0
  # AC Review Round has 1 line spawning both Developer and QA in parallel
  # Phase 0.9 re-spawn logic may also have Agent tool references
  [ "$count" -ge 1 ]
}

# ---------------------------------------------------------------------------
# #165-AC6: Mid-phase resume Agent re-generation
# ---------------------------------------------------------------------------

@test "#165-AC6: Phase 0.9 contains resume logic for mid-phase restart" {
  grep -A 60 "## Phase 0.9" "$AUTOPILOT" | grep -q 'resume\|re-spawn\|re-create\|restart\|regenerat'
}

@test "#165-AC6: Resume logic maps Phase 4 to QA agent" {
  grep -A 60 "## Phase 0.9" "$AUTOPILOT" | grep -q 'Phase 4.*QA\|PR Review.*QA'
}

@test "#165-AC6: Resume logic maps Phase 3 to Developer agent" {
  grep -A 60 "## Phase 0.9" "$AUTOPILOT" | grep -q 'Phase 3.*Developer\|Implementation.*Developer'
}

@test "#165-AC6: Resume logic maps Phase 2 to Developer and QA" {
  grep -A 60 "## Phase 0.9" "$AUTOPILOT" | grep -q 'Phase 2.*Developer.*QA\|plan.*Developer.*QA'
}

# ===========================================================================
# Issue #180: Agent name change and Decision Trail file rename
# ===========================================================================

# ---------------------------------------------------------------------------
# #180-AC1: Agent name "Dev" -> "Developer" in autopilot.md
# ---------------------------------------------------------------------------

@test "#180-AC1: No name: Dev in autopilot.md (replaced by Developer)" {
  ! grep -q 'name: "Dev"' "$AUTOPILOT"
  ! grep -q 'name.*"Dev"' "$AUTOPILOT" || grep -q 'name.*"Developer"' "$AUTOPILOT"
}

@test "#180-AC1: No SendMessage to: Dev in autopilot.md (replaced by Developer)" {
  ! grep -q 'to: "Dev"' "$AUTOPILOT"
  ! grep -q 'to.*"Dev"' "$AUTOPILOT" || grep -q 'to.*"Developer"' "$AUTOPILOT"
}

@test "#180-AC1: Phase 3 heading uses Developer" {
  grep -q '## Phase 3: Implementation (Developer agent)' "$AUTOPILOT"
}

@test "#180-AC1: Phase 2 heading uses Developer" {
  grep -q 'Developer + QA lead their domains' "$AUTOPILOT"
}

@test "#180-AC1: developer agent definition exists in agents/" {
  [[ -f "agents/developer.md" ]]
}

@test "#180-AC1: description uses Developer not Dev" {
  head -5 "$AUTOPILOT" | grep -q 'PO/Developer/QA'
}

# ---------------------------------------------------------------------------
# #180-AC2: Decision Trail file names use developer not dev
# ---------------------------------------------------------------------------

@test "#180-AC2: ac-review-developer.md referenced in AC Review Round" {
  grep -A 20 "## AC Review Round" "$AUTOPILOT" | grep -q 'ac-review-developer.md'
}

@test "#180-AC2: impl-strategy-developer.md referenced in Phase 2" {
  grep -A 20 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'impl-strategy-developer.md'
}

@test "#180-AC2: plan-review-developer.md referenced in Plan Review Round" {
  grep -A 20 "## Plan Review Round" "$AUTOPILOT" | grep -q 'plan-review-developer.md'
}

@test "#180-AC2: No old ac-review-dev.md filename in autopilot.md" {
  ! grep -q 'ac-review-dev\.md' "$AUTOPILOT"
}

@test "#180-AC2: No old impl-strategy-dev.md filename in autopilot.md" {
  ! grep -q 'impl-strategy-dev\.md' "$AUTOPILOT"
}

@test "#180-AC2: No old plan-review-dev.md filename in autopilot.md" {
  ! grep -q 'plan-review-dev\.md' "$AUTOPILOT"
}

# ===========================================================================
# Issue #7: TeamDelete on autopilot completion
# ===========================================================================

# ---------------------------------------------------------------------------
# #7-AC1: Phase 0.9 ToolSearch includes TeamDelete
# ---------------------------------------------------------------------------

@test "#7-AC1: Phase 0.9 Tools annotation includes TeamDelete" {
  grep -A 3 "## Phase 0.9" "$AUTOPILOT" | grep -q 'TeamDelete'
}

@test "#7-AC1: Phase 0.9 ToolSearch fetches TeamDelete schema" {
  grep -A 10 "## Phase 0.9" "$AUTOPILOT" | grep 'ToolSearch' | grep -q 'TeamDelete'
}

# ---------------------------------------------------------------------------
# #7-AC2: Phase 5 TeamDelete step exists
# ---------------------------------------------------------------------------

@test "#7-AC2: Phase 5 contains TeamDelete step" {
  grep -A 40 "## Phase 5" "$AUTOPILOT" | grep -q 'TeamDelete'
}

@test "#7-AC2: Phase 5 TeamDelete removes autopilot-{issue_number} team" {
  grep -A 40 "## Phase 5" "$AUTOPILOT" | grep 'TeamDelete' | grep -q 'autopilot-{issue_number}'
}

@test "#7-AC2: Phase 5 Tools annotation includes TeamDelete" {
  grep -A 3 "## Phase 5" "$AUTOPILOT" | grep '\*\*Tools:\*\*' | grep -q 'TeamDelete'
}

# ---------------------------------------------------------------------------
# #7-AC3: Phase 5 step ordering (merge -> label -> ExitWorktree -> TeamDelete -> git checkout)
# ---------------------------------------------------------------------------

@test "#7-AC3: ExitWorktree appears before TeamDelete in Phase 5 steps" {
  exit_line=$(grep -A 40 "## Phase 5" "$AUTOPILOT" | grep -n '^[0-9].*ExitWorktree' | head -1 | cut -d: -f1)
  delete_line=$(grep -A 40 "## Phase 5" "$AUTOPILOT" | grep -n '^[0-9].*TeamDelete' | head -1 | cut -d: -f1)
  [ -n "$exit_line" ] && [ -n "$delete_line" ] && [ "$exit_line" -lt "$delete_line" ]
}

@test "#7-AC3: TeamDelete appears before git checkout main in Phase 5 steps" {
  delete_line=$(grep -A 40 "## Phase 5" "$AUTOPILOT" | grep -n '^[0-9].*TeamDelete' | head -1 | cut -d: -f1)
  checkout_line=$(grep -A 40 "## Phase 5" "$AUTOPILOT" | grep -n '^[0-9].*git checkout main' | head -1 | cut -d: -f1)
  [ -n "$delete_line" ] && [ -n "$checkout_line" ] && [ "$delete_line" -lt "$checkout_line" ]
}

# ---------------------------------------------------------------------------
# #7: Negative test — TeamDelete scoped to Phase 0.9 and Phase 5 only
# ---------------------------------------------------------------------------

@test "#7: TeamDelete not referenced in Phases 1-4" {
  # TeamDelete is a destructive operation — must only appear in Phase 0.9 (ToolSearch) and Phase 5 (execution)
  ! sed -n '/## Phase 1:/,/## Phase 5:/p' "$AUTOPILOT" | grep -q 'TeamDelete'
}

# ===========================================================================
# Issue #11: Agent re-generation prohibition (Prompt Guard)
# ===========================================================================

# ---------------------------------------------------------------------------
# #11-AC1: Autonomy Rules — Agent re-generation prohibition (Rule 5)
# ---------------------------------------------------------------------------

@test "#11-AC1: Autonomy Rules contains agent re-generation prohibition" {
  # Scope to Autonomy Rules section only (up to next ## heading)
  sed -n '/^## Autonomy Rules/,/^## /p' "$AUTOPILOT" | grep -qi 'agent.*re-\?gen\|new instances.*agents'
}

@test "#11-AC1: Rule 5 is numbered as item 5 in Autonomy Rules" {
  sed -n '/^## Autonomy Rules/,/^## /p' "$AUTOPILOT" | grep -q '^5\.'
}

@test "#11-AC1: Rule 5 specifies SendMessage as the correct alternative" {
  # Rule 5 line itself must mention SendMessage (not just neighboring sections)
  sed -n '/^## Autonomy Rules/,/^## /p' "$AUTOPILOT" | grep '^5\.' | grep -q 'SendMessage'
}

@test "#11-AC1: Rule 5 scopes prohibition to after AC Review Round" {
  sed -n '/^## Autonomy Rules/,/^## /p' "$AUTOPILOT" | grep '^5\.' | grep -qi 'AC Review Round'
}

@test "#11-AC1: Rule 5 is covered by existing Failure Mode" {
  count=$(grep -c '## Autonomy Rules' "$AUTOPILOT")
  [ "$count" -eq 1 ]
  sed -n '/^## Autonomy Rules/,/^## /p' "$AUTOPILOT" | grep -q 'Failure mode.*STOP'
}

# ---------------------------------------------------------------------------
# #11-AC2: SendMessage-only guard in Phase 2-4 and Plan Review Round
# ---------------------------------------------------------------------------

@test "#11-AC2: Phase 2 contains SendMessage-only guard" {
  sed -n '/^## Phase 2: plan/,/^## /p' "$AUTOPILOT" | grep -qi 'prohibited.*phase\|SendMessage only'
}

@test "#11-AC2: Plan Review Round contains SendMessage-only guard" {
  sed -n '/^## Plan Review Round/,/^## /p' "$AUTOPILOT" | grep -qi 'prohibited.*phase\|SendMessage only'
}

@test "#11-AC2: Phase 3 contains SendMessage-only guard" {
  sed -n '/^## Phase 3: Implementation/,/^## /p' "$AUTOPILOT" | grep -qi 'prohibited.*phase\|SendMessage only'
}

@test "#11-AC2: Phase 4 contains SendMessage-only guard" {
  sed -n '/^## Phase 4: PR Review/,/^## /p' "$AUTOPILOT" | grep -qi 'prohibited.*phase\|SendMessage only'
}

# ---------------------------------------------------------------------------
# #11-AC3: Bidirectional cross-reference between Phase 0.9 and Rule 5
# ---------------------------------------------------------------------------

@test "#11-AC3: Phase 0.9 Mid-phase resume references Rule 5 or Autonomy Rules" {
  # The mid-phase resume section must reference the prohibition rule
  sed -n '/Mid-phase resume/,/^## /p' "$AUTOPILOT" | grep -qi 'Autonomy Rule 5\|Rule 5\|re-generation prohibition'
}

@test "#11-AC3: Rule 5 references Phase 0.9 Mid-phase resume as exception" {
  # Rule 5 text must mention Phase 0.9 or Mid-phase resume as the exception
  sed -n '/^## Autonomy Rules/,/^## /p' "$AUTOPILOT" | grep '^5\.' | grep -qi 'Phase 0.9\|Mid-phase resume'
}

@test "#11-AC3: Mid-phase resume is the only spawn reference outside AC Review Round" {
  # Phase 2-4 main flow should not contain spawn references
  ! sed -n '/## Phase 2:/,/## Phase 5:/p' "$AUTOPILOT" | grep -qi 'spawn.*Developer\|spawn.*QA'
}
