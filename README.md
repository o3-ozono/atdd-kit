# atdd-kit

[日本語](README.ja.md)

Run your development process with ATDD (Acceptance Test Driven Development) — from Issue to merge — like autonomous driving for your development process.

A Claude Code plugin that gives you a complete workflow: create an Issue, explore requirements, derive acceptance criteria, write tests first, implement, verify, and ship.

## Why atdd-kit?

AI coding assistants can write code, but they lack a structured development process. Without guardrails, they skip requirements exploration, write code before tests, and merge without verification.

atdd-kit solves this by enforcing an **Issue-driven, test-first workflow**:

- **Every change starts with an Issue** — no code without a tracked requirement
- **Acceptance criteria are derived through dialogue** — not assumed
- **Tests are written before implementation** — ATDD double loop (E2E first, then unit tests)
- **Evidence-based verification** — every AC is verified with test results before merge

Design principles: zero dependencies, plugin architecture, pure markdown + bash.

**Autopilot mode** takes the wheel. main Claude acts as the orchestrator, driving task-type-specific teams — Developer, QA, Tester, Reviewer, Researcher, Writer — from Issue to merge. You approve key checkpoints; agents handle the rest.

### The ATDD Double Loop

atdd-kit implements the Double-Loop TDD model from Freeman & Pryce's *[Growing Object-Oriented Software, Guided by Tests](https://www.amazon.com/Growing-Object-Oriented-Software-Guided-Tests/dp/0321503627)* (2009):

```
┌─ Outer Loop: Acceptance Test ─────────────────────┐
│                                                     │
│  RED       Write a failing end-to-end test          │
│                                                     │
│    ┌─ Inner Loop: Unit Test ────────────────────┐   │
│    │  RED       Write a failing unit test        │   │
│    │  GREEN     Minimal implementation           │   │
│    │  REFACTOR                    ↻ repeat       │   │
│    └─────────────────────────────────────────────┘   │
│                                                     │
│  GREEN     Acceptance test passes                   │
│  REFACTOR                                           │
└─────────────────────────────────────────────────────┘
```

Also influenced by:

- [ATDD by Example](https://www.amazon.com/dp/0321784154) (Markus Gärtner, 2012) — The practical ATDD guide that popularized the term "ATDD"
- [obra/superpowers](https://github.com/obra/superpowers) — Process enforcement patterns (Red Flags, `<HARD-GATE>`, Iron Laws)
- [BDD](https://cucumber.io/docs/bdd/) (Dan North) — Given/When/Then acceptance criteria format


## Quick Start

```bash
# 1. Register the marketplace (first time only)
claude plugins marketplace add https://github.com/o3-ozono/atdd-kit.git

# 2. Install (project scope recommended)
claude plugins install atdd-kit --scope project
```

Setup happens automatically on the first session. The `session-start` skill auto-detects your platform (iOS, Web, Other), shows what will be installed, and asks for confirmation. You can also run setup commands manually (`/atdd-kit:setup-github`, `/atdd-kit:setup-ios`, etc.). See [Getting Started — What Each Addon Installs](docs/getting-started.md#what-each-addon-installs) for details.

Then describe what you want to build — atdd-kit handles the rest.

See [Getting Started](docs/getting-started.md) for a full end-to-end walkthrough.

## How It Works

```mermaid
flowchart LR
  bug["bug (auto)"] --> discover
  issue["issue (auto)"] --> ideate["ideate (optional)"] --> discover
  discover --> plan --> approval["[approval]"] --> atdd --> verify --> ship
```

### Skills

#### Core Workflow

| Skill | What it does |
|-------|-------------|
| **discover** | Explore requirements through dialogue, derive Given/When/Then acceptance criteria |
| **plan** | Create a test-first implementation plan from acceptance criteria |
| **atdd** | Execute the ATDD double loop — outer E2E tests, inner unit tests |
| **verify** | Verify all acceptance criteria pass with fresh evidence |
| **ship** | Finalize PR, handle review cycle, squash merge |

#### Auto-trigger

| Skill | What it does |
|-------|-------------|
| **issue** | Auto-detects task requests and starts Issue creation |
| **bug** | Auto-detects bug reports and starts the triage pipeline |
| **ideate** | Design exploration -- auto-triggers on exploratory requests, also chains from issue before discover |
| **debugging** | Auto-detects error reports and starts root cause investigation |
| **skill-gate** | Ensures relevant skills are invoked before direct work |

#### Utilities

| Skill | What it does |
|-------|-------------|
| **session-start** | Reports git status, open PRs/Issues, and recommends next tasks |
| **sim-pool** | iOS simulator pool management (addon) |

### Commands

| Command | What it does |
|---------|-------------|
| `/atdd-kit:autopilot` | Autopilot — main Claude orchestrates task-type-specific Agent Teams for end-to-end Issue completion |
| `/atdd-kit:auto-sweep` | Sweeper utility (manual, on-demand) |
| `/atdd-kit:auto-eval` | Skill eval runner (detects regressions in skill quality) |
| `/atdd-kit:setup-github` | Set up GitHub issue/PR templates and labels |
| `/atdd-kit:setup-ci` | Generate CI workflow from base + addon fragments |
| `/atdd-kit:setup-ios` | Manually set up iOS addon (MCP servers, hooks, scripts) |
| `/atdd-kit:setup-web` | Manually set up Web addon (placeholder) |

## Architecture

### Workflow Phases

```mermaid
flowchart TD
  P1["Phase 1: discover\n(main Claude leads)"] --> P2["Phase 2: plan\n(main Claude orchestrates, task-type agents lead)"]
  P2 --> P3{"Task type branch"}
  P3 -->|development / bug| P3a["Developer + QA"]
  P3 -->|research| P3b["Researcher x N"]
  P3 -->|documentation| P3c["Writer + Reviewer x N"]
  P3 -->|refactoring| P3d["Developer + Reviewer x N"]
  P3a --> P4["Phase 4: PR Review\n(Reviewer x N)"]
  P3b --> P5["Phase 5: Merge\n(main Claude)"]
  P3c --> P4
  P3d --> P4
  P4 --> P5
```

### Agent Teams

main Claude acts as the orchestrator (PO role) and drives task-type-specific teams. Six agents are available:

| Agent | Role | Model |
|-------|------|-------|
| **Developer** | ATDD implementation, cannot self-review | sonnet |
| **QA** | Test strategy and verification, cannot edit code | sonnet |
| **Tester** | Bug reproduction and fix verification | sonnet |
| **Reviewer** | Code review across task types, cannot edit code | sonnet |
| **Researcher** | Research and analysis, cannot edit code | sonnet |
| **Writer** | Documentation creation, can edit files | sonnet |

**Agent composition by task type** (see [autopilot.md](commands/autopilot.md) for details):

| Task Type | Phase 1 Agents | Phase 2 Agents |
|-----------|----------------|----------------|
| development | main Claude, Developer, QA | main Claude, Developer, Reviewer x N |
| bug | main Claude, Tester, Developer | main Claude, Developer, Tester, Reviewer x N |
| research | main Claude | main Claude, Researcher x N (min 2 per theme) |
| documentation | main Claude | main Claude, Writer, Reviewer x N |
| refactoring | main Claude | main Claude, Developer, Reviewer x N |

```bash
# Auto-detect in-progress Issue, launch Agent Teams
/atdd-kit:autopilot

# Target a specific Issue
/atdd-kit:autopilot 123
/atdd-kit:autopilot search keywords
```

### Label Flow

```
[Issue]  (no label) → in-progress → ready-for-plan-review → ready-to-go → in-progress
[PR]     ready-for-PR-review → needs-pr-revision (loop) → merge
```

See [Workflow Detail](docs/workflow-detail.md) for the full label state machine and transition rules.

## Configuration

### iOS Addon

When iOS is detected (or manually set up via `/atdd-kit:setup-ios`), the addon:
- Adds XcodeBuildMCP, ios-simulator, apple-docs, xcode to `.mcp.json`
- Deploys `sim-pool-guard.sh` and `lint-xcstrings.sh`
- Configures PreToolUse hooks for simulator exclusion

### Always-Loaded Rules

Only ~30 lines loaded every turn (kept minimal to save context):
- Issue-driven workflow principles
- Commit conventions (Conventional Commits)
- PR rules (squash merge)

Detailed guides live in `docs/` and load on-demand.

## Contributing

See [DEVELOPMENT.md](DEVELOPMENT.md) for the full development guide. Key rules:

- **Versioning**: Every feature PR must bump version in `.claude-plugin/plugin.json` and update `CHANGELOG.md`
- **Zero dependencies**: No npm packages, no external services — pure markdown + bash
- **Language**: LLM-facing files are English only. User-facing README/DEVELOPMENT maintain en/ja pairs in sync

## Recommended Companion Tools

| Tool | Purpose |
|------|---------|
| [swiftui-expert-skill](https://github.com/AvdLee/swiftui-expert-skill) | SwiftUI best practices (iOS projects) |

## License

MIT
