# Impact Map

> **Loaded by:** discover skill, issue skill

## Goal

**atdd-kit solves the problem of AI-assisted solo developers skipping quality steps under time pressure.**
For **Hiro Sawaki** (solo developer, primary persona), the tool enforces an Issue-driven, AC-first workflow so that increments are reliable and context can be resumed after long gaps.

See [product-goal.md](./product-goal.md) for the full Product Goal statement.

## Actors

| Actor | File | Role |
|-------|------|------|
| Hiro Sawaki | [hiro-solo-dev.md](../personas/hiro-solo-dev.md) | Primary — solo developer who benefits from enforcement |
| Rin Akagi | [rin-freeform-coder.md](../personas/rin-freeform-coder.md) | Negative — explicitly out of scope |

## Impacts and Deliverables

Each Impact describes a **behavioral change** in an Actor, not a feature. Deliverables (Issues / skills / features) contribute to one or more Impacts.

---

### Impact 1: Requirements Definition Quality (discover / AC)

> Hiro notices AC gaps during discover, before implementation starts — not after CI fails.

| Deliverable | Issue |
|-------------|-------|
| Fix discover COMPLETE → AC Review Round regression | [#162](https://github.com/o3-ozono/atdd-kit/issues/162) |
| Backlog Refinement = discover skill evolution (Example Mapping + INVEST + Story Splitting) | [#169](https://github.com/o3-ozono/atdd-kit/issues/169) |
| autopilot SKILL.md AC Review Round with US traceability mention | [#158](https://github.com/o3-ozono/atdd-kit/issues/158) |
| refactor: discover skill split into 5 flows | [#148](https://github.com/o3-ozono/atdd-kit/issues/148) |
| tracking: US/AC spec coverage for remaining 8 skills | [#117](https://github.com/o3-ozono/atdd-kit/issues/117) |
| feat: AC per fresh sub-agent | [#71](https://github.com/o3-ozono/atdd-kit/issues/71) |
| epic: ATDD core — persona / User Story / AC system + docs reorganization | [#63](https://github.com/o3-ozono/atdd-kit/issues/63) |

---

### Impact 2: Flow Automation (autopilot / Projects)

> Hiro spends less time manually managing Issue state and more time on actual development.

| Deliverable | Issue |
|-------------|-------|
| Phase B — Kanban Board via GitHub Projects v2 | [#168](https://github.com/o3-ozono/atdd-kit/issues/168) |
| Phase D — Automation (autopilot label → Projects Status sync) | [#170](https://github.com/o3-ozono/atdd-kit/issues/170) |
| Phase E — WIP Limit + DoR Gate | [#171](https://github.com/o3-ozono/atdd-kit/issues/171) |
| Phase F — Retrospective mechanism | [#172](https://github.com/o3-ozono/atdd-kit/issues/172) |
| Phase G — Iteration (lightweight milestone operation) | [#173](https://github.com/o3-ozono/atdd-kit/issues/173) |

---

### Impact 3: Skill Quality Assurance (L4 / test)

> Hiro trusts that skills behave correctly after updates, without manual regression checking.

| Deliverable | Issue |
|-------------|-------|
| feat: L4 as atdd outer-loop integration into autopilot | [#137](https://github.com/o3-ozono/atdd-kit/issues/137) |
| test: L4 integration test for verify skill | [#141](https://github.com/o3-ozono/atdd-kit/issues/141) |
| test: L4 integration test for ship skill | [#142](https://github.com/o3-ozono/atdd-kit/issues/142) |
| test: L4 integration test for bug skill | [#143](https://github.com/o3-ozono/atdd-kit/issues/143) |
| test: L4 integration test for debugging skill | [#144](https://github.com/o3-ozono/atdd-kit/issues/144) |
| test: L4 integration test for ideate skill | [#145](https://github.com/o3-ozono/atdd-kit/issues/145) |
| test: L4 integration test for issue skill | [#146](https://github.com/o3-ozono/atdd-kit/issues/146) |
| test: L4 integration test for express skill | [#147](https://github.com/o3-ozono/atdd-kit/issues/147) |

---

### Impact 4: Quality Gate Enforcement (CI / eval)

> Hiro's PRs are blocked automatically when skill quality degrades — no manual eval needed.

| Deliverable | Issue |
|-------------|-------|
| feat: CI eval auto-block on pass_rate drop | [#73](https://github.com/o3-ozono/atdd-kit/issues/73) |

---

### Impact 5: Maintainability Improvement (refactor)

> Hiro can evolve atdd-kit itself without accumulating technical debt that slows future changes.

| Deliverable | Issue |
|-------------|-------|
| refactor: Rationalization table rename across 6 skills | [#161](https://github.com/o3-ozono/atdd-kit/issues/161) |
| refactor: Issue state to file-based, spec slug deterministic | [#149](https://github.com/o3-ozono/atdd-kit/issues/149) |

---

### Impact 6: Documentation Coverage

> Hiro always finds up-to-date methodology docs when skills reference them.

| Deliverable | Issue |
|-------------|-------|
| feat: plan skill mandatory doc-follow step | [#14](https://github.com/o3-ozono/atdd-kit/issues/14) |

---

### Impact 7: Epic / Investigation (Goal-level)

> These are parent investigations and epics that span multiple Impacts above.

| Deliverable | Issue |
|-------------|-------|
| epic: Scrumban + ATDD hybrid development flow | [#165](https://github.com/o3-ozono/atdd-kit/issues/165) |
| investigation: parallel development visualization + requirements quality | [#163](https://github.com/o3-ozono/atdd-kit/issues/163) |

---

### Impact 8: Dogfood / Maintenance

> Hiro's own use of atdd-kit surfaces real-world gaps that improve the tool.

| Deliverable | Issue |
|-------------|-------|
| BATS dogfood fixture for AC exclusion list (follow-up to #156) | [#159](https://github.com/o3-ozono/atdd-kit/issues/159) |

---

## Deliverable Coverage

Open Issues mapped to at least one Impact: **27 / 27** (100% ≥ required 80%)

| # | Impact |
|---|--------|
| #162 | Impact 1 |
| #169 | Impact 1 |
| #158 | Impact 1 |
| #148 | Impact 1 |
| #117 | Impact 1 |
| #71 | Impact 1 |
| #63 | Impact 1 |
| #168 | Impact 2 |
| #170 | Impact 2 |
| #171 | Impact 2 |
| #172 | Impact 2 |
| #173 | Impact 2 |
| #137 | Impact 3 |
| #141 | Impact 3 |
| #142 | Impact 3 |
| #143 | Impact 3 |
| #144 | Impact 3 |
| #145 | Impact 3 |
| #146 | Impact 3 |
| #147 | Impact 3 |
| #73 | Impact 4 |
| #161 | Impact 5 |
| #149 | Impact 5 |
| #14 | Impact 6 |
| #165 | Impact 7 |
| #163 | Impact 7 |
| #159 | Impact 8 |
| #166 | (this doc — Phase A) |

## Governance Rule

Every new Issue must declare which Impact it contributes to in the Issue body, using the label or a `Impact:` line. If no existing Impact applies, propose a new Impact in the Issue before creating it.

## References

- Gojko Adzic, *Impact Mapping* (2012) — https://www.impactmapping.org/book.html
- [product-goal.md](./product-goal.md) — Why atdd-kit exists
- [story-map.md](./story-map.md) — Backbone and Walking Skeleton
- [roadmap.md](./roadmap.md) — Now / Next / Later prioritization
