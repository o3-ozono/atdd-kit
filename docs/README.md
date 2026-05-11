# Docs

On-demand reference documents loaded by skills and commands. These are not always-loaded -- skills read specific files when they need detailed context.

## guides/

How-to guides and reference materials for day-to-day usage.

| Document | Description |
|----------|-------------|
| [commit-guide.md](guides/commit-guide.md) | Commit message conventions and examples |
| [testing-skills.md](guides/testing-skills.md) | Impact scope detection — `@covers` format, `impact_map.sh` usage |
| [doc-sync-checklist.md](guides/doc-sync-checklist.md) | Pre-PR documentation sync checklist |
| [error-handling.md](guides/error-handling.md) | Error handling rules for implementation skills |
| [getting-started.md](guides/getting-started.md) | First-time user walkthrough from feature to merged PR |
| [review-guide.md](guides/review-guide.md) | PR review guide for ship and QA |
| [skill-authoring-guide.md](guides/skill-authoring-guide.md) | Dialogue UX design principles for skill authors |
| [skill-status-spec.md](guides/skill-status-spec.md) | SKILL_STATUS block field definitions and autopilot action matrix |

## product/

Product strategy and prioritization documents.

| Document | Description |
|----------|-------------|
| [product-goal.md](product/product-goal.md) | Product Goal — why atdd-kit exists and success indicators |
| [impact-map.md](product/impact-map.md) | Impact Map — Actors, Impacts, and Deliverable links to open Issues |
| [story-map.md](product/story-map.md) | Story Map — Backbone (skill chain), Walking Skeleton, and next slices |
| [roadmap.md](product/roadmap.md) | Roadmap — Now / Next / Later lanes (quarterly cadence) |

## methodology/

Deep-dive methodology documents for ATDD, Scrumban, and related practices.

| Document | Description |
|----------|-------------|
| [atdd-guide.md](methodology/atdd-guide.md) | ATDD methodology guide for the atdd skill and Issue templates |
| [bug-fix-process.md](methodology/bug-fix-process.md) | Bug fix workflow and triage process |
| [definition-of-done.md](methodology/definition-of-done.md) | Definition of Done — AC gate, CI gate, PR gate, documentation gate |
| [definition-of-ready.md](methodology/definition-of-ready.md) | Definition of Ready — criteria for Issue to reach ready-to-go state |
| [scrumban.md](methodology/scrumban.md) | Scrumban + ATDD integrated methodology — terminology, label table, solo adaptations |
| [story-splitting.md](methodology/story-splitting.md) | Story splitting guide — SPIDR patterns, Lawrence 9-pattern |
| [test-mapping.md](methodology/test-mapping.md) | AC-to-test-layer mapping and Testing Quadrants reference |
| [us-ac-format.md](methodology/us-ac-format.md) | US/AC spec file format definition (frontmatter schema, status transitions, filename convention) |

## workflow/

Workflow reference documents for the full Issue lifecycle.

| Document | Description |
|----------|-------------|
| [autonomy-levels.md](workflow/autonomy-levels.md) | Autonomy level definitions and escalation rules |
| [issue-ready-flow.md](workflow/issue-ready-flow.md) | Issue Ready flow (discover + plan) reference |
| [workflow-detail.md](workflow/workflow-detail.md) | Full workflow detail for session-start and autopilot |

## specs/

User Story + Acceptance Criteria spec files. Spec files persist ACs beyond Issue closure as Living Documentation.

| Document | Description |
|----------|-------------|
| [README.md](specs/README.md) | Directory purpose, naming convention, and operational rules |
| [TEMPLATE.md](specs/TEMPLATE.md) | Blank template for new spec files |
| [us-ac-format.md](specs/us-ac-format.md) | Sample spec: US/AC format convention introduced in #66 |

## personas/

Research-based persona files. Personas anchor User Stories to specific characters and prevent the Elastic User Problem.

| Document | Description |
|----------|-------------|
| [README.md](personas/README.md) | Directory purpose, template usage, and one-file-per-persona convention |
| [TEMPLATE.md](personas/TEMPLATE.md) | Blank template for creating new persona files |

## References

- [DEVELOPMENT.md](../DEVELOPMENT.md) -- Always-loaded rules budget, language policy
- [rules/](../rules/) -- Always-loaded rules (60-line budget)
