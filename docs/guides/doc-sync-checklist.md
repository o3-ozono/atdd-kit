# Documentation Sync Checklist

Every PR must verify that documentation stays in sync with the changes. Before marking a PR as ready for review, check all applicable items below.

## Always Check

| Item | When applicable |
|------|----------------|
| `CHANGELOG.md` updated | Every feature/fix PR |
| Version bumped in `.claude-plugin/plugin.json` | Every feature PR |
| `README.md` and `README.ja.md` in sync | Any user-facing change (new command, skill, feature) |

## If You Changed Skills or Commands

| Item | When applicable |
|------|----------------|
| Skills table in README updated | New/renamed/removed skill |
| Commands table in README updated | New/renamed/removed command |
| `docs/workflow/workflow-detail.md` updated | New process, label change, or flow change |
| `commands/autopilot.md` updated | New auto-* command |

## If You Changed Architecture or Rules

| Item | When applicable |
|------|----------------|
| `DEVELOPMENT.md` and `DEVELOPMENT.ja.md` in sync | Architecture decision, new convention, or process change |
| `rules/atdd-kit.md` updated | New workflow rule (stay under 40 lines) |
| `docs/guides/review-guide.md` updated | New review criteria |

## If You Changed Eval-Related Files

| Item | When applicable |
|------|----------------|
| `skills/<name>/evals/baseline.json` updated | Eval assertions changed |
| Eval results verified | SKILL.md modified |

## How to Use

This checklist is enforced by the `Documentation Sync` rule in `rules/atdd-kit.md`. Reviewers (both human and `QA (autopilot)`) should verify these items during PR review.

If a doc update is not applicable, no action is needed. The key principle: **a reader of the docs should never be surprised by the current state of the code.**
