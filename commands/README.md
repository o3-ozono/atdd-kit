# Commands

Commands are explicitly invoked by the user via `/atdd-kit:<name>`. Unlike skills, they are not auto-detected — they run only when called directly.

See [DEVELOPMENT.md](../DEVELOPMENT.md) for the distinction between skills and commands.

## Command List

| Command | Purpose | Invocation |
|---------|---------|------------|
| [autopilot](autopilot.md) | Autopilot end-to-end workflow; main Claude orchestrates discover → plan → implement → review → merge with task-type-specific Agent Teams | `/atdd-kit:autopilot` |
| [auto-eval](auto-eval.md) | Runs skill evals for changed skills, compares against baseline, posts results as PR comment | `/atdd-kit:auto-eval` |
| [auto-sweep](auto-sweep.md) | Detects state transition anomalies and sends notifications | `/atdd-kit:auto-sweep` |
| [maintenance](maintenance.md) | On-demand rule and documentation health check; creates/updates maintenance Issue | `/atdd-kit:maintenance` |
| [setup-github](setup-github.md) | Set up GitHub issue/PR templates and labels | `/atdd-kit:setup-github` |
| [setup-ci](setup-ci.md) | Generate CI workflow from base + addon CI fragments | `/atdd-kit:setup-ci` |
| [setup-ios](setup-ios.md) | Manually set up iOS addon (MCP servers, hooks, scripts) | `/atdd-kit:setup-ios` |
| [setup-web](setup-web.md) | Manually set up Web addon (placeholder for future) | `/atdd-kit:setup-web` |

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — Skills vs Commands distinction
- [docs/workflow/workflow-detail.md](../docs/workflow/workflow-detail.md) — Full workflow documentation
