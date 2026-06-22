# Commands

Commands are explicitly invoked by the user via `/atdd-kit:<name>`. Unlike skills, they are not auto-detected — they run only when called directly.

See [DEVELOPMENT.md](../DEVELOPMENT.md) for the distinction between skills and commands.

## Command List

| Command | Purpose | Invocation |
|---------|---------|------------|
| [express](express.md) | Documentation-grade Issue fast path — skips PRD/US/plan/AT/review; requires explicit approval and CI gate | `/atdd-kit:express <issue>` |
| [bugfix](bugfix.md) | bugfix lightweight route — chains `bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying`, skips PRD/US/plan/AT spec; middle gate is cause-agreement, merge stays a User gate | `/atdd-kit:bugfix <issue>` |
| [flaky-fix](flaky-fix.md) | flaky-test-fix lightweight route — chains `bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying`, skips PRD/US/plan/AT spec; middle gate is cause-agreement (non-determinism classification + failure rate); convergence oracle is N consecutive greens | `/atdd-kit:flaky-fix <issue>` |
| [maintenance](maintenance.md) | On-demand rule and documentation health check; creates/updates maintenance Issue | `/atdd-kit:maintenance` |
| [skill-fix](skill-fix.md) | Manually trigger the atdd-kit skill-defect report flow | `/atdd-kit:skill-fix` |
| [setup-github](setup-github.md) | Set up GitHub issue/PR templates and labels | `/atdd-kit:setup-github` |
| [setup-ci](setup-ci.md) | Generate CI workflow from base + addon CI fragments | `/atdd-kit:setup-ci` |
| [setup-ios](setup-ios.md) | Manually set up iOS addon (MCP servers, hooks, scripts) | `/atdd-kit:setup-ios` |
| [setup-web](setup-web.md) | Manually set up Web addon (deploys impact_map.sh + impact_rules.yml template) | `/atdd-kit:setup-web` |
| [setup-discord](setup-discord.md) | Opt-in: set up the Discord notifications addon (per-issue threads for full-autopilot) | `/atdd-kit:setup-discord` |

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — Skills vs Commands distinction
- [docs/workflow/workflow-detail.md](../docs/workflow/workflow-detail.md) — Full workflow documentation
