# Story Map

> **Loaded by:** defining-requirements skill, writing-plan-and-tests skill

Story Mapping (Jeff Patton) organizes the big story of how Hiro uses atdd-kit. The horizontal axis is the user activity flow (Backbone); the vertical axis is priority depth.

参考: Jeff Patton, *User Story Mapping* (2014) — https://www.jpattonassociates.com/wp-content/uploads/2015/03/story_mapping.pdf

## Backbone — The Big Story

Hiro goes from "I have an idea" to "increment is merged and documented" in a reproducible way, even alone.

```
idea → Issue → defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying
```

The backbone maps to atdd-kit's 6-step skill chain:

| Activity | Skill | Description |
|----------|-------|-------------|
| Capture idea | bug / writing-design-doc | Translate idea into a structured Issue with US + ACs |
| Explore requirements | defining-requirements | Dialogue-based AC derivation; INVEST check; persona link |
| Extract user stories | extracting-user-stories | Derive User Stories from the requirements |
| Plan implementation | writing-plan-and-tests | Test strategy + implementation strategy per AC |
| Implement ATDD | running-atdd-cycle | Double-loop TDD: Story Test → Unit TDD → GREEN |
| Review deliverables | reviewing-deliverables | AC Review + evidence-based check against all ACs via reviewer subagents |
| Merge & deploy increment | merging-and-deploying | PR review → merge → changelog → post-deploy regression |

## Walking Skeleton

The minimum end-to-end path that works today:

| Activity | Status |
|----------|--------|
| Issue creation (bug skill / flow) | Operational |
| Requirements exploration (defining-requirements) | Operational |
| User story extraction (extracting-user-stories) | Operational |
| Plan generation (writing-plan-and-tests) | Operational |
| ATDD implementation (running-atdd-cycle) | Operational |
| Review + verification (reviewing-deliverables) | Operational |
| Merge & deploy (merging-and-deploying) | Operational |

The skeleton is functional. Current work focuses on **reliability** (reducing regressions) and **automation** (reducing manual state management).

## Story Map Table

The table shows activities (columns) and priority slices (rows). Each cell is a user story or skill feature.

| Slice | Issue capture | defining-requirements | writing-plan-and-tests | reviewing-deliverables (AC gate) | running-atdd-cycle | reviewing-deliverables (evidence) | merging-and-deploying |
|-------|---------------|----------|------|-----------|------|--------|------|
| **Walking Skeleton** | Issue + US + ACs created | AC derivation dialogue | Test strategy per AC | Reviewer PASS/FAIL | Double-loop TDD per AC | Evidence per AC | PR merged + changelog |
| **Next slice** | Impact link required (#169) | Example Mapping (#169) | doc-follow step (#14) | US traceability check (#158) | Fresh sub-agent per AC (#71) | outer-loop coverage (#137) | — |
| **Later slice** | Projects v2 sync (#170) | INVEST gate (#171) | — | WIP Limit gate (#171) | — | — | — |

## Next Slice — Priority Features

The next vertical slice adds quality and automation across the backbone:

| Feature | Issue | Backbone column |
|---------|-------|----------------|
| Backlog Refinement evolution | [#169](https://github.com/o3-ozono/atdd-kit/issues/169) | defining-requirements |
| Plan doc-follow step mandatory | [#14](https://github.com/o3-ozono/atdd-kit/issues/14) | writing-plan-and-tests |
| AC Review Round US traceability | [#158](https://github.com/o3-ozono/atdd-kit/issues/158) | reviewing-deliverables |
| Fresh sub-agent per AC | [#71](https://github.com/o3-ozono/atdd-kit/issues/71) | running-atdd-cycle |
| running-atdd-cycle outer-loop coverage | [#137](https://github.com/o3-ozono/atdd-kit/issues/137) | running-atdd-cycle |

## References

- [product-goal.md](./product-goal.md) — Why and for whom
- [impact-map.md](./impact-map.md) — Impacts and Deliverables
- [roadmap.md](./roadmap.md) — Now / Next / Later timeline
- [atdd-guide.md](../methodology/atdd-guide.md) — Double-loop TDD rules
