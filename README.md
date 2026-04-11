# atdd-kit

[日本語](README.ja.md)

Run your development process with ATDD (Acceptance Test Driven Development) — from Issue to merge.

A Claude Code plugin that gives you a complete workflow: create an Issue, explore requirements, derive acceptance criteria, write tests first, implement, verify, and ship.

## Why atdd-kit?

AI coding assistants can write code, but they lack a structured development process. Without guardrails, they skip requirements exploration, write code before tests, and merge without verification.

atdd-kit solves this by enforcing an **Issue-driven, test-first workflow**:

- **Every change starts with an Issue** — no code without a tracked requirement
- **Acceptance criteria are derived through dialogue** — not assumed
- **Tests are written before implementation** — ATDD double loop (E2E first, then unit tests)
- **Evidence-based verification** — every AC is verified with test results before merge

Design principles: zero dependencies, plugin architecture, pure markdown + bash.

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
| `/atdd-kit:autopilot` | PO-led Agent Teams (PO/Developer/QA) for end-to-end Issue completion |
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
  P1["Phase 1: discover\n(PO leads)"] --> P2["Phase 2: plan\n(PO orchestrates, Developer + QA lead)"]
  P2 --> P3["Phase 3: Implementation\n(Developer: atdd → verify → ship)"]
  P3 --> P4["Phase 4: PR Review\n(QA reviews)"]
  P4 --> P5["Phase 5: Cross-Cutting Checks & Merge\n(PO merges)"]
```

### Agent Teams

PO/Developer/QA run as Agent Teams teammates:

| Agent | Role |
|-------|------|
| **PO** | Team lead — discover, plan orchestration, merge decision |
| **Developer** | Implementation — ATDD double loop, fixes |
| **QA** | Reviews — plan review and PR code review (no code changes) |

```bash
# Auto-detect in-progress Issue, launch Agent Teams
/atdd-kit:autopilot

# Target a specific Issue
/atdd-kit:autopilot 123
/atdd-kit:autopilot search keywords
```

### Label Flow

```
[Issue]  (no label) → in-progress → ready-for-plan-review → ready-to-implement → in-progress
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
