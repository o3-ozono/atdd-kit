# Story Splitting Guide

> **Loaded by:** discover skill

When an Issue has Size=L or contains 7+ ACs, consider splitting before starting discover. This guide provides proven patterns for splitting without losing value.

## When to Split

| Signal | Action |
|--------|--------|
| Size = L label | Split before discover starts (DoR R6) |
| 7+ ACs derived | Split or document why splitting is inappropriate |
| Multiple independent user goals in one Issue | Split into separate Issues |
| Bug fix + refactor in same Issue | Split unless tightly coupled |

When splitting is inappropriate (e.g., the work is atomically coupled), document the reason in the Issue body.

## SPIDR — 5 Splitting Patterns (Mike Cohn)

SPIDR covers the most common split opportunities. Apply the first pattern that fits.

参考: Mike Cohn, SPIDR — https://blogs.itemis.com/en/spidr-five-simple-techniques-for-a-perfectly-split-user-story

| Pattern | When to Use | Example |
|---------|-------------|---------|
| **S — Spike** | Unknown implementation path; research needed first | "Research: how should discover split into flows?" → Split: Spike Issue + Implementation Issue |
| **P — Path** | Multiple alternative paths through the same story | "User can sign in with password OR OAuth" → Split by auth method |
| **I — Interface** | Multiple UI surfaces or API endpoints | "Display AC progress in CLI and in GitHub comment" → Split by output surface |
| **D — Data** | Different data types or sources | "Import from CSV and from JSON" → Split by format |
| **R — Rules** | Complex business rules; each rule = a story | "Discover applies INVEST check with all 6 criteria" → Split by criterion if independently releasable |

### Applying SPIDR to atdd-kit Issues

| Original Issue | Pattern | Split Suggestion |
|----------------|---------|-----------------|
| "discover skill split into 5 flows" (#148) | I (Interface / structure) | Each flow as a separate sub-Issue |
| "L4 integration tests for 8 skills" (#141–#147) | D (Data — each skill is a dataset) | Already split — 1 Issue per skill |
| "Backlog Refinement evolution" (#169) | R (Rules — Example Mapping, INVEST, Story Splitting, Impact link) | Split into sub-Issues per rule addition |

## Lawrence 9-Pattern Guide (Humanizing Work)

For more nuanced situations, the Lawrence 9-pattern guide provides additional split dimensions.

参考: Richard Lawrence & Peter Green, *The Humanizing Work Guide to Splitting User Stories* — https://www.humanizingwork.com/the-humanizing-work-guide-to-splitting-user-stories/

| # | Pattern | Description |
|---|---------|-------------|
| 1 | Workflow Steps | Split each step of a multi-step process |
| 2 | Business Rule Variations | One story per rule variant |
| 3 | Major Effort | Spike first, then implementation |
| 4 | Simple / Complex | Simple case first; complex as follow-up |
| 5 | Variations in Data | One story per data type/source |
| 6 | Data Entry Methods | One story per input method |
| 7 | Defer System QA | Core feature first; QA/NFR as separate story |
| 8 | Operations (CRUD) | Create / Read / Update / Delete as separate stories |
| 9 | Breaking Out a Spike | Extract unknowns into a research story |

## Split Decision Flow

```
Is this a Size=L Issue or does discover produce 7+ ACs?
  YES → Can the story be split along SPIDR patterns?
          YES → Split: create child Issues, link to parent
          NO  → Document why splitting is inappropriate in Issue body
                → proceed with one large Issue (R6 justification)
  NO  → No split needed; proceed with discover
```

## Relationship to Bug Fix Process

When a bug requires both a fix and a refactor, the split decision follows [bug-fix-process.md](./bug-fix-process.md):

- **1–2 parallel occurrences** → fix in same PR (no split)
- **3+ parallel occurrences** → create a separate refactoring Issue

This is consistent with SPIDR-S (Spike for investigation) and the "simple/complex" Lawrence split.

## Creating Split Issues

1. Create child Issues with the same Impact link as the parent.
2. Reference the parent Issue in each child's body.
3. Add `Size=S` or `Size=M` to confirm the split reduced scope.
4. Close the original large Issue only when all children are merged.

## References

- [definition-of-ready.md](./definition-of-ready.md) — R6 criterion for DoR
- [atdd-guide.md](./atdd-guide.md) — AC count rules (7+ ACs = split signal)
- [bug-fix-process.md](./bug-fix-process.md) — Parallel pattern search and split rules
- [impact-map.md](../product/impact-map.md) — Impact link required for child Issues
