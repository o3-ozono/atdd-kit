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

#### Skill rename = semver-breaking

Renaming or removing a shipped skill (the `name` segment of `skills/<name>/SKILL.md` or the invocation id `atdd-kit:<name>`) is a **breaking change** and requires a **major** version bump. Reason: `tests/fixtures/headless/*.scenario.json` and any downstream skill-chain references are pinned to exact skill ids. A rename silently breaks replay fixtures and user automation. When you must rename:

1. Bump the major version.
2. Re-record every affected fixture under `tests/fixtures/headless/` (see `docs/guides/headless-skill-testing.md`).
3. Document the rename explicitly in the CHANGELOG "### Changed" / "### Removed" sections with a `BREAKING CHANGE:` prefix.

Adding a new skill, or adding a new optional gate within an existing skill, is a **minor** bump.

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

Protected elements: YAML frontmatter fields, code block contents, XML guard tag blocks (`<HARD-GATE>`, `<SUBAGENT-STOP>`) — structure preserved and text inside may be tightened provided BATS-verified strings are not altered, step numbers, and `If X:` conditional structures.

### Zero Dependencies

atdd-kit has **zero external dependencies** by design. No npm packages, no external services. Pure markdown + bash scripts only. This ensures the plugin is self-contained, shareable via source control, and works without dependency installation on any platform.

### Always-Loaded Rules Budget

`rules/atdd-kit.md` loads on **every turn**. Keep it under **60 lines**. Move anything else to `docs/`.

> The budget was raised from 40 to 60 lines during the v1.0 migration (#179) to accommodate the 6-step Workflow table. Re-tighten toward 40 lines as legacy hints are pruned.

### Directory READMEs

Each top-level directory (`skills/`, `commands/`, `hooks/`, `rules/`, `scripts/`, `templates/`, `tests/`) has a `README.md`. When adding, removing, or modifying files in these directories, **update the corresponding README.md** in the same PR.

## Architecture Decisions

### Skills vs Commands

- **Skill**: Has `description` for auto-detection, or is part of the 6-step workflow chain (defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying)
- **Command**: Explicitly invoked by user (`/atdd-kit:*`)

### Skill Chain

```
bug (auto) → defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying
```

- `bug` auto-triggers on a bug report and routes into `defining-requirements`
- Each step chains forward to the next on completion
- `skill-gate` ensures the relevant step skill is invoked before direct work begins
- All core skills include a Session Start Check that runs `session-start` if it hasn't yet

### Addon System

Platform-specific features live in `addons/<platform>/`. Each addon has an `addon.yml` manifest declaring MCP servers, hooks, deploy files, and CI fragments. See `addons/README.md`.

### Agents

Reviewer role definitions live in `agents/`, spawned by the `reviewing-deliverables` skill (Step 5). Each agent has YAML frontmatter (`name`, `description`, `tools`, `skills`) and a system prompt body. See `agents/README.md`.

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

### Skill Changes Require Test Evidence

Skills are **behavior-shaping code**, not prose. Any modification to a skill's SKILL.md requires:

1. Run the skill's BATS test (`tests/test_<skill>_skill.bats`) before and after the change
2. Keep the suite green — a skill edit must not break its pinned structural assertions
3. Do NOT remove Rationalization tables, `<HARD-GATE>` blocks, or carefully-tuned enforcement content without a corresponding test update that justifies it

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
├── skills/           # Skill definitions (SKILL.md)
│   ├── bug/
│   ├── debugging/
│   ├── defining-requirements/
│   ├── extracting-user-stories/
│   ├── launching-preview/
│   ├── merging-and-deploying/
│   ├── reviewing-deliverables/
│   ├── running-atdd-cycle/
│   ├── session-start/
│   ├── sim-pool/             # iOS addon skill (in skills/ for framework discovery)
│   ├── skill-fix/
│   ├── skill-gate/
│   ├── ui-test-debugging/    # iOS addon skill
│   ├── writing-design-doc/
│   └── writing-plan-and-tests/
├── agents/           # Reviewer role definitions (prd/us/plan/code/at/final-reviewer) spawned by reviewing-deliverables
├── addons/           # Platform-specific addon packages (ios/, web/)
│   └── ios/          # iOS addon (addon.yml, scripts/, ci/, tests/)
├── commands/         # User-invoked slash commands (/atdd-kit:*)
├── rules/            # Always-loaded rules (60-line budget, loaded every turn)
├── docs/             # On-demand reference documents (loaded by skills when needed)
│   ├── guides/       # How-to guides and reference materials (commit-guide, review-guide, etc.)
│   ├── methodology/  # Methodology deep-dives (atdd-guide, bug-fix-process)
│   ├── product/      # Product strategy (product-goal, impact-map, story-map, roadmap)
│   ├── specs/        # User Story + AC spec files (Living Documentation, persisted beyond Issue closure)
│   └── workflow/     # Workflow reference (workflow-detail, issue-ready-flow)
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
name: defining-requirements
description: "Explore requirements through dialogue and derive ACs (Given/When/Then)."
---

## Session Start Check (required)
...
# defining-requirements Skill -- Requirements Exploration
...
```

The `description` field controls auto-trigger behavior. It must contain **trigger conditions only** — never workflow summaries (see Architecture Decisions above).

### Auto-trigger vs Manual Skills

| Type | Trigger | Examples |
|------|---------|----------|
| **Auto-trigger** | Claude detects matching user intent from `description` | bug, debugging, skill-gate, skill-fix |
| **Workflow chain** | Previous skill chains forward | defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying |
| **Manual** | User invokes explicitly | session-start, sim-pool |

### Skill Chain

```
bug (auto) → defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying
```

- `bug` auto-triggers on a bug report and routes into `defining-requirements`
- Each skill chains to the next upon completion
- All core skills include a Session Start Check that runs `session-start` if it hasn't run yet
- Skills with state gates (running-atdd-cycle, merging-and-deploying) check Issue labels before proceeding

## Adding a New Skill

1. **Create the directory**: `skills/<name>/`
2. **Write `SKILL.md`** with YAML frontmatter (`name`, `description`) and step-by-step instructions
3. **Add a BATS test** (recommended): Create `tests/test_<name>_skill.bats` pinning the skill's structural assertions
4. **Update `skills/README.md`** to include the new skill in the directory listing
5. **Update `CHANGELOG.md`** with the new skill entry
6. **Bump version** in `.claude-plugin/plugin.json`

### Checklist

- [ ] `description` contains trigger conditions only (no workflow summaries)
- [ ] Session Start Check is included if the skill is part of the core workflow
- [ ] `skills/README.md` is updated
- [ ] `CHANGELOG.md` has an entry
- [ ] Version is bumped in `.claude-plugin/plugin.json`
