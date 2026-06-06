# Roadmap

> **Loaded by:** session-start skill

The roadmap uses **Now / Next / Later** lanes (no fixed dates). Focus areas are updated at a quarterly cadence. Issues within each lane are not ordered — priority is managed via the Kanban Board (Phase B: #168).

## Now — Active Focus

Issues currently in progress or the highest priority for the next iteration.

| Area | Issue | Description |
|------|-------|-------------|
| Requirements quality | [#71](https://github.com/o3-ozono/atdd-kit/issues/71) | Fresh sub-agent per AC — structural fix for running-atdd-cycle isolation |
| Skill refactor | [#148](https://github.com/o3-ozono/atdd-kit/issues/148) | defining-requirements skill split into 5 flows — reduces complexity |
| Bug: AC Review regression | [#162](https://github.com/o3-ozono/atdd-kit/issues/162) | defining-requirements COMPLETE → AC Review Round regression |
| Methodology docs | [#166](https://github.com/o3-ozono/atdd-kit/issues/166) | Phase A — Scrumban foundation docs (this PR) |

## Next — Up Next

Ready or nearly ready for implementation once Now lane items complete.

| Area | Issue | Description |
|------|-------|-------------|
| Kanban Board | [#168](https://github.com/o3-ozono/atdd-kit/issues/168) | Phase B — GitHub Projects v2 Kanban implementation |
| Backlog Refinement | [#169](https://github.com/o3-ozono/atdd-kit/issues/169) | Phase C — defining-requirements evolution with Example Mapping + INVEST |
| CI test block | [#73](https://github.com/o3-ozono/atdd-kit/issues/73) | Auto-block on BATS test failure |
| Doc follow step | [#14](https://github.com/o3-ozono/atdd-kit/issues/14) | writing-plan-and-tests skill mandatory doc-follow step |
| US traceability in AC Review | [#158](https://github.com/o3-ozono/atdd-kit/issues/158) | reviewing-deliverables AC Review Round US traceability mention |
| Skill chain test coverage | [#137](https://github.com/o3-ozono/atdd-kit/issues/137) | BATS test coverage for the running-atdd-cycle outer loop |
| Skill chain tests (remaining skills) | [#141](https://github.com/o3-ozono/atdd-kit/issues/141)–[#147](https://github.com/o3-ozono/atdd-kit/issues/147) | BATS integration tests for reviewing-deliverables, merging-and-deploying, bug, debugging, writing-design-doc, and remaining skills |

## Later — Backlog

Valuable but not yet the top priority. Revisit each quarter.

| Area | Issue | Description |
|------|-------|-------------|
| WIP Limit + DoR Gate | [#171](https://github.com/o3-ozono/atdd-kit/issues/171) | Phase E — structural blocking of defining-requirements/writing-plan-and-tests by WIP limit |
| Automation | [#170](https://github.com/o3-ozono/atdd-kit/issues/170) | Phase D — workflow label → Projects Status auto-sync |
| Retrospective | [#172](https://github.com/o3-ozono/atdd-kit/issues/172) | Phase F — weekly review → methodology improvement |
| Iteration | [#173](https://github.com/o3-ozono/atdd-kit/issues/173) | Phase G — lightweight milestone operation |
| Refactor: state file-based | [#149](https://github.com/o3-ozono/atdd-kit/issues/149) | Issue state to file-based, spec slug deterministic |
| Refactor: Rationalization table | [#161](https://github.com/o3-ozono/atdd-kit/issues/161) | Rename across 6 remaining skills |
| US/AC spec coverage | [#117](https://github.com/o3-ozono/atdd-kit/issues/117) | Tracking remaining 8 skills |
| BATS dogfood fixture | [#159](https://github.com/o3-ozono/atdd-kit/issues/159) | AC exclusion list follow-up |
| Epic: ATDD core | [#63](https://github.com/o3-ozono/atdd-kit/issues/63) | Persona / US / AC system and docs reorganization |
| Epic: Scrumban | [#165](https://github.com/o3-ozono/atdd-kit/issues/165) | Phase roadmap parent epic |
| Investigation | [#163](https://github.com/o3-ozono/atdd-kit/issues/163) | Parallel dev visualization + requirements quality |

## Update Cadence

- Review and update lane assignments **quarterly**.
- Issues promoted from Later → Next when they have an approved US/AC spec.
- Issues promoted from Next → Now when they meet DoR (see [definition-of-ready.md](../methodology/definition-of-ready.md)).

## References

- [impact-map.md](./impact-map.md) — Which Impact each issue contributes to
- [story-map.md](./story-map.md) — Activity backbone context
- [product-goal.md](./product-goal.md) — Success indicators that guide prioritization
