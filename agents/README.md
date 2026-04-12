# Agents

Role definitions for the autopilot multi-agent workflow. Each agent is a Markdown file with YAML frontmatter defining its capabilities and system prompt.

## Available Agents

| Agent | Role | Model | Effort | Key Constraints |
|-------|------|-------|--------|-----------------|
| `po.md` | Product Owner | opus | high | Orchestrates workflow. Does not edit code. |
| `developer.md` | Developer | sonnet | high | ATDD implementation. Cannot self-review. |
| `qa.md` | QA | sonnet | high | Test strategy and verification. Cannot edit code. |
| `tester.md` | Tester | sonnet | high | Bug reproduction and fix verification. Cannot edit production code. |
| `reviewer.md` | Reviewer | sonnet | high | Code review across task types. Cannot edit code. |
| `researcher.md` | Researcher | sonnet | high | Research and analysis. Cannot edit code. |
| `writer.md` | Writer | sonnet | high | Documentation creation. Can edit files. |

## Frontmatter Fields

| Field | Description |
|-------|-------------|
| `name` | Agent identifier (used with `@name` or `--agent name`) |
| `description` | Trigger conditions for auto-delegation |
| `model` | Model override (`inherit`, `sonnet`, `opus`, `haiku`) |
| `tools` | Allowlist of tools the agent can use |
| `skills` | Skills preloaded into the agent's context at startup |

## Usage

### Via Autopilot

`/atdd-kit:autopilot` spawns PO as the main thread, which orchestrates task-type-specific agent teams (Developer, QA, Tester, Reviewer, Researcher, Writer) based on the Issue type.

### Standalone

Agents can be invoked directly:
- `@qa` — QA review outside of autopilot
- `@developer` — Developer implementation outside of autopilot
- `claude --agent po` — Start a session with PO as the main agent
