---
description: "PO-led end-to-end workflow. Orchestrates discover → plan → implement → review → merge with PO/Developer/QA Agent Teams."
---

# Autopilot — PO-Led End-to-End Workflow

PO（プロダクトオーナー）が team-lead として常駐し、discover から merge まで一気通貫で Issue を完遂する。

## Prerequisites
- `.claude/workflow-config.yml` must exist (if missing, start a new session to trigger auto-setup)
- Agent definitions must exist in `${CLAUDE_PLUGIN_ROOT}/agents/` (po.md, developer.md, qa.md)
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

## Phase 0.5: Phase Determination

**Tools:** Bash (gh)

After resolving the target Issue, determine which phase to start from based on the Issue's labels:

1. `gh issue view <number> --json labels --jq '[.labels[].name]'`
2. Match against the phase determination table (most advanced phase wins if multiple labels exist):

| Label State | Start Phase |
|-------------|-------------|
| `ready-for-PR-review` | Phase 4: PR Review |
| `needs-pr-revision` | Phase 3: Implementation (revision) |
| `implementing` | Phase 3: Implementation (continue) |
| `ready-to-implement` | Phase 3: Implementation |
| `needs-plan-revision` | Phase 2: plan (recreate) |
| `ready-for-plan-review` | Phase 2: Plan Review Round |
| `in-progress` only (no phase label) | Phase 1: discover |
| No `in-progress` label | Phase 1: discover (will acquire lock) |

3. Skip to the determined phase. Do not re-execute earlier phases that are already complete.

## Phase 0.9: Agent Teams Setup

**Tools:** ToolSearch, TeamCreate, EnterWorktree

Bootstrap the Agent Teams infrastructure before any phase execution. This phase must succeed — solo execution fallback is prohibited.

1. Use ToolSearch to fetch full schemas for `TeamCreate`, `SendMessage`, and `EnterWorktree` (deferred tools require explicit schema resolution before use)
2. Use TeamCreate to create team `autopilot-{issue_number}` — record the returned team_name for all subsequent Agent tool calls
3. Read agent definitions from `${CLAUDE_PLUGIN_ROOT}/agents/` (po.md, developer.md, qa.md). The system_prompt is the markdown body; the `tools` and `skills` fields in frontmatter control agent capabilities.
4. Use EnterWorktree with name `autopilot-{issue_number}` to enter an isolated worktree — all subsequent phases (1–5) execute inside this worktree
5. Create `docs/decisions/` directory in the worktree for Decision Trail output: `mkdir -p docs/decisions`
6. **Mid-phase resume:** If Phase 0.5 determined a start phase beyond AC Review Round (i.e., Phase 2/plan, Plan Review, Phase 3/Implementation, or Phase 4/PR Review), the Developer and QA agents do not yet exist in this session. Re-spawn the required agents before proceeding:
   - Phase 2 (plan) or Plan Review Round: spawn both Developer (name: "Developer", subagent_type: "developer") and QA (name: "QA", subagent_type: "qa") with Agent tool (team_name: `autopilot-{issue_number}`, isolation: "worktree"). Load prior Decision Trail files from `docs/decisions/` as context in each Agent's prompt.
   - Phase 3 (Implementation): spawn Developer (name: "Developer", subagent_type: "developer") only. Load prior Decision Trail as context.
   - Phase 4 (PR Review): spawn QA (name: "QA", subagent_type: "qa") only. Load prior Decision Trail as context.
   - Phase 1 (discover) or AC Review Round: no re-spawn needed — agents are created in AC Review Round.
   Then proceed to the determined phase using SendMessage.
7. On failure at any step: report the error → STOP. Do NOT fall back to solo execution. See Autonomy Rules below.

## Autonomy Rules

The following execution patterns are **prohibited**. If any situation would trigger one of these patterns, the correct action is: report the failure to the user → STOP → wait for user decision.

1. **Solo execution** — PO must not execute Developer or QA responsibilities alone. All implementation requires a Developer agent; all review requires a QA agent.
2. **Explore subagent substitution** — Do not use Explore subagents as a replacement for Developer or QA agents. Explore subagents are for codebase research only, not for implementation or review.
3. **Self-executing skill steps** — When a skill is delegated to Developer or QA via Agent tool, PO must not execute that skill's steps directly. The skill must run inside the spawned agent.
4. **Context-priority execution** — Do not skip spawning an agent because "the context from a prior skill is already available." Each role must run in its own agent with its own system_prompt.

Failure mode: report what failed → STOP → user decides next step.

## Phase 1: discover (PO leads)

**Tools:** Bash (gh), Skill

PO が Stakeholder（ユーザー）と対話して要件を探索し、AC を導出する。

1. `gh issue edit <number> --add-label in-progress` (exclusive lock)
2. Read the Issue body and comments for context
3. Use Skill tool to invoke `atdd-kit:discover` for the Issue
4. PO derives draft ACs through Stakeholder dialogue (one question at a time)
5. Proceed to AC Review Round

## AC Review Round

**Tools:** Agent, SendMessage

PO・Developer・QA 全員で draft AC をレビューする（Three Amigos）。

1. Use Agent tool to spawn Developer (name: "Developer", subagent_type: "developer") and QA (name: "QA", subagent_type: "qa") in parallel for AC review (team_name: `autopilot-{issue_number}`, isolation: "worktree"). Agent definitions in `${CLAUDE_PLUGIN_ROOT}/agents/` provide system prompts, tool restrictions, and skill preloading automatically:
   - **PO:** 要件の網羅性、ユーザーストーリーとの整合性、ビジネス価値
   - **Developer:** アーキテクチャ整合性、技術的実現性、エッジケース、実装複雑度
   - **QA:** テスト可能性、境界条件の網羅性、エラーケース、カバレッジの抜け
   Each agent must write its review results to `docs/decisions/ac-review-developer.md` or `docs/decisions/ac-review-qa.md` respectively.
2. PO collects review results from Developer and QA (read from `docs/decisions/ac-review-developer.md` and `docs/decisions/ac-review-qa.md`)
3. PO integrates feedback and modifies ACs accordingly
4. Present final AC set to Stakeholder for approval with the message: "Three Amigos レビュー結果を統合した最終版です。" This is the single approval point — discover's Step 7 approval was skipped in autopilot mode.
   - **Approve:** Proceed to step 5
   - **Reject:** PO modifies ACs based on user feedback and re-presents (do NOT restart the AC Review Round — PO corrects directly)
5. On approval: post final ACs as Issue comment with `gh issue comment` (this is the authoritative posting — discover did not post in autopilot mode)

## Phase 2: plan (PO orchestrates, Developer + QA lead their domains)

**Tools:** SendMessage, Skill

Developer が実装戦略、QA がテスト戦略を主導し、PO が統合する。Developer and QA agents were already spawned in AC Review Round — continue via SendMessage.

1. Use SendMessage to: "Developer" with implementation strategy instructions. Include Issue number, approved AC set, and prior Decision Trail references as context:
   - ファイル構成、実装順序、依存関係、技術リスク
   - Agent must write results to `docs/decisions/impl-strategy-developer.md`
2. Use SendMessage to: "QA" with test strategy instructions. Include Issue number, approved AC set, and prior Decision Trail references as context:
   - AC ごとのテスト層選定（Unit/Integration/E2E）、カバレッジ戦略、リグレッションリスク分析
   - Agent must write results to `docs/decisions/test-strategy-qa.md`
3. PO integrates both strategies into a unified Plan

## Plan Review Round

**Tools:** SendMessage

PO・Developer・QA 全員で Plan をレビューする。Developer and QA agents continue via SendMessage.

1. Use SendMessage to: "Developer" and SendMessage to: "QA" in parallel for Plan review. Include Issue number, approved AC set, unified Plan, and prior Decision Trail file paths as context:
   - **PO:** AC との整合性、スコープ逸脱の有無
   - **Developer:** ファイル構成の妥当性、実装順序のリスク、技術リスク評価 — write results to `docs/decisions/plan-review-developer.md`
   - **QA:** テスト層の妥当性（Unit/Integration/E2E の使い分け）、カバレッジ戦略の網羅性 — write results to `docs/decisions/plan-review-qa.md`
2. PO collects and integrates review results from `docs/decisions/plan-review-developer.md` and `docs/decisions/plan-review-qa.md`
3. PO finalizes Plan (Stakeholder approval is NOT required for Plan)
4. Post Plan as Issue comment with `gh issue comment`
5. `gh issue edit <number> --add-label ready-to-implement`

## Phase 3: Implementation (Developer agent)

**Tools:** SendMessage, Skill

Developer が ATDD ダブルループで実装する。Developer agent continues via SendMessage.

1. Use SendMessage to: "Developer" with ATDD implementation instructions. Include Issue number, approved AC set, unified Plan, and all prior Decision Trail file paths as context — Developer uses Skill tool to invoke `atdd-kit:atdd`
2. Developer creates branch, Draft PR, and implements AC by AC
3. Developer uses Skill tool to invoke `atdd-kit:verify` after all ACs are complete
4. Developer runs `git add docs/decisions/` to include all Decision Trail files in PR commits
5. Developer marks PR as ready and adds `ready-for-PR-review` label

## Phase 4: PR Review (QA agent)

**Tools:** SendMessage

QA が PR をレビューする。QA agent continues via SendMessage.

1. Use SendMessage to: "QA" with PR review instructions. Include Issue number, approved AC set, PR number, and all prior Decision Trail file paths as context
2. QA performs:
   - Stage 1: Spec compliance (S0-S3 — AC coverage, fidelity, no extras, test-AC mapping)
   - Stage 2: Code quality (state management, error handling, security)
3. If issues found: QA adds `needs-pr-revision`, Developer fixes
4. If no issues: QA posts review PASS comment

## Phase 5: PO Cross-Cutting Checks and Merge Decision

**Tools:** Bash (gh), ExitWorktree

PO が横断チェックを実施し、マージを判断する。

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
7. Cleanup: `git checkout main && git pull origin main`

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
2. Verify agent definitions exist in `${CLAUDE_PLUGIN_ROOT}/agents/` (po.md, developer.md, qa.md)
3. Verify Agent Teams tools are available: use ToolSearch to confirm `TeamCreate` and `SendMessage` are resolvable
   - If unavailable: STOP — "Agent Teams tools (TeamCreate, SendMessage) not found. Verify that `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set in `.claude/settings.local.json` `env`, then restart the session."

### Initialization

1. `git checkout main && git pull origin main` to update
2. Read agent definitions from `${CLAUDE_PLUGIN_ROOT}/agents/`
3. Launch the selected mode
