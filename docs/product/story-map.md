# Story Map

> **Loaded by:** discover skill, plan skill

Story Mapping (Jeff Patton) organizes the big story of how Hiro uses atdd-kit. The horizontal axis is the user activity flow (Backbone); the vertical axis is priority depth.

参考: Jeff Patton, *User Story Mapping* (2014) — https://www.jpattonassociates.com/wp-content/uploads/2015/03/story_mapping.pdf

## Backbone — The Big Story

Hiro goes from "I have an idea" to "increment is merged and documented" in a reproducible way, even alone.

```
idea → Issue → discover → plan → [AC Review] → atdd → verify → ship
```

The backbone maps to atdd-kit's skill chain:

| Activity | Skill | Description |
|----------|-------|-------------|
| Capture idea | issue / bug / ideate | Translate idea into a structured Issue with US + ACs |
| Explore requirements | discover | Dialogue-based AC derivation; INVEST check; persona link |
| Plan implementation | plan | Test strategy + implementation strategy per AC |
| AC Review gate | autopilot (Reviewer) | AC Review Round before implementation starts |
| Implement ATDD | atdd | Double-loop TDD: Story Test → Unit TDD → GREEN |
| Verify evidence | verify | Evidence-based check against all ACs |
| Ship increment | ship | PR review → merge → changelog update |

## Walking Skeleton

The minimum end-to-end path that works today:

| Activity | Status |
|----------|--------|
| Issue creation (issue/bug skill) | Operational |
| Requirements exploration (discover) | Operational |
| Plan generation (plan) | Operational |
| AC Review Round (autopilot) | Operational |
| ATDD implementation (atdd) | Operational |
| Verification (verify) | Operational |
| Ship (ship) | Operational |

The skeleton is functional. Current work focuses on **reliability** (reducing regressions) and **automation** (reducing manual state management).

## Story Map Table

The table shows activities (columns) and priority slices (rows). Each cell is a user story or skill feature.

| Slice | Issue capture | discover | plan | AC Review | atdd | verify | ship |
|-------|---------------|----------|------|-----------|------|--------|------|
| **Walking Skeleton** | Issue + US + ACs created | AC derivation dialogue | Test strategy per AC | Reviewer PASS/FAIL | Double-loop TDD per AC | Evidence per AC | PR merged + changelog |
| **Next slice** | Impact link required (#169) | Example Mapping (#169) | doc-follow step (#14) | US traceability check (#158) | Fresh sub-agent per AC (#71) | L4 outer-loop (#137) | — |
| **Later slice** | Projects v2 sync (#170) | INVEST gate (#171) | — | WIP Limit gate (#171) | — | — | — |

## Next Slice — Priority Features

The next vertical slice adds quality and automation across the backbone:

| Feature | Issue | Backbone column |
|---------|-------|----------------|
| Backlog Refinement evolution | [#169](https://github.com/o3-ozono/atdd-kit/issues/169) | discover |
| Plan doc-follow step mandatory | [#14](https://github.com/o3-ozono/atdd-kit/issues/14) | plan |
| AC Review Round US traceability | [#158](https://github.com/o3-ozono/atdd-kit/issues/158) | AC Review |
| Fresh sub-agent per AC | [#71](https://github.com/o3-ozono/atdd-kit/issues/71) | atdd |
| L4 as atdd outer-loop | [#137](https://github.com/o3-ozono/atdd-kit/issues/137) | verify |

## References

- [product-goal.md](./product-goal.md) — Why and for whom
- [impact-map.md](./impact-map.md) — Impacts and Deliverables
- [roadmap.md](./roadmap.md) — Now / Next / Later timeline
- [atdd-guide.md](../methodology/atdd-guide.md) — Double-loop TDD rules
