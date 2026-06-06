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

> Model and effort are intentionally unset; agents inherit the session-level `/model` and `/effort` settings.

## Usage

The reviewer agents are spawned by the `reviewing-deliverables` skill during Step 5 of the ATDD flow. The skill dispatches the five specialist reviewers (PRD, User Story, Plan, Code, Acceptance Test) in parallel, then the final reviewer aggregates their verdicts into a single PASS/FAIL determination.
