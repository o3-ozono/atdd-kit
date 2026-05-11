# Agents

Role definitions for the autopilot multi-agent workflow. Each agent is a Markdown file with YAML frontmatter defining its capabilities and system prompt.

## Available Agents

| Agent | Role | Key Constraints |
|-------|------|-----------------|
| `developer.md` | Developer | ATDD implementation. Cannot self-review. |
| `qa.md` | QA | Test strategy and verification. Cannot edit code. |
| `tester.md` | Tester | Bug reproduction and fix verification. Cannot edit production code. |
| `reviewer.md` | Reviewer | Code review across task types. Cannot edit code. |
| `researcher.md` | Researcher | Research and analysis. Cannot edit code. |
| `writer.md` | Writer | Documentation creation. Can edit files. |
| `prd-reviewer.md` | PRD Reviewer | PRD review against 10 structural criteria. Read-only. Cannot edit files. |
| `us-reviewer.md` | User Story Reviewer | User Story review against 10 structural criteria. Read-only. Cannot edit files. |
| `plan-reviewer.md` | Plan Reviewer | Plan review against 10 structural criteria. Read-only. Cannot edit files. |
| `code-reviewer.md` | Code Reviewer | Code change review against 10 structural criteria. Read-only. Cannot edit files. |
| `at-reviewer.md` | Acceptance Test Reviewer | Acceptance Test review against 10 structural criteria. Read-only. Cannot edit files. |
| `final-reviewer.md` | Final Reviewer | Aggregates 5 specialist reviewer verdicts (50 criteria total) into a unified PASS/FAIL. Read-only. Cannot edit files. |

## Frontmatter Fields

| Field | Description |
|-------|-------------|
| `name` | Agent identifier (used with `@name` or `--agent name`) |
| `description` | Trigger conditions for auto-delegation |
| `tools` | Allowlist of tools the agent can use |
| `skills` | Skills preloaded into the agent's context at startup |

> Model and effort are intentionally unset; agents inherit the session-level `/model` and `/effort` settings.

## Usage

### Via Autopilot

`/atdd-kit:autopilot` — main Claude acts as the orchestrator (PO role) and drives task-type-specific agent teams (Developer, QA, Tester, Reviewer, Researcher, Writer) based on the Issue type.

### Standalone

Agents can be invoked directly:
- `@qa` — QA review outside of autopilot
- `@developer` — Developer implementation outside of autopilot
