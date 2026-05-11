# Rules

Rules are markdown files loaded into Claude Code's context on every turn. They define behavioral constraints that the agent must follow at all times.

## Budget Constraint

`atdd-kit.md` is loaded on **every turn** and must stay under **60 lines**. Detailed guidance belongs in `docs/` instead. (Budget raised from 40 to 60 during v1.0 migration; see `DEVELOPMENT.md` § Always-Loaded Rules Budget.)

## Files

| File | Purpose |
|------|---------|
| [atdd-kit.md](atdd-kit.md) | Core rules for atdd-kit users: Issue-driven workflow, commit conventions, PR rules, label flow |

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) — "Always-Loaded Rules Budget" section
- [docs/](../docs/) — Extended documentation referenced by the rules
