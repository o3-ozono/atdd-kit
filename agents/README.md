# Agents

This directory is the home for custom agent definitions. Currently no agent definition files exist — only this README. Add `<name>.md` files here when you want to define project-specific agents with YAML frontmatter and a system prompt.

## Role of this directory

`agents/` serves as the future custom agent placement area. When custom agents are defined here, each file should follow the Frontmatter Fields convention below.

Review functionality is **not** handled by fixed agent files in this directory. The `reviewing-deliverables` skill (Step 5 of the ATDD flow) runs review through a dynamic lens panel × parallel Workflow (#234): Scout → Generate (dynamic panel) → Review (parallel) → Verify (adversarial check) → Aggregate (PASS/FAIL). See `skills/reviewing-deliverables/SKILL.md` for details.

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
