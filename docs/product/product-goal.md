# Product Goal

> **Loaded by:** discover skill, issue skill

## Why atdd-kit Exists

**Problem:** AI coding assistants make it easy to skip quality steps — Issue creation, AC derivation, test-first discipline — especially under time pressure or on tired evenings.

**For whom:** Solo developers (Hiro Sawaki persona) who use AI assistants as a pair-programmer but have no teammates to catch mistakes.

**Solution:** atdd-kit enforces an Issue-driven, AC-first, test-first workflow via Claude Code skill chains. The guardrails are structural — not advisory — so they hold even when the developer wants to skip them.

> "I don't need a bigger AI — I need an AI that won't let me skip the steps I'd skip on a tired Tuesday night." — Hiro Sawaki

See [hiro-solo-dev.md](../personas/hiro-solo-dev.md) for the full primary persona profile.

## Product Goal Statement

**atdd-kit enables a solo developer to ship reliable, resumable increments on personal projects by enforcing AC-driven workflow through Claude Code skill chains — without any runtime dependencies or team infrastructure.**

This is the Scrum Guide Product Goal: the commitment that the Product Backlog works toward.

参考: Scrum Guide 2020 — "The Product Goal describes a future state of the product which can serve as a target for the Scrum Team to plan against." https://scrumguides.org/scrum-guide.html

## Success Indicators

Success is qualitative for now (Phase A). Quantitative metrics will be defined in Phase C (Backlog Refinement evolution).

| Indicator | Description |
|-----------|-------------|
| AC gate enforced | No PR merges without AC-verified implementation |
| Resumability | A session started after a week gap picks up cleanly via session-start |
| Skill chain stability | skill regressions are caught by L4 tests before merge |
| Zero skip | Hiro does not bypass discover/plan/atdd even on small changes |
| Documentation alive | docs/ stays in sync with skill behavior; stale docs are flagged in plan |

## Current Achievement

| Area | Status |
|------|--------|
| Skill chain (discover → plan → atdd → verify → ship) | Operational |
| AC Review Round (autopilot) | Operational (regression tracked in #162) |
| L4 integration tests (atdd, discover, plan) | Operational; 5 more skills pending (#141–#147) |
| CI eval auto-block | Planned (#73) |
| Kanban Board (GitHub Projects v2) | Planned (#168) |
| Scrumban methodology docs | This PR (#166) |

## References

- [impact-map.md](./impact-map.md) — Actors, Impacts, and Deliverable links
- [story-map.md](./story-map.md) — Backbone and Walking Skeleton
- [roadmap.md](./roadmap.md) — Now / Next / Later prioritization
- [hiro-solo-dev.md](../personas/hiro-solo-dev.md) — Primary persona
