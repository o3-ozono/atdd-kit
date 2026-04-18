---
description: "Autopilot end-to-end workflow. main Claude acts as orchestrator, driving discover → plan → implement → review → merge with task-type-specific Agent Teams."
---

# Autopilot — PO-Led End-to-End Workflow

PO drives Issues end-to-end from discover through merge. Agent composition switches by task type.

## Agent Composition Table

| Task Type | Phase 1 Agents | Phase 2 Agents |
|-----------|----------------|----------------|
| development | PO, Developer, QA | PO, Developer, Reviewer x N |
| bug | PO, Tester, Developer | PO, Developer, Tester, Reviewer x N |
| research | PO | PO, Researcher x N (min 2 per theme) |
| documentation | PO | PO, Writer, Reviewer x N |
| refactoring | PO | PO, Developer, Reviewer x N |

### Variable-Count Agents (Reviewer, Researcher)

Count and focus/themes are determined during plan in the `### Agent Composition` section.

When spawning Variable-Count Agents in Phase 3 or Phase 4:
1. Read `### Agent Composition` from the `## Implementation Plan` Issue comment
2. Spawn per approved composition — no additional user approval required
3. If `### Agent Composition` is absent: report error and STOP (see Autonomy Rules)

> **Phase 5 note:** research tasks skip PR verify/merge steps. Phase 5 routes directly to
> deliverable classification → issue create/comment → closing comment → issue close → label removal → ExitWorktree/TeamDelete.

## Prerequisites
- `.claude/workflow-config.yml` must exist (if missing, start a new session to trigger auto-setup)
- Agent definitions in `${CLAUDE_PLUGIN_ROOT}/agents/` (developer.md, qa.md, tester.md, reviewer.md, researcher.md, writer.md). main Claude acts as PO.
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` `env` (auto-configured by session-start)

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

### No argument (auto-detect)

1. `gh issue list --label in-progress --state open --json number,title --jq '.[]'`
2. **0 results:** Error — "No in-progress Issue found." STOP.
3. **1 result:** Use it.
4. **Multiple results:** Present numbered list, ask user to select.

### Numeric argument (Issue number)

1. `gh issue view <number> --json number,title,state`
2. Open → use it. Not found or closed → error and STOP.

### Text argument (partial match search)

1. `gh issue list --state open --search "<text>" --json number,title --jq '.[]'`
2. **0 results:** Error — "No Issue found matching '<text>'." STOP.
3. **1 result:** Use it.
4. **Multiple results:** Present numbered list, ask user to select.

## Phase 0.5: Phase and Task Type Determination

**Tools:** Bash (gh)

1. `gh issue view <number> --json labels --jq '[.labels[].name]'`
2. **Task type:** Extract from labels (`type:development`, `type:bug`, `type:research`, `type:documentation`, `type:refactoring`). Default: `development`.
3. **Phase determination** (most advanced label wins):

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

4. Skip to the determined phase.

## Phase 0.8: Persona Prerequisite Check

**Tools:** Bash

Runs **before** Phase 0.9 (TeamCreate / EnterWorktree) so we fail fast without leaking Teams or worktrees when `docs/personas/` is empty. See `docs/methodology/persona-guide.md` "Autopilot Requirements" for rationale.

Applicability (persona-required flows only):

| Task type (from Phase 0.5) | Check applies? |
|----------------------------|----------------|
| `development` | Yes |
| `bug` | Yes |
| `refactoring` | No (external behavior unchanged — no persona required) |
| `research` | No (not user-facing) |
| `documentation` | No (not user-facing) |

**Mid-phase resume skip:** Skip this check when Phase 0.5 determined the start phase to be `ready-to-go`, `implementing`, `needs-plan-revision`, `ready-for-PR-review`, or `needs-pr-revision` — persona selection already happened during Phase 1 and cannot be retro-actively required.

Procedure:

1. If task type is not persona-required, skip and continue to Phase 0.9.
2. If Phase 0.5 start phase matches the mid-phase resume list above, skip and continue.
3. Otherwise, run the valid-persona count using the shared helper:

   ```bash
   count=$(bash lib/persona_check.sh count_valid_personas docs/personas)
   if [ "$count" -eq 0 ]; then
     guidance=$(bash lib/persona_check.sh get_persona_guidance_message)
     gh issue comment <number> --body "$guidance"
     printf '%s\n' "$guidance"   # 全チャネル内容同期 — terminal にも同じ guidance
     exit                        # Do NOT call TeamCreate / EnterWorktree
   fi
   ```

4. On `count >= 1`: continue to Phase 0.9.

The BLOCKED guidance is the canonical text emitted by `lib/persona_check.sh get_persona_guidance_message`. discover Step 3a-precheck emits the same message so the two layers agree on when and why persona bootstrap is disallowed.

## Phase 0.9: Agent Teams Setup

**Tools:** ToolSearch, TeamCreate, TeamDelete, EnterWorktree

Bootstrap Agent Teams before any phase. Solo execution fallback is prohibited. Spawn agents per task type from Phase 0.5 (see Agent Composition Table).

1. ToolSearch: fetch schemas for `TeamCreate`, `TeamDelete`, `SendMessage`, `EnterWorktree`
2. TeamCreate: create `autopilot-{issue_number}` — record team_name for all Agent calls
3. Read agent definitions from `${CLAUDE_PLUGIN_ROOT}/agents/`. system_prompt is the markdown body; `tools` and `skills` frontmatter fields control capabilities.
4. EnterWorktree `autopilot-{issue_number}` — all phases (1–5) run inside this worktree. Immediately after, export `ATDD_AUTOPILOT_WORKTREE=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" <worktree_absolute_path>)` so the PreToolUse `autopilot-worktree-guard` hook enforces the boundary for all subsequent Edit/Write/MultiEdit/NotebookEdit/Bash calls. Keep the variable set for the rest of the session; do not `unset` it between phases.
5. **Mid-phase resume:** If Phase 0.5 start phase is beyond AC Review Round:
   - Phase 1 or AC Review Round: no re-spawn needed.
   - Phase 2+: spawn Phase 1/2 agents for the task type.
   - Phase 3 or 4: verify plan comment (`## Implementation Plan` with `### Agent Composition`) exists. If absent: STOP — "plan is incomplete. Re-run from Phase 2."
   Then proceed via SendMessage.
   Note: This is the sole exception to Autonomy Rule 5 — applies only on session restart.
6. On failure: report the error → STOP. Do NOT fall back to solo execution.

## Output Channels (applies to all phases)

Two channels only — never via repository files:

- **Inter-agent handoff**: use `SendMessage`. Do not persist to files.
- **Human-facing work log** (AC confirmation, plan, review results, reports): post as Issue/PR comments via `gh issue comment` / `gh pr comment`.

Writing to `docs/decisions/` or any repository path is prohibited. Curated knowledge graduates into `docs/` or `DEVELOPMENT.md` by explicit human decision only.

## Status Evaluation (SKILL_STATUS)

Evaluate the `skill-status` block in each agent reply to determine the next action.

### Extraction Rule

Locate the **last** `skill-status` block. Parse `SKILL_STATUS` and `PHASE`. `RECOMMENDATION` is informational only — do not use it for branching.

### Action Matrix

| SKILL_STATUS | Autopilot Next Action |
|---|---|
| `COMPLETE` | Proceed to next phase |
| `PENDING` | Wait for user input; do not advance |
| `BLOCKED` | Post RECOMMENDATION as Issue comment. STOP and wait for user. |
| `FAILED` | Stop autopilot. Post RECOMMENDATION. Report to user. |
| (any other) | Treat as `PENDING` |

### Fallback: No SKILL_STATUS Block Found

1. Post Issue comment: "Agent returned output without SKILL_STATUS block. Manual verification required."
2. STOP. Do not advance.
3. Report: which agent, which phase, raw message.

Do NOT infer skill completion from message text. Only `skill-status` blocks are authoritative.

See `docs/guides/skill-status-spec.md` for full specification.

## Autonomy Rules

Prohibited patterns. Failure mode: report what failed → STOP → wait for user.

1. **Solo execution** — PO must not execute Developer or QA responsibilities. Implementation requires a Developer agent; review requires a QA agent.
2. **Explore subagent substitution** — Do not use Explore subagents instead of Developer/QA. Explore is for codebase research only.
3. **Self-executing skill steps** — Skills delegated via Agent tool must run inside the spawned agent, not by PO directly.
4. **Context-priority execution** — Do not skip spawning an agent because prior skill context is available. Each role requires its own agent.
5. **Agent re-generation** — Once spawned in AC Review Round, do not create new Developer/QA instances in Phase 2, Plan Review Round, Phase 3, or Phase 4. Use SendMessage only. Exception: Phase 0.9 mid-phase resume on session restart.

## Phase 1: discover (PO leads)

**Tools:** Bash (gh), Skill

1. `gh issue edit <number> --add-label in-progress` (exclusive lock)
2. Read the Issue body and comments
3. Use Skill tool to invoke `atdd-kit:discover` with `"<number> --autopilot"`
4. On `SKILL_STATUS: COMPLETE` from discover: immediately issue Agent tool calls to spawn AC Review Round agents. **Phase 1 is not complete until AC Review Round agents have been spawned. Receiving SKILL_STATUS: COMPLETE from discover alone does not complete Phase 1.** Do NOT present draft deliverables to the user or send any intermediate messages before the Agent tool calls.

## AC Review Round

**Tools:** Agent, SendMessage

Spawn agents per Phase 1 column of the Agent Composition Table and review draft ACs.

### development / refactoring: Three Amigos (PO + Developer + QA)

1. Spawn Developer and QA in parallel (team_name: `autopilot-{issue_number}`, isolation: "worktree"):
   - **PO:** requirement completeness, user story alignment, business value
   - **Developer:** architecture, feasibility, edge cases, implementation complexity
   - **QA:** testability, boundary conditions, error cases
   Each agent returns review via SendMessage reply.

### bug: PO + Tester + Developer (bug-triage)

1. Spawn Tester and Developer in parallel:
   - **PO:** impact scope, priority
   - **Tester:** reproduction confirmation, test environment
   - **Developer:** root cause hypothesis, fix approach
   Each agent returns triage via SendMessage reply.

### research / documentation: PO only

1. PO designs scope, DoD, theme breakdown, and agent count.

### Common (all task types)

2. Collect review results via SendMessage replies
3. Integrate feedback and modify ACs
4. Present final AC set: "This is the final AC set incorporating all Three Amigos review results." Single approval point (discover Step 7 was skipped in autopilot mode).
   - **Approve:** Proceed to step 5
   - **Reject:** PO modifies ACs and re-presents (do NOT restart the round)
5. On approval: `gh issue comment` with final ACs (authoritative posting)

## Phase 2: plan (PO orchestrates, Developer + QA lead their domains)

**Tools:** SendMessage, Skill

> **Constraint:** No new agents. Use SendMessage only to existing Developer/QA (see Autonomy Rule 5).

1. SendMessage to Developer: implementation strategy — file structure, order, dependencies, risks. Include Issue number and reference to Issue comments containing the AC set (`gh issue view <number> --json comments` on demand).
2. SendMessage to QA: test strategy — layer selection per AC, coverage, regression risk. Include Issue number and reference to Issue comments containing the AC set.
3. PO integrates both into a unified Plan.

## Plan Review Round

**Tools:** SendMessage

> **Constraint:** No new agents. Use SendMessage only to existing Developer/QA (see Autonomy Rule 5).

> **Circuit Breaker Check:** At the start of each iteration (initial and `needs-plan-revision` re-entry), run `bash lib/circuit_breaker.sh check`. OPEN → halt autopilot.

1. SendMessage to Developer and QA in parallel. Include Issue number and reference to Issue comments containing the AC set and the unified Plan (`gh issue view <number> --json comments` on demand):
   - **PO:** AC alignment, no scope creep
   - **Developer:** file structure validity, implementation order risks, Agent Composition concreteness
   - **QA:** test layer validity, coverage completeness
2. Collect and integrate results
3. Finalize Plan (no Stakeholder approval required)
4. `gh issue comment` with Plan
5. `gh issue edit <number> --add-label ready-to-go`
6. **Stop-point (same-session only, skip if mid-phase resume):** Fires only when Plan Review Round ran in the current session. Skip if reached via Phase 0.5 resume (label already set).

   AskUserQuestion:
   - **Option 1:** "Clear and end — clear this session, then run `/atdd-kit:autopilot <N>` to resume from Phase 3"
   - **Option 2:** "Continue — proceed to Phase 3 now"

   **Fallback (AskUserQuestion unavailable):**
   ```
   Plan approved. Choose how to proceed:
   1. Clear and end — clear this session, then run `/atdd-kit:autopilot <N>` to resume from Phase 3
   2. Continue — proceed to Phase 3 now
   Reply with 1 or 2.
   ```
   STOP and wait.

   **On response:**
   - **Option 1:** Print and terminate:
     ```
     Session cleared. To resume, run `/atdd-kit:autopilot <N>` in a new session.
     Phase 0.5 will detect the `ready-to-go` label and start directly from Phase 3.
     ```
   - **Option 2:** Proceed to Phase 3.
   - **Other:** Report "Response could not be classified as clear or continue." → STOP. Do NOT auto-select.

## Phase 3: Implementation (task-type-specific)

**Tools:** SendMessage, Skill

> **Constraint:** No new agents except variable-count agents per plan. Use SendMessage only (see Autonomy Rule 5).

> **Circuit Breaker Check:** At each iteration start (`ready-to-go` entry and `needs-pr-revision` re-entry), run `bash lib/circuit_breaker.sh check`. OPEN → halt. Do not delegate to Developer.

### development / refactoring: Developer implements

1. SendMessage to Developer: ATDD instructions with Issue number and AC set/Plan references. Developer uses Skill tool to invoke `atdd-kit:atdd` with `"<number> --autopilot"`.
2. Developer creates branch, Draft PR, implements AC by AC
3. Developer uses Skill tool to invoke `atdd-kit:verify` after all ACs complete
4. Developer marks PR ready and adds `ready-for-PR-review`

### bug: Developer fixes + Tester verifies

1. Developer implements fix using ATDD
2. Tester verifies fix by reproducing original bug
3. Developer marks PR ready and adds `ready-for-PR-review`

### research: Researcher x N (min 2 per theme)

1. PO spawns Researchers (per plan-approved Agent Composition)
2. Each Researcher returns findings via SendMessage
3. PO synthesizes into a report, posts as Issue/PR comment

### documentation: Writer creates

1. Writer creates/updates documentation per approved plan
2. Writer marks PR ready and adds `ready-for-PR-review`

## Phase 4: PR Review (task-type-specific)

**Tools:** SendMessage

> **Constraint:** No new agents except variable-count Reviewers per plan. Use SendMessage only (see Autonomy Rule 5).

> **Circuit Breaker Check:** At each iteration start (initial and `needs-pr-revision` re-entry), run `bash lib/circuit_breaker.sh check`. OPEN → halt. Do not spawn Reviewers.

### development / bug / documentation / refactoring: Reviewer x N

1. PO spawns Reviewers (per plan-approved Agent Composition)
2. Each Reviewer returns results via SendMessage. PO posts consolidated review as PR comment.
3. Issues found → `needs-pr-revision`, Developer/Writer fixes. No issues → review PASS comment.

### research: PO reviews

1. PO reviews report against DoD
2. Gaps → send Researchers back. Complete → review PASS comment.

## Phase 5: PO Cross-Cutting Checks and Merge Decision

**Tools:** Bash (gh), ExitWorktree, TeamDelete

### development / bug / documentation / refactoring

1. **Verify review PASS:** `gh pr view <PR> --json comments --jq '.comments[].body'`
   - No PASS comment → STOP. Do NOT proceed to merge. "QA review PASS not confirmed. Returning to Phase 4."
   - PASS confirmed → Step 2
2. `gh pr view <PR> --json statusCheckRollup,mergeable`
3. `mergeable == CONFLICTING`:
   - Do NOT merge. Post: "⚠ PR has merge conflicts. Rebase required."
     ```bash
     git fetch origin main
     git checkout <branch>
     git rebase origin/main
     # After resolving conflicts
     git push --force-with-lease
     ```
   - After rebase: return to Phase 4
   `mergeable == MERGEABLE`: proceed to merge
4. `gh pr merge <PR> --squash`
5. Remove `in-progress` label
6. Switch back to the worktree base branch:
   ```bash
   git switch worktree-autopilot-{issue_number}
   ```
7. ExitWorktree with action: "remove"
8. TeamDelete `autopilot-{issue_number}`
9. `git checkout main && git pull origin main`

### research

PR verify/merge steps do not apply to research tasks. Phase 5 processes deliverables into next actions.
Do NOT add `ready-for-PR-review` label for research tasks. Phase 5 triggers on Review PASS comment only.

1. **Idempotency guard:** `gh issue view <n> --json state --jq '.state'`
   - state == `CLOSED` → post "Phase 5 skipped: Issue already closed. Manual review required." as Issue comment, return SKILL_STATUS: BLOCKED, STOP.
   - state == `OPEN` → proceed.

2. **Deliverable Classification:** Classify each research finding:
   - `new_issue`: the finding can be acted on independently as a development/bug/refactoring task → create new Issue
   - `existing_comment`: the finding supplements an existing open Issue without requiring a new one → comment on existing Issue
   - `no_action`: the finding is informational only (confirmation, negative result, context) → record reason

   **Classification heuristic:** When in doubt between `new_issue` and `existing_comment`, prefer `existing_comment` to avoid Issue sprawl.

   If findings total 0, skip to Step 4 ("発見なし" explanation).

3. **Execute Actions:**
   - **3a. `new_issue` items:** If no `new_issue` items exist, skip to Step 3b.
     - `gh issue create --title "<title>" --body "<body includes link to source #<n>>"` — record created Issue number.
     - 1+ successes then failure → best-effort continue, record failed items.
     - All items fail → post failure report, return SKILL_STATUS: BLOCKED, STOP.
   - **3b. `existing_comment` items:** `gh issue comment <existing-n> --body "<content>"` — record commented Issue numbers.
   - **3c. `no_action` items:** Record reason for each.

4. **Closing Comment:** Post `gh issue comment <source> --body` with the following structure.
   **Omit any section with 0 items** (do not leave empty headings).
   If all sections are empty (発見なし), include explanation instead:
   - `### 起票した新規 Issue` — `new_issue` results (including any failures)
   - `### コメントした既存 Issue` — `existing_comment` results
   - `### アクション不要項目` — `no_action` reasons

5. Close source Issue: `gh issue close <source>`

6. Remove `in-progress` label: `gh issue edit <source> --remove-label in-progress`

7. Switch back to the worktree base branch:
   ```bash
   git switch worktree-autopilot-{issue_number}
   ```
8. ExitWorktree with action: "remove"
9. TeamDelete `autopilot-{issue_number}`
10. `git checkout main && git pull origin main`

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

1. `.claude/workflow-config.yml` exists (if missing, start a new session to trigger auto-setup)
2. Agent definitions exist in `${CLAUDE_PLUGIN_ROOT}/agents/` (developer.md, qa.md)
3. ToolSearch: confirm `TeamCreate` and `SendMessage` are resolvable
   - Unavailable → STOP: "Agent Teams tools not found. Verify `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` `env`, then restart."

### Initialization

1. `git checkout main && git pull origin main`
2. Read agent definitions from `${CLAUDE_PLUGIN_ROOT}/agents/`
3. Launch the selected mode

## Circuit Breaker Integration

Prevents infinite loops by tracking progress and errors. See `docs/guides/circuit-breaker.md`.

### Trigger Events

| Event | Signal | Command |
|-------|--------|---------|
| `SKILL_STATUS: COMPLETE` | Progress | `bash lib/circuit_breaker.sh record_progress` |
| Same label state at iteration end | No progress | `bash lib/circuit_breaker.sh record_no_progress` |
| Same issue fingerprint in consecutive rounds | Error | `bash lib/circuit_breaker.sh record_error <fingerprint>` |

### Fingerprint Convention

Short `[a-zA-Z0-9_-]+` string. Examples: `missing-tests`, `type-error-AC3`, `plan-scope-creep`. Invalid characters cause non-zero exit.

### Manual Reset

```bash
bash lib/circuit_breaker.sh reset
```

Then: `/atdd-kit:autopilot <issue-number>`
