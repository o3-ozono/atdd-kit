# Issue Ready Flow

> **Loaded by:** discover, plan skills

After creating an Issue, execute the following steps in order before approval (`ready-to-implement` label). **Do not skip any step.**

## Principles

- **No code edits before approval.** Do not start implementation until all steps are complete and the user approves.
- **Deliverables go in Issue comments.** Design artifacts, ACs, and implementation plans are posted as Issue comments. Repository commits happen only on the work branch after `ready-to-implement` approval.

## Development Tasks (`type:development`)

| Step | Action | Skill/Command | Output |
|------|--------|---------------|--------|
| 1 | **Create Issue** | `issue` | Issue (no `in-progress` label yet) |
| 1.5 | **Design exploration (optional)** | `ideate` (post-Issue mode) | Approach comparison, design decision -> Issue comment (Context Block). Skippable. |
| 2 | **Brainstorming** | `discover` (brainstorming mode) | Acquires `in-progress` lock. Requirements, approach, impact analysis -> Issue comment |
| 3 | **User story and AC** | `discover` (AC mode) | ATDD-based ACs -> Issue comment |
| 4 | **Test strategy and implementation strategy** | `plan` | Test strategy (AC→test layer mapping) + implementation strategy -> Issue comment |
| 5 | **Plan review** | Reviewer (`ready-for-plan-review`) | Plan review results -> Issue comment. Reviewer PASS -> label: `ready-to-implement` |

## Bug Reports (`type:bug`)

| Step | Action | Skill/Command | Output |
|------|--------|---------------|--------|
| 1 | **Intake and Issue creation** | `/bug` Phase 1-2 | Issue (no `in-progress` label yet) |
| 2 | **Root cause investigation** | `/bug` Phase 3-5 | Reproduction, evidence, root cause -> Issue comment |
| 2.5 | **Design exploration (optional)** | `ideate` (post-Issue mode) | Approach comparison for fix strategy. Skippable. |
| 3 | **Brainstorming** | `discover` (bug mode) | Fix approach, impact, design decisions -> Issue comment |
| 4 | **User story and AC** | `discover` (AC mode) | ATDD-based ACs -> Issue comment |
| 5 | **Test strategy and implementation strategy** | `plan` | Test strategy + implementation strategy -> Issue comment |
| 6 | **Plan review** | Reviewer (`ready-for-plan-review`) | Plan review results -> Issue comment. Reviewer PASS -> label: `ready-to-implement` |

## Refactoring (`type:development` + `refactoring`)

Same flow as development tasks.

## Documentation / Investigation (`type:documentation` / `type:investigation`)

| Step | Action | Skill/Command | Output |
|------|--------|---------------|--------|
| 1 | **Create Issue** | -- | Issue (no `in-progress` label yet) |
| 2 | **Brainstorming** | `discover` | Acquires `in-progress` lock. Scope and approach -> Issue comment |
| 3 | **Define completion criteria** | -- | Verifiable completion criteria -> Issue comment |
| 4 | **Work plan** | `plan` | Work plan -> Issue comment |
| 5 | **Plan review** | Reviewer (`ready-for-plan-review`) | Plan review results -> Issue comment. Reviewer PASS -> label: `ready-to-implement` |

## Readiness Check (Approval Gate)

Before adding `ready-to-implement` label, verify all of the following.

| Check | Bad Example | Good Example |
|-------|-------------|-------------|
| Completion criteria are verifiable | "improved" | "zero build errors" |
| Subtasks are concrete | "investigate", "organize" | "change X to Y" |
| Design decisions are resolved | "choose approach A or B" | "approach A chosen (reason: ...)" |
| Target files are identified | "improve CI" | "change ci.yml line 100" |
| ATDD ACs are posted to Issue | no ACs | ACs in checklist format |
| Implementation plan exists | no plan | plan posted as Issue comment |
| Plan review passed | no review | Reviewer approved plan |

When all checks pass, the Issue is an "execution spec" that an AI can work from autonomously.
