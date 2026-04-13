# Skills

Skills are auto-detected or workflow-chained behaviors that shape how Claude Code operates within a project. Each skill has a `SKILL.md` with trigger conditions and detailed instructions.

See [DEVELOPMENT.md](../DEVELOPMENT.md) for the distinction between skills and commands.

## Workflow Chain

```
bug/issue (auto) → ideate (optional) → discover → plan → [approval gate] → atdd → verify → ship
```

## State Gate

Skills in the core workflow chain (plan, atdd, verify, ship) include a **State Gate** that verifies GitHub label preconditions before execution. This prevents workflow violations structurally:

| Skill | Required Label | Gate Action on Pass |
|-------|---------------|-------------------|
| plan | `in-progress` + discover deliverables | Proceed to planning |
| atdd | `ready-to-go` | Remove label, add `in-progress` |
| verify | `in-progress` | Proceed to verification |
| ship | `in-progress` | Proceed to ship flow |

Additionally, `skill-gate` enforces **Iron Law #1**: no code editing without an Issue.

## Skill List

| Skill | Trigger | Workflow Position |
|-------|---------|-------------------|
| [atdd](atdd/) | Manually invoked on ready-to-go Issues | Core chain: implementation |
| [bug](bug/) | Auto-triggers on bug/error keywords | Entry point → chains to discover |
| [debugging](debugging/) | Auto-triggers on bug reports, errors, crashes | Pre-fix root cause investigation |
| [discover](discover/) | First step of Issue Ready flow | Core chain: requirements → ACs |
| [ideate](ideate/) | Auto-triggers on exploratory design requests; also chained from issue | Between issue and discover (optional, skippable) |
| [issue](issue/) | Auto-triggers on feature/task requests | Entry point → chains to ideate |
| [plan](plan/) | Second step of Issue Ready flow | Core chain: test & implementation strategy |
| [session-start](session-start/) | Auto-invoked by other skills | Session initialization |
| [ship](ship/) | Manually invoked after verify passes | Core chain: PR finalization → merge |
| [sim-pool](sim-pool/) | Auto-triggers before iOS simulator tool calls | iOS simulator access management |
| [skill-gate](skill-gate/) | Auto-triggers on every user message | Skill enforcement gate |
| [ui-test-debugging](ui-test-debugging/) | Auto-triggers on CI UI Test failures | CI UI Test failure diagnosis |
| [verify](verify/) | Manually invoked before claiming completion | Core chain: evidence-based verification |

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — Skills vs Commands, skill description field rules, eval requirements
- Each skill's `SKILL.md` — Full trigger conditions and instructions
- [agents/](../agents/) — Role definitions for autopilot (PO, Developer, QA, Tester, Reviewer, Researcher, Writer)
- [addons/](../addons/) — Platform-specific addon packages
