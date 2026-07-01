> **Loaded by:** `running-atdd-cycle` skill (Step 4 research artifact — Issue #314). Referenced from `docs/issues/314-skill-loader-stub-split/`.

# SKILL.md Loader Stub Split — Methodology and Rollout Plan

This document establishes the methodology for splitting large SKILL.md files into a **loader stub** plus one or more **detail docs** under `docs/methodology/`. It records the current inventory, urgency classification, and the priority order for applying the split across all skills.

> **Scope:** Research and planning only (Issue #314). No SKILL.md file is modified by this document. Actual splits are carried out by separate derivative Issues listed in [## Rollout Plan](#rollout-plan).

---

## Split Pattern

### When to split

Per `DEVELOPMENT.md` § SKILL.md Line-Budget Raises:

> Raising a SKILL.md line-budget pin is allowed at most **twice cumulatively per file**. When a third raise becomes necessary, do not raise again — split the SKILL.md into a loader stub plus a detailed doc under `docs/methodology/` (#283).

Split is triggered when the **third raise** of a `test_<skill>_skill.bats` line-budget pin becomes necessary.

### What stays in the loader stub (SKILL.md)

The stub is the entry point that Claude loads when the skill triggers. Keep it thin:

- **Trigger** — the auto-detection description and explicit invocation syntax
- **Input** — what the skill consumes (Issue number, arguments, upstream artifacts)
- **Output** — deliverables and their paths
- **Frontmatter / meta** — `# Skill Name`, brief one-paragraph purpose
- **Reference pointers** — links to detail docs under `docs/methodology/<skill>-*.md` (one pointer per section moved out)
- **Hard gates and status-block contracts** — must-not-miss invariants that must fire even when detail docs are not loaded

### What moves to detail docs (docs/methodology/<skill>-*.md)

Everything else — the prose that grows over time:

- Step-by-step procedure detail (flow scripts, numbered substeps)
- Guard logic body (verbatim rules with many conditions)
- Large tables (role maps, option matrices, boundary tables)
- Presentation contracts (AskUserQuestion options, body formats)
- Iron laws, design gates, and anything that accumulates amendments

### Pointer format in the stub

Each moved section is replaced with a single reference line:

```
See [`docs/methodology/<skill>-detail.md`](../../docs/methodology/<skill>-detail.md).
```

Example from autopilot (reference implementation — #283 / #304):

| Moved content | Stub pointer | Detail doc |
|---------------|--------------|------------|
| Iron Law clauses | `See autopilot-iron-law.md` | `docs/methodology/autopilot-iron-law.md` |
| Design-approval gate | `See autopilot-design-gate.md` | `docs/methodology/autopilot-design-gate.md` |
| Route eligibility | `See route-eligibility.md` | `docs/methodology/route-eligibility.md` |
| Responsibility Boundary | `See autopilot-overview.md` | `docs/methodology/autopilot-overview.md` |

Each detail doc must begin with a `> **Loaded by:**` meta-comment (see CS-1 structural pin) and must be English-only (see CS-3 language policy).

---

## Reference Implementation — autopilot (#283 / #304)

The autopilot skill is the canonical prior art for this pattern. Its SKILL.md was at the 280-line budget limit (raised twice from the original 200-line baseline). Rather than a third raise, four detail docs were split out in Issues #283 and #304:

| SKILL.md pointer stub | Detail doc | Content moved |
|-----------------------|-----------|---------------|
| `autopilot-iron-law.md` reference | `docs/methodology/autopilot-iron-law.md` | The autopilot Iron Law (AL-1…AL-6) |
| `autopilot-design-gate.md` reference | `docs/methodology/autopilot-design-gate.md` | Design-approval gate presentation contract |
| `route-eligibility.md` reference | `docs/methodology/route-eligibility.md` | Express vs autopilot route signals |
| `autopilot-overview.md` reference | `docs/methodology/autopilot-overview.md` | Role map and Responsibility Boundary |

This reduced the stub from 279 lines (at the 280 pin) back to a maintainable size while keeping all behavioral detail auditable in dedicated docs.

---

## Skill Inventory

### Urgency thresholds

Urgency rank is derived from **headroom** (pin limit minus current line count) and **pin status**:

| Rank | Condition |
|------|-----------|
| **CRITICAL** | Has a budget pin AND headroom ≤ 5 lines (one PR away from split trigger) |
| **HIGH** | Has a budget pin AND headroom ≤ 30 lines (approaching next raise) |
| **MEDIUM** | Has a budget pin AND headroom > 30 lines, OR no pin but current count ≥ 200 lines |
| **LOW** | No pin and current count < 200 lines |

The thresholds use 30 lines as the HIGH boundary because a typical feature PR adds 10–20 lines; 30 lines gives roughly 1-2 PRs of runway before the next pin raise would be needed.

### Inventory table

Current line counts were measured with `wc -l` on 2026-06-24 (#356 / #350: autopilot 280→255 per #355/#359, merging-and-deploying 79→82 per #356).

| Skill | Current lines | Pin limit | Headroom | Rank | Notes |
|-------|--------------|-----------|----------|------|-------|
| autopilot | 255 | 280 | 25 | **HIGH** | Split in progress (#283/#304); LLM-review removed from convergence loop (#355/#359) reduced 280→255 |
| reviewing-deliverables | 228 | 240 | 12 | **HIGH** | Pin raised twice (first raise #302, second for embedded script) |
| session-start | 235 | none | — | **MEDIUM** | No budget pin — unguarded; 235 lines is high-risk without a ceiling (231→235 per #343) |
| skill-fix | 157 | none | — | **LOW** | No pin; moderate size |
| express | 128 | 200 | 72 | **LOW** | Pin at 200; comfortable headroom |
| batch-discovery | 124 | none | — | **LOW** | No pin; complements full-autopilot (queue priming, #341) |
| fixing-flaky-tests | 121 | none | — | **LOW** | No pin; moderate size |
| full-autopilot | 97 | none | — | **LOW** | No pin; manageable |
| running-atdd-cycle | 95 | 200 | 105 | **LOW** | Pin at 200; ample headroom |
| skill-gate | 88 | none | — | **LOW** | No pin; small |
| debugging | 105 | none | — | **LOW** | No pin; moderate |
| ui-test-debugging | 113 | none | — | **LOW** | No pin; moderate |
| defining-requirements | 68 | 200 | 132 | **LOW** | Pin at 200; ample headroom |
| extracting-user-stories | 63 | 200 | 137 | **LOW** | Pin at 200; ample headroom |
| writing-plan-and-tests | 62 | 200 | 138 | **LOW** | Pin at 200; ample headroom |
| fixing-bugs | 87 | none | — | **LOW** | No pin; small |
| bug | 92 | none | — | **LOW** | No pin; small |
| merging-and-deploying | 82 | 200 | 118 | **LOW** | Pin at 200; ample headroom (impact-selected e2e wiring #356) |
| writing-design-doc | 71 | 200 | 129 | **LOW** | Pin at 200; ample headroom |
| launching-preview | 60 | 200 | 140 | **LOW** | Pin at 200; ample headroom |
| sim-pool | 65 | none | — | **LOW** | No pin; small |
| designing-ui | 79 | none | — | **LOW** | No pin; small (#368) |

**Total: 22 SKILL.md files.**

### session-start finding (FS-2)

`session-start` has **no budget pin** (`tests/test_session_start_*.bats` contains no `wc -l` line-budget assertion). At 235 lines it is the second largest SKILL.md and growing. Without a pin, additions can silently push it past the split-threshold without triggering a test failure. This is a latent risk.

Recommended remediation (tracked in Rollout Plan below): add a budget pin at 240 lines in a near-term Issue so the file is guarded before the next feature PR.

---

## Impact Analysis

### 1. String-pin AT impact

When a section of SKILL.md that BATS tests verify via `grep -q` moves to a detail doc, the existing string-pin assertion in `test_<skill>_skill.bats` will break (RED) unless updated.

**Impact:** Any `@test` that `grep`s for a string now in a detail doc will fail after the move.

**Mitigation:** Before moving a section, inventory all BATS tests that pin strings from that section:

1. Identify every `grep -q` / `grep -qE` assertion in `tests/test_<skill>_skill.bats` and related `tests/acceptance/AT-*.bats` that references strings in the moved section.
2. Audit both the source pin (in the stub test file) and any destination that should re-pin the string in a new detail-doc test.
3. Update `@covers` annotations to point to the detail doc file path, not the SKILL.md path — this is the `@covers` widening rule generalised from MEMORY #304 lesson.

The **both-pin inventory** rule: after a split, every verifiable string must be pinned in *at least one* test targeting the file where it now lives. Stale pins referencing the stub for content that moved to a detail doc must be removed or redirected.

### 2. Template sync impact

atdd-kit uses bilingual templates (`templates/*.md`) and a template-sync check. SKILL.md files are not templates and are not synchronised via the bilingual template pipeline.

**Impact:** None. The split does not touch template files.

**Mitigation:** No action needed for template sync. Confirm at the time of each derivative Issue that no new template cross-reference to the stub is introduced.

### 3. Line-count pin test impact

When a SKILL.md shrinks after a split, the existing line-count pin in `test_<skill>_skill.bats` must be updated to reflect the new (lower) stub line count.

**Impact:** If the pin is not updated, the test remains vacuously green at the old (too high) limit and no longer enforces the stub budget.

**Mitigation:** In the same PR that performs the split:

1. Measure the new stub line count after moving content.
2. Set a new, tighter pin (stub target size, e.g. 120 lines) in `test_<skill>_skill.bats`.
3. Run the pin test to confirm it is GREEN at the new limit.

---

## Pin Operation

### DEVELOPMENT.md rule (quoted)

From `DEVELOPMENT.md` § SKILL.md Line-Budget Raises:

> Raising a SKILL.md line-budget pin (in `tests/test_<skill>_skill.bats`) is allowed at most **twice cumulatively per file**. When a third raise becomes necessary, do not raise again — split the SKILL.md into a loader stub plus a detailed doc under `docs/methodology/` (#283).

This is the trigger rule. The split methodology in this document is the operationalisation of that rule.

### Stub budget pin (post-split)

After splitting, set a **new, lower** line-budget pin in `test_<skill>_skill.bats` that reflects the stub's expected size:

- Measure the post-split stub line count.
- Add headroom of approximately 20 lines for future stub additions.
- Record the pin value in `test_<skill>_skill.bats` as a `@test "line budget: SKILL.md is at most N lines"` assertion.
- This resets the raise counter to zero for the stub — the stub now has two more allowed raises before the next split is needed.

### Detail doc structural pins (CS-1)

Each detail doc under `docs/methodology/` must have the following structural pins enforced by a BATS test (follow the pattern in `tests/test_phase_test_policy.bats` AT-312):

1. **Loaded-by meta-comment** — `head -3 <doc>` contains `> **Loaded by:**`
2. **README registration** — `docs/methodology/README.md` Documents table has an entry for the doc
3. **English-only** — `grep -P '[ぁ-んァ-ヶ一-龥]' <doc>` returns no matches

These three pins together form the CS-1 structural pin set and should be added to the acceptance test for the Issue that performs the split.

---

## Rollout Plan

Priority order is **urgency rank descending**, then by line count within the same rank. Each skill becomes a separate derivative Issue.

Dependencies: the FS-2 threshold definitions above must be finalised (done in this document) before derivative Issues are filed.

| Priority | Skill | Rank | Current lines | Pin limit | Recommended action | Prerequisite |
|----------|-------|------|--------------|-----------|-------------------|--------------|
| 1 | autopilot | CRITICAL | 279 | 280 | Split is already applied (#283/#304). Monitor for stub creep; if stub exceeds ~140 lines, split again. | #283 / #304 complete |
| 2 | reviewing-deliverables | HIGH | 228 | 240 | Split before the next feature PR adds to this file. Target stub ≤ 150 lines. | FS-2 thresholds (this doc) |
| 3 | session-start | MEDIUM | 235 | none | Add budget pin at 240 lines first (near-term Issue), then plan split if pin is hit. | Pin Issue must land first |
| 4 | skill-fix | LOW | 157 | none | Add a budget pin at 200 lines to guard against silent growth. | None |
| 5–20 | All others | LOW | ≤ 128 | 200 or none | No action needed now. Re-evaluate when any file approaches its pin or 180 lines without a pin. | FS-2 threshold monitoring |

**FS-2 dependency note:** The urgency thresholds defined in [## Skill Inventory](#skill-inventory) (CRITICAL ≤ 5 lines headroom, HIGH ≤ 30 lines) govern the priority order above. If line counts change between this writing and the derivative Issue, re-classify using the same threshold formula.
