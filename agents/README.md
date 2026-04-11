# Agents

Role definitions for the autopilot multi-agent workflow. Each agent is a Markdown file with YAML frontmatter defining its capabilities and system prompt.

## Available Agents

| Agent | Role | Key Constraints |
|-------|------|-----------------|
| `po.md` | Product Owner | Orchestrates workflow. Does not edit code. |
| `developer.md` | Developer | ATDD implementation. Cannot self-review. |
| `qa.md` | QA | Code review and verification. Cannot edit code (no Write/Edit tools). |
| `researcher.md` | Researcher | Investigation and analysis. Cannot edit code. |

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

`/atdd-kit:autopilot` spawns PO as the main thread, which orchestrates Developer and QA as subagents.

### Standalone

Agents can be invoked directly:
- `@qa` — QA review outside of autopilot
- `@developer` — Developer implementation outside of autopilot
- `claude --agent po` — Start a session with PO as the main agent
