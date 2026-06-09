# Commands

Commands are explicitly invoked by the user via `/atdd-kit:<name>`. Unlike skills, they are not auto-detected — they run only when called directly.

See [DEVELOPMENT.md](../DEVELOPMENT.md) for the distinction between skills and commands.

## Command List

| Command | Purpose | Invocation |
|---------|---------|------------|
| [autopilot](autopilot.md) | Run an Issue in autopilot — autonomously converge its deliverables to near-green (invokes `converging-deliverables`) | `/atdd-kit:autopilot <issue>` |
| [maintenance](maintenance.md) | On-demand rule and documentation health check; creates/updates maintenance Issue | `/atdd-kit:maintenance` |
| [skill-fix](skill-fix.md) | Manually trigger the atdd-kit skill-defect report flow | `/atdd-kit:skill-fix` |
| [setup-github](setup-github.md) | Set up GitHub issue/PR templates and labels | `/atdd-kit:setup-github` |
| [setup-ci](setup-ci.md) | Generate CI workflow from base + addon CI fragments | `/atdd-kit:setup-ci` |
| [setup-ios](setup-ios.md) | Manually set up iOS addon (MCP servers, hooks, scripts) | `/atdd-kit:setup-ios` |
| [setup-web](setup-web.md) | Manually set up Web addon (placeholder for future) | `/atdd-kit:setup-web` |

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — Skills vs Commands distinction
- [docs/workflow/workflow-detail.md](../docs/workflow/workflow-detail.md) — Full workflow documentation
