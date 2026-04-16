[日本語版](DEVELOPMENT.ja.md)

# Development Guide

## Non-Negotiable Rules

These rules are mandatory for all contributions. No exceptions.

### Versioning

Every feature PR merged to main **must** update the version and changelog:

1. Bump version in `.claude-plugin/plugin.json` ([SemVer](https://semver.org/))
2. Add entry to `CHANGELOG.md` ([Keep a Changelog](https://keepachangelog.com/))
3. Both updates go in the same PR as the feature — not a separate commit after the fact

Failure to follow this will break the plugin update notification system (`scripts/check-plugin-version.sh`).

### Language

- **LLM-facing files** (skills, rules, docs, commands, agents): English only. No `*.ja.md` translations.
- **User-facing files** (README, DEVELOPMENT): Maintain both `.md` and `.ja.md` in sync.
- **Issue/PR templates**: Maintain `en/` and `ja/` variants in `templates/`.

#### Tightening Guidelines

When editing LLM-facing files, apply tight English style to minimize token count without losing instructional content:

1. Remove self-evident command purpose descriptions (e.g., `` `git status` to check status `` → `` `git status` ``).
2. Shorten verbose heading parentheticals (e.g., "Update Repository (highest priority, run alone)" → "Update repo (run alone)").
3. Remove repeated statements already expressed by the surrounding structure.
4. Keep articles ("the", "a") — no extreme stripping that harms readability.
5. Convert prose to lists or tables where applicable.
6. Convert polite instructions ("You MUST/should/need to") to imperatives ("Verify X", "Run Y").
7. Compress error handling to 1 sentence.

Protected elements: YAML frontmatter fields, code block contents, XML guard tag blocks (`<HARD-GATE>`, `<AUTOPILOT-GUARD>`, `<SUBAGENT-STOP>`) — structure preserved and text inside may be tightened provided BATS-verified strings are not altered, step numbers, and `If X:` conditional structures.

### Zero Dependencies

atdd-kit has **zero external dependencies** by design. No npm packages, no external services. Pure markdown + bash scripts only. This ensures the plugin is self-contained, shareable via source control, and works without dependency installation on any platform.

### Always-Loaded Rules Budget

`rules/atdd-kit.md` loads on **every turn**. Keep it under **40 lines**. Move anything else to `docs/`.

### Directory READMEs

Each top-level directory (`skills/`, `commands/`, `hooks/`, `rules/`, `scripts/`, `templates/`, `tests/`) has a `README.md`. When adding, removing, or modifying files in these directories, **update the corresponding README.md** in the same PR.

## Architecture Decisions

### Skills vs Commands

- **Skill**: Has `description` for auto-detection, or is part of the workflow chain (discover → plan → atdd → verify → ship)
- **Command**: Explicitly invoked by user (`/atdd-kit:*`)

### Skill Chain

```
bug/issue (auto) → ideate (optional) → discover → plan → [approval gate] → atdd → verify → ship
```

- `issue` chains to `ideate`, which chains to `discover` (ideate is skippable)
- Skills chain forward (discover → plan, atdd → verify → ship)
- Commands call the chain entry point only (autopilot (Dev) → atdd, not verify)
- Session-start guard on all 7 core skills

### Addon System

Platform-specific features live in `addons/<platform>/`. Each addon has an `addon.yml` manifest declaring MCP servers, hooks, deploy files, and CI fragments. See `addons/README.md`.

### Agents

Role definitions for autopilot live in `agents/`. Each agent has YAML frontmatter (`name`, `description`, `model`, `tools`, `skills`) and a system prompt body. See `agents/README.md`.

### Skill Description Field Rules

Skill YAML `description` fields must contain **trigger conditions only** -- never workflow summaries. If the description summarizes the workflow, agents follow the description instead of reading the full skill content.

**Bad** (summarizes workflow):
```
description: "ATDD implementation -- creates E2E tests, then unit tests, then implementation code"
```

**Good** (trigger conditions only):
```
description: "Use when implementing a ready-to-go Issue."
```

### Skill Changes Require Eval Evidence

Skills are **behavior-shaping code**, not prose. Any modification to a skill's SKILL.md requires:

1. Run evals before and after the change
2. Show before/after pass_rate comparison
3. If pass_rate drops 10%+, the change is blocked
4. Do NOT modify Red Flags tables or carefully-tuned enforcement content without eval evidence

## Skill Evals

Skills can have regression tests using the [skill-creator](https://github.com/anthropics/claude-code/tree/main/plugins/skill-creator) eval framework.

### Adding evals to a skill

1. Create `skills/<skill-name>/evals/evals.json` with test cases and assertions (skill-creator compatible format)
2. Run `/atdd-kit:auto-eval --all` to establish the initial baseline
3. The baseline is saved to `skills/<skill-name>/evals/baseline.json`

### When evals run

- **On PR review**: `autopilot (QA)` detects `skills/*/SKILL.md` changes and triggers `auto-eval` automatically
- **Periodic**: `/atdd-kit:autopilot eval` runs every 30 minutes
- **Manual**: `/atdd-kit:auto-eval` or `/atdd-kit:auto-eval --all`

### Regression detection

If pass_rate drops by 10% or more compared to the baseline, the eval reports a regression and blocks the PR merge.

## Release Process

1. Update version in `.claude-plugin/plugin.json`
2. Update `CHANGELOG.md`
3. Ensure README.md and README.ja.md are in sync
4. Tag: `git tag vX.Y.Z`
5. Push: `git push origin main --tags`

## Repository Structure

```
atdd-kit/
├── .claude-plugin/   # Plugin metadata (plugin.json — single source of truth for version)
├── skills/           # Skill definitions (SKILL.md + optional evals/)
│   ├── atdd/
│   ├── bug/
│   ├── debugging/
│   ├── discover/
│   ├── ideate/
│   ├── issue/
│   ├── plan/
│   ├── session-start/
│   ├── ship/
│   ├── sim-pool/        # iOS addon skill (in skills/ for framework discovery)
│   ├── skill-gate/
│   ├── ui-test-debugging/ # iOS addon skill
│   └── verify/
├── agents/           # Agent role definitions (PO, Developer, QA, Tester, Reviewer, Researcher, Writer)
├── addons/           # Platform-specific addon packages (ios/, web/)
│   └── ios/          # iOS addon (addon.yml, scripts/, ci/, tests/)
├── commands/         # User-invoked slash commands (/atdd-kit:*)
├── rules/            # Always-loaded rules (40-line budget, loaded every turn)
├── docs/             # On-demand reference documents (loaded by skills when needed)
│   ├── guides/       # How-to guides and reference materials (commit-guide, review-guide, etc.)
│   ├── methodology/  # Methodology deep-dives (atdd-guide, bug-fix-process)
│   ├── specs/        # User Story + AC spec files (Living Documentation, persisted beyond Issue closure)
│   └── workflow/     # Workflow reference (workflow-detail, issue-ready-flow, autonomy-levels)
├── hooks/            # Claude Code hooks (session-start bootstrap)
├── scripts/          # Bash/Node utilities (version check)
├── templates/        # Static templates (issue/, pr/, ci/) — no template expansion
└── tests/            # BATS test suite (core tests; addon tests in addons/*/tests/)
```

Each top-level directory has its own `README.md` describing its contents.

## How Skills Work

### SKILL.md Structure

Every skill lives in `skills/<name>/SKILL.md` with two parts:

1. **YAML frontmatter** — `name` and `description` fields
2. **Markdown body** — Steps, checklists, gates, and enforcement rules

```yaml
---
name: discover
description: "Explore requirements through dialogue and derive ACs (Given/When/Then)."
---

## Session Start Check (required)
...
# discover Skill -- Requirements Exploration
...
```

The `description` field controls auto-trigger behavior. It must contain **trigger conditions only** — never workflow summaries (see Architecture Decisions above).

### Auto-trigger vs Manual Skills

| Type | Trigger | Examples |
|------|---------|----------|
| **Auto-trigger** | Claude detects matching user intent from `description` | issue, bug, ideate, debugging, skill-gate |
| **Workflow chain** | Previous skill chains forward | discover → plan → atdd → verify → ship |
| **Manual** | User invokes explicitly | session-start, sim-pool |

### Skill Chain

```
bug/issue (auto) → ideate (optional) → discover → plan → [approval gate] → atdd → verify → ship
```

- `issue` chains to `ideate`, which chains to `discover` (ideate is skippable)
- Each skill chains to the next upon completion (discover → plan, atdd → verify → ship)
- The approval gate between plan and atdd requires human sign-off (or autopilot AC Review Round)
- All core skills include a Session Start Check that runs `session-start` if it hasn't run yet
- Skills with state gates (atdd, verify, ship) check Issue labels before proceeding

### Evals

Skills can have regression tests in `skills/<name>/evals/`. See the "Skill Evals" section above.

## Adding a New Skill

1. **Create the directory**: `skills/<name>/`
2. **Write `SKILL.md`** with YAML frontmatter (`name`, `description`) and step-by-step instructions
3. **Add evals** (recommended): Create `skills/<name>/evals/evals.json` and run `/atdd-kit:auto-eval --all` to establish a baseline
4. **Update `skills/README.md`** to include the new skill in the directory listing
5. **Update `CHANGELOG.md`** with the new skill entry
6. **Bump version** in `.claude-plugin/plugin.json`

### Checklist

- [ ] `description` contains trigger conditions only (no workflow summaries)
- [ ] Session Start Check is included if the skill is part of the core workflow
- [ ] `skills/README.md` is updated
- [ ] `CHANGELOG.md` has an entry
- [ ] Version is bumped in `.claude-plugin/plugin.json`
