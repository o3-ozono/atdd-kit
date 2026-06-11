# Agents

Reviewer role definitions spawned by the `reviewing-deliverables` skill (Step 5 of the v1.0 ATDD flow). Each agent is a Markdown file with YAML frontmatter defining its capabilities and system prompt.

## Available Agents

| Agent | Role | Key Constraints |
|-------|------|-----------------|
| `prd-reviewer.md` | PRD Reviewer | PRD review against 10 structural criteria. Read-only. Cannot edit files. |
| `us-reviewer.md` | User Story Reviewer | User Story review against 7 structural criteria. Read-only. Cannot edit files. |
| `plan-reviewer.md` | Plan Reviewer | Plan review against 10 structural criteria. Read-only. Cannot edit files. |
| `code-reviewer.md` | Code Reviewer | Code change review against 10 structural criteria. Read-only. Cannot edit files. |
| `at-reviewer.md` | Acceptance Test Reviewer | Acceptance Test review against 10 structural criteria. Read-only. Cannot edit files. |
| `final-reviewer.md` | Final Reviewer | Aggregates 5 specialist reviewer verdicts (47 criteria total) into a unified PASS/FAIL. Read-only. Cannot edit files. |

## Frontmatter Fields

| Field | Description |
|-------|-------------|
| `name` | Agent identifier (used with `@name` or `--agent name`) |
| `description` | Trigger conditions for auto-delegation |
| `tools` | Allowlist of tools the agent can use |
| `skills` | Skills preloaded into the agent's context at startup |

> **Model policy (#259):** impl / review phase subagents default to **Sonnet**, specified via the `agent()` options of the `reviewing-deliverables` Workflow script — never in the `agents/*.md` frontmatter (the #105 session-inheritance design stays; frontmatter carries no `model:` / `effort:`). The design phase (`extracting-user-stories` / `writing-plan-and-tests`) and the orchestrator (autopilot main loop) inherit the session model unchanged. **Escalation path (one-way per Issue):** a convergence-failure halt (`MAX_ITERATIONS` / `sameness-detector` / `stuck`) ending a Sonnet cycle in `COMPLETED_WITH_DEBT` promotes that step's impl / review subagents to the session model from the next convergence cycle. Effort stays unset; agents inherit the session-level `/effort` setting.
>
> Bench (2026-06-10〜11, 2 Issues × 3 models × 10 runs = 60 implementations + 76 judge runs): functional quality equal across models; cost ratio Sonnet 1.0 : Opus 2.2 : Fable 4.1; design-judgment consistency Fable 20/20 — the basis for keeping the design phase on the session model.

## Usage

The reviewer agents are spawned by the `reviewing-deliverables` skill during Step 5 of the ATDD flow. The skill dispatches the five specialist reviewers (PRD, User Story, Plan, Code, Acceptance Test) in parallel, then the final reviewer aggregates their verdicts into a single PASS/FAIL determination.
