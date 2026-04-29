# Scrumban + ATDD — Integrated Methodology

> **Loaded by:** discover skill, plan skill, session-start skill

## Definition and Adoption Rationale

**Scrumban** is a hybrid methodology combining Scrum's structure with Kanban's flow-based pull system. atdd-kit adopts it for solo development because:

- **Scrum** provides cadence artifacts (Product Goal, DoR, DoD, Increment) that prevent drift without requiring a full team.
- **Kanban** provides WIP limit and pull-based flow that prevents overload when working alone.
- **ATDD** provides the quality gate: no implementation without AC-driven tests.

The combination fits the primary persona (Hiro — solo developer) who needs structure without ceremony.

参考: Corey Ladas, *Scrumban* (2008) — https://leanpub.com/scrumban

## Industry Standard ↔ atdd-kit Terminology

### Core Terms

| Industry Standard | atdd-kit Term | Notes |
|-------------------|---------------|-------|
| Product Goal | Product Goal | Documented in [product-goal.md](../product/product-goal.md) |
| Product Backlog | GitHub Issues | Open Issues ordered by roadmap lane |
| Backlog Refinement | discover skill | Requirement exploration + AC derivation + INVEST check |
| Definition of Ready (DoR) | DoR | See [definition-of-ready.md](./definition-of-ready.md) |
| Definition of Done (DoD) | DoD | See [definition-of-done.md](./definition-of-done.md) |
| Increment | PR / merge | One merged PR = one Increment (potentially shippable) |
| Sprint Goal | (intentionally omitted) | See "Solo Development Adaptations" below |
| User Story (US) | US | "As a [persona], I want to [goal], so that [benefit]." |
| Acceptance Criteria (AC) | AC | Given / When / Then — see [us-ac-format.md](./us-ac-format.md) |
| Story Points / Sizing | MoSCoW + Size label | M/S/C/W priority; XS/S/M/L/XL size |

### Skill Chain Terms

| atdd-kit Skill | Workflow Role |
|----------------|---------------|
| issue / bug / ideate | Backlog item creation |
| discover | Backlog Refinement (AC derivation) |
| plan | Sprint Planning equivalent (test strategy) |
| atdd | Implementation (double-loop TDD) |
| verify | Done confirmation (evidence-based) |
| ship | Increment delivery (PR merge + changelog) |

### Autopilot Label Correspondence

The autopilot system uses GitHub Issue labels to track flow state. Labels map to Kanban columns (implemented in Phase B — #168).

| Label | State | Description |
|-------|-------|-------------|
| `ready-for-plan-review` | Plan Review | Plan awaiting Reviewer check |
| `ready-to-go` | Ready to Implement | Plan passed review; AC-first implementation can start |
| `implementing` | In Progress | atdd skill active |
| `ready-for-PR-review` | PR Review | Implementation complete; PR awaiting review |
| `needs-plan-revision` | Plan Revision | Reviewer requested plan changes |
| `needs-pr-revision` | PR Revision | PR review requested changes |
| `in-progress` | In Progress (generic) | Active work not yet at implementing stage |
| `blocked-ac` | Blocked | AC ambiguity or conflict blocks progress |
| `express-mode` | Express | Trivial change on fast path (skips discover/plan) |
| ~~`ready-to-implement`~~ | **Deprecated** | Superseded by `ready-to-go`. Scheduled for removal in Phase E (#171). |

## Solo Development Adaptations

Scrum ceremonies designed for teams are adapted or removed for solo use.

| Scrum Artifact / Ceremony | Status | Reasoning |
|---------------------------|--------|-----------|
| Product Goal | **Kept** | Critical anchor for prioritization — prevents scope creep |
| Product Backlog | **Kept** | GitHub Issues serve this role |
| Definition of Ready | **Kept** | Enforces "ready before start"; see DoR doc |
| Definition of Done | **Kept** | Enforces "done before close"; see DoD doc |
| Increment | **Kept** | PR/merge unit — "potentially shippable" after each merge |
| Backlog Refinement | **Kept** | = discover skill; the primary quality gate |
| Sprint Goal | **Omitted** | No value for 1-person, 1-Issue flow; replaced by roadmap Now lane |
| Daily Scrum | **Omitted** | No team to sync with |
| Sprint Planning | **Omitted** | Replaced by plan skill per Issue |
| Sprint Review | **Omitted** | Replaced by verify + ship skills |
| Sprint Retrospective | **Planned** | Phase F (#172) — weekly retrospective via methodology |

## Increment Definition

An Increment in atdd-kit = **one merged PR that passes all ACs**.

- Each PR is a potentially shippable Increment.
- The DoD (see [definition-of-done.md](./definition-of-done.md)) defines "done" for an Increment.
- Multiple PRs may contribute to a single Issue (e.g., refactor + feature).
- The Increment is complete when the Issue is closed.

参考: Scrum Guide 2020 — "An Increment is a concrete stepping stone toward the Product Goal." https://scrumguides.org/scrum-guide.html

## GitHub Project

> **Phase B (#168)** — Kanban Board implemented on GitHub Projects v2.

### Project URL

https://github.com/users/o3-ozono/projects/<TBD>

### Custom Fields

| Field | Type | Creation | Options / Notes |
|-------|------|----------|-----------------|
| Status | Single-select | CLI | 8 options: Backlog / Shaped (Pitch済) / Ready (DoR満) / In Discover / In Plan / In ATDD / In Review (PR) / Done |
| Skill | Single-select | CLI | discover / plan / atdd / verify / ship / bug / issue / express / ideate / debugging / N/A |
| Phase | Single-select | CLI | discover / plan / atdd / verify / ship |
| Size | Single-select | CLI | S / M / L / XL |
| Impact | Text | CLI | Free text referencing Impact Map branch |
| Epic | Text | CLI | Issue number reference (e.g. #165) |
| Iteration | Iteration | **Web UI only** | Now (current..+4w) / Next (+4w..+8w) / Later (+8w..+12w) — CLI `gh project field-create` does not support ITERATION type |

### Status ↔ Autopilot Label Mapping

The full autopilot label definitions are in [Autopilot Label Correspondence](#autopilot-label-correspondence) above.
The table below maps each Status option to the corresponding autopilot label:

| Status option | Autopilot label | Note |
|--------------|-----------------|------|
| Backlog | (none) | Not yet picked up |
| Shaped (Pitch済) | (none) | **Intentional gap** — no autopilot label exists for this pre-DoR state |
| Ready (DoR満) | `ready-to-go` | DoR passed; ready for implementation |
| In Discover | `in-progress` | discover skill active |
| In Plan | `ready-for-plan-review` | plan skill active |
| In ATDD | `implementing` | atdd skill active |
| In Review (PR) | `ready-for-PR-review` | PR under review |
| Done | (closed Issue) | Issue closed = Increment complete |

### Setup and Verification Scripts

- `scripts/setup-project.sh` — idempotent CLI setup (project create → fields → items → bulk-set)
- `scripts/verify-project.sh <project-number>` — automated AC2/AC5 verification

**Note:** Re-run `setup-project.sh` steps 5+6 (item-add + bulk-set) just before PR merge to capture any Issues opened after initial setup.

## References

- [definition-of-ready.md](./definition-of-ready.md) — DoR criteria
- [definition-of-done.md](./definition-of-done.md) — DoD criteria
- [story-splitting.md](./story-splitting.md) — When and how to split stories
- [atdd-guide.md](./atdd-guide.md) — ATDD double-loop TDD rules
- [us-ac-format.md](./us-ac-format.md) — US/AC spec file format (AC notation authority)
- [us-quality-standard.md](./us-quality-standard.md) — US quality MUST/SHOULD criteria
- [persona-guide.md](./persona-guide.md) — Persona creation and usage
- [test-mapping.md](./test-mapping.md) — AC-to-test-layer mapping
- [bug-fix-process.md](./bug-fix-process.md) — Bug classification and fix workflow
- [product-goal.md](../product/product-goal.md) — Product Goal statement
- [roadmap.md](../product/roadmap.md) — Now / Next / Later prioritization
