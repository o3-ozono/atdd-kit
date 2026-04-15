---
description: "Autopilot end-to-end workflow. main Claude acts as orchestrator, driving discover → plan → implement → review → merge with task-type-specific Agent Teams."
---

# Autopilot — PO-Led End-to-End Workflow

The PO (Product Owner) acts as team-lead throughout, driving Issues end-to-end from discover through merge. Agent composition switches based on task type.

## Agent Composition Table

| Task Type | Phase 1 Agents | Phase 2 Agents |
|-----------|----------------|----------------|
| development | PO, Developer, QA | PO, Developer, Reviewer x N |
| bug | PO, Tester, Developer | PO, Developer, Tester, Reviewer x N |
| research | PO | PO, Researcher x N (min 2 per theme) |
| documentation | PO | PO, Writer, Reviewer x N |
| refactoring | PO | PO, Developer, Reviewer x N |

### Variable-Count Agents (Reviewer, Researcher)

Reviewer and Researcher agents have variable count (x N). The composition (count and focus/themes)
is determined during plan and approved as part of the `### Agent Composition` section in the plan comment.

When spawning Variable-Count Agents in Phase 3 or Phase 4:
1. Read the `### Agent Composition` section from the `## Implementation Plan` comment in the Issue
2. Spawn agents according to the approved composition directly — no additional user approval required
3. If the plan comment does not contain a `### Agent Composition` section: report error and STOP
   (see Autonomy Rules — failure mode: report what failed → STOP → user decides next step)

## Prerequisites
- `.claude/workflow-config.yml` must exist (if missing, start a new session to trigger auto-setup)
- Agent definitions must exist in `${CLAUDE_PLUGIN_ROOT}/agents/` (developer.md, qa.md, tester.md, reviewer.md, researcher.md, writer.md). main Claude acts as the PO orchestrator directly.
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` must be set in `.claude/settings.local.json` `env` (auto-configured by session-start)

## Usage

```
/atdd-kit:autopilot                  -> Auto-detect in-progress Issue
/atdd-kit:autopilot 123              -> Target Issue #123
/atdd-kit:autopilot search keywords  -> Search Issues by partial match
/atdd-kit:autopilot sweep            -> /atdd-kit:auto-sweep (one-shot utility)
/atdd-kit:autopilot eval             -> /atdd-kit:auto-eval (one-shot utility)
```

## Phase 0: Issue Resolution

**Tools:** Bash (gh)

Resolve which Issue to work on based on the argument.

### No argument (auto-detect)

When no argument is given, auto-detect the target Issue:

1. `gh issue list --label in-progress --state open --json number,title --jq '.[]'`
2. **0 results:** Error — "No in-progress Issue found. Specify an Issue number or keyword."  STOP.
3. **1 result:** Use that Issue automatically.
4. **Multiple results:** Present a numbered candidate list and ask the user to select:
   ```
   Multiple in-progress Issues found:
   1. #80 — feat: ...
   2. #87 — feat: ...
   Choose [1-N]:
   ```

### Numeric argument (Issue number)

When the argument is a number (e.g., `autopilot 123`):

1. `gh issue view <number> --json number,title,state`
2. If the Issue exists and is open: use it.
3. If not found or closed: error and STOP.

### Text argument (partial match search)

When the argument is not a number and not a subcommand (sweep/eval):

1. `gh issue list --state open --search "<text>" --json number,title --jq '.[]'`
2. **0 results:** Error — "No Issue found matching '<text>'." STOP.
3. **1 result:** Use that Issue automatically.
4. **Multiple results:** Present a numbered candidate list and ask the user to select.

## Phase 0.5: Phase and Task Type Determination

**Tools:** Bash (gh)

After resolving the target Issue, determine (a) which phase to start from and (b) the task type, based on the Issue's labels:

1. `gh issue view <number> --json labels --jq '[.labels[].name]'`

2. **Task type detection:** Extract the task type from labels (`type:development`, `type:bug`, `type:research`, `type:documentation`, `type:refactoring`). If no type label exists, default to `development`. The task type determines which agents to spawn (see Agent Composition Table above).

3. **Phase determination:** Match against the phase determination table (most advanced phase wins if multiple labels exist):

| Label State | Start Phase |
|-------------|-------------|
| `ready-for-PR-review` | Phase 4: PR Review |
| `needs-pr-revision` | Phase 3: Implementation (revision) |
| `implementing` | Phase 3: Implementation (continue) |
| `ready-to-go` | Phase 3: Implementation |
| `needs-plan-revision` | Phase 2: plan (recreate) |
| `ready-for-plan-review` | Phase 2: Plan Review Round |
| `in-progress` only (no phase label) | Phase 1: discover |
| No `in-progress` label | Phase 1: discover (will acquire lock) |

4. Skip to the determined phase. Do not re-execute earlier phases that are already complete.

## Phase 0.9: Agent Teams Setup

**Tools:** ToolSearch, TeamCreate, TeamDelete, EnterWorktree

Bootstrap the Agent Teams infrastructure before any phase execution. This phase must succeed — solo execution fallback is prohibited. Spawn agents based on the task type detected in Phase 0.5 (see Agent Composition Table).

1. Use ToolSearch to fetch full schemas for `TeamCreate`, `TeamDelete`, `SendMessage`, and `EnterWorktree` (deferred tools require explicit schema resolution before use)
2. Use TeamCreate to create team `autopilot-{issue_number}` — record the returned team_name for all subsequent Agent tool calls
3. Read agent definitions from `${CLAUDE_PLUGIN_ROOT}/agents/`. Available agents: developer.md, qa.md, tester.md, reviewer.md, researcher.md, writer.md. main Claude acts as the PO orchestrator directly. The system_prompt is the markdown body; the `tools` and `skills` fields in frontmatter control agent capabilities.
4. Use EnterWorktree with name `autopilot-{issue_number}` to enter an isolated worktree — all subsequent phases (1–5) execute inside this worktree
5. **Mid-phase resume:** If Phase 0.5 determined a start phase beyond AC Review Round, re-spawn the required agents for the task type before proceeding. Use the Agent Composition Table to determine which agents are needed for the current phase and task type. Load prior phase context by reading Issue/PR comments via `gh issue view` / `gh pr view`.
   - Phase 1 (discover) or AC Review Round: no re-spawn needed — agents are created in AC Review Round.
   - Phase 2+ : spawn agents required by the task type's Phase 1/2 composition.
   - **Phase 3 or Phase 4 resume:** Before proceeding, verify that the plan comment (containing `## Implementation Plan` with a `### Agent Composition` section) exists in the Issue. If the plan comment is absent, report: "plan is incomplete. Please re-run from Phase 2." and STOP. Do not proceed without an approved Agent Composition.
   Then proceed to the determined phase using SendMessage.
   Note: This mid-phase resume is the sole exception to Autonomy Rule 5 (Agent re-generation prohibition). It applies only when agents do not exist in the current session due to a session restart.
6. On failure at any step: report the error → STOP. Do NOT fall back to solo execution. See Autonomy Rules below.

## Output Channels (applies to all phases)

All agent output flows through two channels — never via repository files:

- **Inter-agent handoff** (e.g., QA strategy consumed by Developer): use `SendMessage`. Do not persist to files.
- **Human-facing work log** (AC confirmation, Plan conclusion, review results, research reports): post as Issue / PR comments via `gh issue comment` / `gh pr comment`.

Writing agent deliverables to `docs/decisions/` or any other repository path is prohibited. Curated knowledge that deserves long-term reference must be graduated into existing docs (`docs/`, `DEVELOPMENT.md`, etc.) by explicit human decision — not by agents automatically.

## Status Evaluation (SKILL_STATUS)

When PO receives a SendMessage reply from Developer, QA, or any agent that ran a skill, evaluate
the `skill-status` block in the message to determine the next action.

### Extraction Rule

Locate the **last** `skill-status` fenced code block in the received message. Parse the
`SKILL_STATUS` and `PHASE` fields. `RECOMMENDATION` is informational only — do not use it for
branching logic.

### Action Matrix

| SKILL_STATUS | Autopilot Next Action |
|---|---|
| `COMPLETE` | Proceed to next phase |
| `PENDING` | Wait for external input (user approval); do not advance to next phase |
| `BLOCKED` | Stop current phase. Post RECOMMENDATION as Issue comment. STOP and wait for user. |
| `FAILED` | Stop autopilot entirely. Post RECOMMENDATION as Issue comment. Report to user. |
| (any other value) | Treat as `PENDING` — do not advance |

### Fallback: No SKILL_STATUS Block Found

If the received message contains no `skill-status` block:

1. Post a warning Issue comment: "Agent returned output without SKILL_STATUS block. Manual verification required."
2. STOP. Do not advance to the next phase.
3. Report to user: which agent, which phase, and the raw message received.

Do NOT attempt to infer skill completion from message text. Only `skill-status` blocks are
authoritative.

See `docs/guides/skill-status-spec.md` for full format specification and field definitions.

## Autonomy Rules

The following execution patterns are **prohibited**. If any situation would trigger one of these patterns, the correct action is: report the failure to the user → STOP → wait for user decision.

1. **Solo execution** — PO must not execute Developer or QA responsibilities alone. All implementation requires a Developer agent; all review requires a QA agent.
2. **Explore subagent substitution** — Do not use Explore subagents as a replacement for Developer or QA agents. Explore subagents are for codebase research only, not for implementation or review.
3. **Self-executing skill steps** — When a skill is delegated to Developer or QA via Agent tool, PO must not execute that skill's steps directly. The skill must run inside the spawned agent.
4. **Context-priority execution** — Do not skip spawning an agent because "the context from a prior skill is already available." Each role must run in its own agent with its own system_prompt.
5. **Agent re-generation** — Once Developer and QA are spawned in AC Review Round, do not create new instances of these agents in Phase 2, Plan Review Round, Phase 3, or Phase 4. Communicate with existing agents exclusively via SendMessage. Exception: Phase 0.9 Mid-phase resume handles session-restart re-creation only.

Failure mode: report what failed → STOP → user decides next step.

## Phase 1: discover (PO leads)

**Tools:** Bash (gh), Skill

Discover the requirements for the Issue. Common to all task types.

1. `gh issue edit <number> --add-label in-progress` (exclusive lock)
2. Read the Issue body and comments for context
3. Use Skill tool to invoke `atdd-kit:discover` with args `"<number> --autopilot"` for the Issue
4. On `SKILL_STATUS: COMPLETE` from discover: **immediately proceed to AC Review Round. Do NOT present draft deliverables to the user or send any intermediate user-facing message.**

## AC Review Round

**Tools:** Agent, SendMessage

The PO and task-type-specific agents review draft ACs. Spawn agents according to the Phase 1 column of the Agent Composition Table.

### development / refactoring: Three Amigos (PO + Developer + QA)

1. Spawn Developer and QA in parallel for AC review (team_name: `autopilot-{issue_number}`, isolation: "worktree"):
   - **PO:** requirement completeness, alignment with user story, business value
   - **Developer:** architectural consistency, technical feasibility, edge cases, implementation complexity
   - **QA:** testability, boundary condition coverage, error cases, coverage gaps
   Each agent returns their review via `SendMessage` reply to PO.

### bug: PO + Tester + Developer (bug-triage)

1. Spawn Tester and Developer in parallel for bug triage:
   - **PO:** impact scope, priority determination
   - **Tester:** reproduction confirmation, test environment information
   - **Developer:** root cause hypothesis, fix approach
   Each agent returns their triage via `SendMessage` reply to PO.

### research / documentation: PO only

1. PO designs scope, DoD, theme breakdown, and agent count independently.

### Common (all task types)

2. PO collects review results from agents (via SendMessage replies)
3. PO integrates feedback and modifies ACs accordingly
4. Present final AC set to Stakeholder for approval with the message: "This is the final AC set incorporating all Three Amigos review results." This is the single approval point — discover's Step 7 approval was skipped in autopilot mode.
   - **Approve:** Proceed to step 5
   - **Reject:** PO modifies ACs based on user feedback and re-presents (do NOT restart the AC Review Round — PO corrects directly)
5. On approval: post final ACs as Issue comment with `gh issue comment` (this is the authoritative posting — discover did not post in autopilot mode)

## Phase 2: plan (PO orchestrates, Developer + QA lead their domains)

**Tools:** SendMessage, Skill

Developer leads the implementation strategy, QA leads the test strategy, and PO integrates both. Developer and QA agents were already spawned in AC Review Round — continue via SendMessage.

> **Constraint:** New agent creation is prohibited in this phase. Communicate with existing Developer/QA agents via SendMessage only (see Autonomy Rule 5).

1. Use SendMessage to: "Developer" with implementation strategy instructions. Include Issue number, approved AC set, and reference to the Issue comment containing prior phase context:
   - file structure, implementation order, dependencies, technical risks
   - Developer returns the strategy via SendMessage reply
2. Use SendMessage to: "QA" with test strategy instructions. Include Issue number, approved AC set, and reference to the Issue comment containing prior phase context:
   - test layer selection per AC (Unit/Integration/E2E), coverage strategy, regression risk analysis
   - QA returns the strategy via SendMessage reply
3. PO integrates both strategies into a unified Plan

## Plan Review Round

**Tools:** SendMessage

All three — PO, Developer, and QA — review the Plan. Developer and QA agents continue via SendMessage.

> **Constraint:** New agent creation is prohibited in this phase. Communicate with existing Developer/QA agents via SendMessage only (see Autonomy Rule 5).

1. Use SendMessage to: "Developer" and SendMessage to: "QA" in parallel for Plan review. Include Issue number, approved AC set, unified Plan, and reference to the Issue comment containing prior phase context:
   - **PO:** alignment with ACs, absence of scope creep
   - **Developer:** validity of file structure, risks in implementation order, technical risk assessment, adequacy of Agent Composition (concreteness of count and focus) — returns review via SendMessage reply
   - **QA:** validity of test layers (appropriate use of Unit/Integration/E2E), completeness of coverage strategy — returns review via SendMessage reply
2. PO collects and integrates review results (via SendMessage replies)
3. PO finalizes Plan (Stakeholder approval is NOT required for Plan)
4. Post Plan as Issue comment with `gh issue comment`
5. `gh issue edit <number> --add-label ready-to-go`
6. **Stop-point: clear or continue (same-session only)**
   This step runs only when Plan Review Round was executed in the current session. If autopilot reached this point via Phase 0.5 mid-phase resume (ready-to-go label already set at session start), this step is skipped.

   Use `AskUserQuestion` to present the following 2-option prompt:
   - **Question:** "Plan has been approved and `ready-to-go` label has been set. Context usage may be high. Would you like to clear the session and resume from Phase 3 in a fresh context, or continue to Phase 3 now?"
   - **Option 1:** "Clear and end — clear this session, then run `/atdd-kit:autopilot <N>` to resume from Phase 3"
   - **Option 2:** "Continue — proceed to Phase 3 now (existing behavior)"

   If `AskUserQuestion` is not resolvable at runtime, output the 2 options as plain text and STOP until the user responds.

   **Fallback for AskUserQuestion unavailability:**
   ```
   Plan approved. Choose how to proceed:
   1. Clear and end — clear this session, then run `/atdd-kit:autopilot <N>` to resume from Phase 3
   2. Continue — proceed to Phase 3 now
   Reply with 1 or 2.
   ```
   STOP and wait for user response.

   **On user response:**
   - **"Clear and end" / Option 1:** Print the following and terminate autopilot entirely (do NOT proceed to Phase 3 or any subsequent phase):
     ```
     Session cleared. To resume, run `/atdd-kit:autopilot <N>` in a new session.
     Phase 0.5 will detect the `ready-to-go` label and start directly from Phase 3.
     ```
   - **"Continue" / Option 2:** Proceed to Phase 3 with no additional steps (existing behavior preserved).
   - **Other / unclassifiable response:** Follow Autonomy Rules failure mode — report "Response could not be classified as clear or continue." → STOP. Do NOT auto-select either option.

## Phase 3: Implementation (task-type-specific)

**Tools:** SendMessage, Skill

> **Constraint:** New agent creation is prohibited in this phase (except variable-count agents per plan-approved Agent Composition). Communicate with existing agents via SendMessage only (see Autonomy Rule 5).

### development / refactoring: Developer implements

1. Use SendMessage to: "Developer" with ATDD implementation instructions. Include Issue number, approved AC set, unified Plan, and reference to the Issue comments containing prior phase context — Developer uses Skill tool to invoke `atdd-kit:atdd` with args `"<number> --autopilot"`
2. Developer creates branch, Draft PR, and implements AC by AC
3. Developer uses Skill tool to invoke `atdd-kit:verify` after all ACs are complete
4. Developer marks PR as ready and adds `ready-for-PR-review` label

### bug: Developer fixes + Tester verifies

1. Developer implements fix using ATDD (same as development)
2. Tester verifies the fix by reproducing the original bug and confirming it no longer occurs
3. Developer marks PR as ready and adds `ready-for-PR-review` label

### research: Researcher x N investigates (min 2 per theme)

1. PO spawns Researcher agents (variable count, per plan-approved Agent Composition)
2. Each Researcher investigates their assigned theme and returns findings via SendMessage reply to PO
3. PO synthesizes findings into a unified research report and posts it as an Issue / PR comment

### documentation: Writer creates

1. Writer creates/updates documentation based on approved plan
2. Writer marks PR as ready and adds `ready-for-PR-review` label

## Phase 4: PR Review (task-type-specific)

**Tools:** SendMessage

> **Constraint:** New agent creation is prohibited in this phase (except variable-count Reviewer agents per plan-approved Agent Composition). Communicate with existing agents via SendMessage only (see Autonomy Rule 5).

### development / bug / documentation / refactoring: Reviewer x N

1. PO spawns Reviewer agents (variable count, per plan-approved Agent Composition — see Variable-Count Agents section)
2. Each Reviewer reviews from their assigned perspective and returns results via SendMessage reply to PO. PO then posts the consolidated review as a PR comment.
3. PO collects results:
   - If issues found: PO adds `needs-pr-revision`, Developer/Writer fixes
   - If no issues: PO posts review PASS comment

### research: PO reviews

1. PO reviews the synthesized research report for completeness against DoD items
2. If gaps found: PO sends Researchers back to investigate
3. If complete: PO posts review PASS comment

## Phase 5: PO Cross-Cutting Checks and Merge Decision

**Tools:** Bash (gh), ExitWorktree, TeamDelete

The PO performs cross-cutting checks and makes the merge decision.

1. **Verify QA review PASS:**
   - Run: `gh pr view <PR> --json comments --jq '.comments[].body'` and check for review PASS comment
   - If no PASS comment found: STOP. Do NOT proceed to merge. Report: "QA review PASS not confirmed. Returning to Phase 4."
   - If PASS comment confirmed: proceed to Step 2
2. Check CI status: `gh pr view <PR> --json statusCheckRollup`
3. **Check merge conflicts:** `gh pr view <PR> --json mergeable`
   - If `mergeable == CONFLICTING`:
     - Do NOT propose merge
     - Post warning: "⚠ PR has merge conflicts with main. Rebase required."
     - Guide rebase steps:
       ```bash
       git fetch origin main
       git checkout <branch>
       git rebase origin/main
       # After resolving conflicts
       git push --force-with-lease
       ```
     - After rebase: return to Phase 4 (QA re-review)
   - If `mergeable == MERGEABLE`: proceed to merge
4. Merge with squash: `gh pr merge <PR> --squash`
5. Remove `in-progress` label from Issue
6. Exit worktree: use ExitWorktree with action: "remove" to delete the worktree and return to the repository root
7. Delete team: use TeamDelete to remove the `autopilot-{issue_number}` team and its task list
8. Cleanup: `git checkout main && git pull origin main`

## Utility Mode

**Tools:** Skill

For running one-shot utilities directly:

```
/atdd-kit:autopilot sweep   -> /atdd-kit:auto-sweep
/atdd-kit:autopilot eval    -> /atdd-kit:auto-eval
```

## Session Initialization

### Prerequisites Check

**Tools:** ToolSearch, Read

Before launching autopilot, verify the Agent Teams prerequisites:

1. `.claude/workflow-config.yml` exists
   - If missing: suggest starting a new session to trigger auto-setup
2. Verify agent definitions exist in `${CLAUDE_PLUGIN_ROOT}/agents/` (developer.md, qa.md)
3. Verify Agent Teams tools are available: use ToolSearch to confirm `TeamCreate` and `SendMessage` are resolvable
   - If unavailable: STOP — "Agent Teams tools (TeamCreate, SendMessage) not found. Verify that `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set in `.claude/settings.local.json` `env`, then restart the session."

### Initialization

1. `git checkout main && git pull origin main` to update
2. Read agent definitions from `${CLAUDE_PLUGIN_ROOT}/agents/`
3. Launch the selected mode
