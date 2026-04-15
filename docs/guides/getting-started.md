# Getting Started

This guide walks you through your first complete workflow with atdd-kit — from describing a feature to merging a PR.

> The examples below show a typical flow. Actual output varies depending on your project configuration and Claude's responses.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- A Git repository with a GitHub remote

## Installation

```bash
# 1. Register the marketplace (first time only)
claude plugins marketplace add https://github.com/o3-ozono/atdd-kit.git

# 2. Install (project scope recommended)
claude plugins install atdd-kit --scope project
```

## Initial Setup

Setup happens automatically on the first session. The `session-start` skill auto-detects your platform (iOS, Web, Other), shows what will be installed, and asks for confirmation before proceeding.

You can also run setup commands manually:

| Command | Purpose |
|---------|---------|
| `/atdd-kit:setup-github` | Set up GitHub issue/PR templates and labels |
| `/atdd-kit:setup-ci` | Generate CI workflow from base + addon fragments |
| `/atdd-kit:setup-ios` | Set up iOS addon (MCP servers, hooks, scripts) |
| `/atdd-kit:setup-web` | Set up Web addon (placeholder) |

### What Each Addon Installs

When a platform addon is activated, the following components are added to your project. The full manifest is in `addons/<platform>/addon.yml`.

#### iOS Addon

| Category | Component | Description |
|----------|-----------|-------------|
| **MCP Server** | XcodeBuildMCP | Xcode build/test automation |
| **MCP Server** | ios-simulator | iOS simulator control |
| **MCP Server** | apple-docs | Apple documentation access |
| **MCP Server** | xcode | Xcode MCP bridge |
| **Hook** | sim-pool-guard (XcodeBuildMCP) | PreToolUse guard for simulator exclusive access |
| **Hook** | sim-pool-guard (ios-simulator) | PreToolUse guard for simulator exclusive access |
| **Deploy** | `.claude/hooks/sim-pool-guard.sh` | Simulator pool guard script |
| **Deploy** | `scripts/lint-xcstrings.sh` | Japanese translation coverage linter |
| **Skill** | sim-pool | Simulator pool management (ephemeral clones, golden image isolation) |
| **Skill** | ui-test-debugging | CI UI test failure diagnosis |
| **CI** | `addons/ios/ci/build-and-test.yml` | xcodebuild job fragment for GitHub Actions |

## Your First Feature — End-to-End Walkthrough

Let's walk through building a small feature using atdd-kit's full workflow.

### Step 1: Describe What You Want

Just tell Claude what you need in natural language. The **issue** skill auto-detects your intent and creates a GitHub Issue.

```
You: I want to add a /health endpoint that returns the app version
```

Claude creates a GitHub Issue from your description and automatically starts **discover**.

### Step 2: discover — Requirements Exploration

The **discover** skill explores your requirements through dialogue and derives acceptance criteria in Given/When/Then format.

```
Claude: Let me explore the requirements for the /health endpoint.

  Questions:
  1. Should the endpoint require authentication?
  2. What HTTP status code should it return?
  3. Should it include uptime or just the version?

You: No auth, 200 OK, just the version from package.json

Claude: Here are the proposed acceptance criteria:

  CC1: GET /health returns 200 with version
    Given the server is running
    When GET /health is called
    Then it responds with 200 and {"version": "<package.json version>"}

  CC2: /health requires no authentication
    Given no auth headers are provided
    When GET /health is called
    Then it responds with 200 (not 401/403)

  Do you approve these acceptance criteria?

You: Yes
```

### Step 3: plan — Implementation Strategy

After you approve the acceptance criteria, **plan** automatically creates a test strategy and implementation strategy.

The plan includes:
- **Test strategy** — What tests to write and how to verify each acceptance criterion
- **Implementation strategy** — File changes, implementation order, design decisions

### Step 4: Approval Gate

The plan undergoes review. In manual mode, you review and approve. In autopilot mode, the Dev and QA agents review the plan.

Once approved, the Issue receives the `ready-to-go` label — the green light for implementation.

### Step 5: atdd — Test-First Implementation

The **atdd** skill implements your feature using the ATDD double loop:

1. **Outer loop (E2E)** — Write a failing end-to-end test for each acceptance criterion
2. **Inner loop (Unit)** — Write unit tests, then implement until all tests pass
3. **Verify outer loop** — Confirm the E2E test now passes

Each acceptance criterion is implemented as a separate commit:
```
feat: #42 GET /health returns 200 with version (CC1)
feat: #42 /health requires no authentication (CC2)
```

### Step 6: verify — Evidence-Based Verification

The **verify** skill runs all tests and collects evidence for each acceptance criterion. It checks:

- All tests pass
- Each AC has corresponding test coverage
- No regressions in existing tests

Verify produces an evidence table mapping each AC to its test results.

### Step 7: ship — PR and Merge

The **ship** skill finalizes the process:

1. Creates a pull request (or updates the existing draft)
2. Adds the `ready-for-PR-review` label
3. Handles the review cycle (addresses reviewer comments, re-requests review)
4. Squash merges when approved and CI passes

```
Claude: PR #43 created: feat: #42 add /health endpoint
        Status: ready-for-PR-review
        URL: https://github.com/you/your-repo/pull/43
```

## Going Further

### Autopilot Mode

Once you're comfortable with the manual workflow, try **autopilot** for hands-off execution:

```bash
# Auto-detect an in-progress Issue and run the full workflow
/atdd-kit:autopilot

# Target a specific Issue
/atdd-kit:autopilot 42
```

Autopilot runs main Claude as orchestrator with Dev and QA as Agent Teams teammates. main Claude orchestrates, Dev implements, and QA reviews — all coordinated automatically.

### Bug Reports

Just describe a bug naturally — the **bug** skill auto-detects keywords like "broken", "crash", "error" and starts the triage pipeline:

```
You: The /users endpoint returns 500 when the email contains a plus sign
```

### Customization

- **Autonomy levels**: Configure how much human approval is needed (see `docs/workflow/autonomy-levels.md`)
- **iOS addon**: Platform-specific tooling for iOS projects (auto-detected or via `/atdd-kit:setup-ios`)

### Reference

- [Workflow Detail](../workflow/workflow-detail.md) — Label flow, state transitions, and phase details
- [ATDD Guide](../methodology/atdd-guide.md) — Deep dive into the ATDD double-loop methodology
- [Review Guide](review-guide.md) — PR review process and criteria
- [Error Handling](error-handling.md) — Common errors and how to resolve them
- [Development Guide](../DEVELOPMENT.md) — Contributing to atdd-kit itself
