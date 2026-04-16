---
name: plan
description: "Create test strategy and implementation strategy from discover's deliverables (DoD + ACs). Second step of the Issue Ready flow."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# plan Skill -- Test Strategy & Implementation Strategy

<HARD-GATE>
Do NOT invoke atdd or write any code until the plan has been REVIEWED and APPROVED. This skill produces strategy only -- no code, no tests, no file edits. Never suggest skipping plan review or PR review -- every plan must go through the QA process.
</HARD-GATE>

<AUTOPILOT-GUARD>
If ARGUMENTS does not contain `--autopilot` (user invoked directly via slash command):
- Display message: "This skill is autopilot-only. Use `/atdd-kit:autopilot <number>` instead."
- **STOP.** Do not proceed with execution.
If ARGUMENTS contains `--autopilot` (invoked by autopilot): skip this guard silently.
</AUTOPILOT-GUARD>

## State Gate (required -- skip only in Inline Mode)

1. **Check `in-progress` label:** `gh issue view <number> --json labels --jq '[.labels[].name] | index("in-progress")'`
   - If missing: STOP. Report: "Issue #N does not have `in-progress` label. Run `discover` first."
2. **Check discover deliverables comment:** `gh issue view <number> --json comments --jq '[.comments[].body | select(startswith("## discover Deliverables"))] | length'`
   - If 0: STOP. Report: "Issue #N has no discover deliverables. Run `discover` first."
3. Both pass: proceed.

> **Inline Mode exception:** When called inline from discover, skip this gate.

Takes approved DoD + ACs from discover and produces test strategy (AC-to-test-layer mapping) and implementation strategy. No code is written here — `atdd` writes the code.

---

## Core Principles

| # | Principle | Detail |
|---|-----------|--------|
| P1 | **Double-Loop awareness** | Outer loop = Story Test (E2E/Integration). Inner loop = Unit/Integration tests per AC. |
| P2 | **No code** | Strategy and mapping only. |
| P3 | **YAGNI** | Only plan what ACs require. |
| P4 | **Exact paths** | "somewhere in src/" is banned. Use exact file paths. |
| P5 | **No file edits** | Issue comments only. |
| P6 | **Post deliverables as Issue comments** | Use `gh issue comment`. |

Default Recommendation Pattern: `Recommended: [X] — reply 'ok' to accept, or provide alternative`

---

## Inline Mode (called from discover)

- Skip Step 1 (deliverables already in context)
- Execute Steps 2-5
- Return output to discover for combined comment
- Skip Steps 7-10

---

## Core Flow

Execute in order. Do not skip any.

### Step 1: Read discover Deliverables

Read Issue comments for:
- Development/bug/refactoring: DoD + User Story + ACs (Given/When/Then)
- Documentation/research: DoD

If not found, suggest `atdd-kit:discover`.

### Step 2: Codebase Analysis

1. Identify files/modules related to the ACs
2. Understand existing test patterns (framework, naming, directory structure)
3. Understand existing implementation patterns (architecture, dependencies, naming)
4. Check `docs/` for design constraints

### Step 3: Test Strategy -- Map ACs to Test Layers

Following the Double-Loop TDD model (`docs/methodology/atdd-guide.md`):

#### Outer Loop (Story Test)

| Candidate | When to choose |
|-----------|---------------|
| **E2E** | Full user flow with UI interaction |
| **Integration** | Cross-module flow without UI, or E2E impractical |

AskUserQuestion — header: "Story Test?", options: "(Recommended) [layer] — [reason]", "[alternative]"

Recommended: [recommended layer] — reply 'ok' to accept, or provide alternative

#### Inner Loop (AC Tests)

| Test Layer | Covers | Example |
|-----------|--------|---------|
| **Unit** | Logic, calculations, transformations | Validation, formatting |
| **Integration** | Cross-module interaction | ViewModel + Repository |
| **Snapshot** | Appearance, layout | View snapshots |
| **E2E** | Full user flows, complex interaction | Screen navigation |

Decision criteria:
- "is displayed" / "is visible" → Snapshot or E2E
- "is calculated" / "is converted" → Unit
- "is saved" / "is sent" → Integration
- "navigate to screen..." → E2E

Present mapping as a table:

```
### Test Strategy

#### Outer Loop (Story Test)
- **User Story:** [copy from discover]
- **Test layer:** E2E / Integration
- **Rationale:** [why]

#### Inner Loop (AC Tests)

| AC | Test Layer | Rationale |
|----|-----------|-----------|
| AC1: [name] | Unit / Integration / Snapshot / E2E | [why] |
```

### Step 4: Implementation Strategy

1. **Target files** -- All files to create or modify with one-line descriptions
2. **Architecture decisions** -- Design choices and rationale
3. **Dependencies** -- Ordering constraints between ACs
4. **Risks** -- Anticipated risks and mitigations
5. **Agent Composition** -- Variable-Count Agents count and focus for Phase 3/4.

   | Task Type | Variable-Count Agents | Criteria |
   |-----------|-----------------------|----------|
   | development / refactoring / bug | Reviewer x N | Components affected, security/performance risk |
   | research | Researcher x N (min 2 per theme) | One agent per theme |
   | documentation | Reviewer x N | Document scope and audience |

   Sizing: single file → Reviewer x 1; multiple components / security risk → Reviewer x 2+; separate themes → Researcher x (theme count).

   > Only Variable-Count Agents listed in `### Agent Composition`. Fixed-count agents from Agent Composition Table in `commands/autopilot.md`.

```
### Implementation Strategy

#### Target Files

| File | Role | Action |
|------|------|--------|
| path/to/file | description | Create / Modify |

#### Architecture Decisions
- [Decision]: [rationale]

#### AC Dependencies
- [ordering constraints, if any]

#### Risks
- [risk]: [mitigation]
```

### Step 5: Readiness Check

Verify before presenting. Fix if any fail.

| Check | Bad | Good |
|-------|-----|------|
| All ACs mapped | AC without mapping | Every AC has a layer |
| Layer choices justified | "Unit" no reason | "Unit -- pure calculation, no dependencies" |
| Target files identified | "improve CI" | "change ci.yml line 100" |
| Design decisions resolved | "choose A or B" | "A chosen (reason: ...)" |
| Outer loop test defined | No story test | Layer and rationale specified |
| Variable-Count Agent count and focus concrete | "Reviewer x N" | "Reviewer x 2: (1) security (2) performance" |

```
### Readiness Check

| Check | Result |
|-------|--------|
| All ACs mapped to test layers | OK |
| Test layer choices justified | OK |
| Target files identified | OK |
| Design decisions resolved | OK |
| Outer loop test defined | OK |
| Variable-Count Agent count and focus are concrete | OK / NG: [reason] |
```

### Step 6: Post to Issue Comment

Post with `gh issue comment`:

```markdown
## Implementation Plan

### Test Strategy

#### Outer Loop (Story Test)
- **User Story:** [from discover]
- **Test layer:** E2E / Integration
- **Rationale:** [reason]

#### Inner Loop (AC Tests)

| AC | Test Layer | Rationale |
|----|-----------|-----------|
| AC1: [name] | [layer] | [reason] |
| AC2: [name] | [layer] | [reason] |

### Discussion Summary

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| [design choice] | [why chosen] | [what else and why rejected] |

> Record key design decisions and trade-offs. Permanent record.

### Implementation Strategy

#### Target Files

| File | Role | Action |
|------|------|--------|
| path/to/file | description | Create / Modify |

#### Architecture Decisions
- [decision]: [rationale]

#### AC Dependencies
- [constraints]

#### Risks
- [risk]: [mitigation]

### Agent Composition

| Phase | Role | Count | Focus |
|-------|------|-------|-------|
| Phase 3 | [Reviewer / Researcher / Developer / Writer] | [N] | [perspective or theme] |
| Phase 4 | [Reviewer] | [N] | [perspective] |

> If no Variable-Count Agents for this phase/task type, write "N/A" in Focus.

### Readiness Check

| Check | Result |
|-------|--------|
| All ACs mapped to test layers | OK / NG: [reason] |
| Test layer choices justified | OK / NG: [reason] |
| Target files identified | OK / NG: [reason] |
| Design decisions resolved | OK / NG: [reason] |
| Outer loop test defined | OK / NG: [reason] |
| Variable-Count Agent count and focus are concrete | OK / NG: [reason] |
```

### Step 7: Risk-based Approval Classification

Classify each plan item by risk:

| Indicator | Classification | Criteria | User Action |
|-----------|---------------|----------|-------------|
| 🔴 | Decision required | Design policy change, new architectural pattern, safety tradeoff | Must approve |
| 🟡 | Confirmation | Direction decided but details may need adjustment | Quick scan |
| 🟢 | Auto-approve | Previously approved, technical details, mechanical changes | No action needed |

```markdown
## Approval Request

### 🔴 Decision Required
| Item | Detail | Decision Point |
|------|--------|---------------|
| [AC/decision] | [what] | [what needs deciding] |

### 🟡 Confirmation
| Item | Detail |
|------|--------|
| [AC/decision] | [what] |

### 🟢 Auto-approved
| Item | Reason |
|------|--------|
| [AC/decision] | [why pre-approved] |
```

### Step 8: Request Approval and Label

```
gh issue edit <number> --add-label "ready-for-plan-review"
```

```
Implementation plan posted and `ready-for-plan-review` label added.

1. `/atdd-kit:autopilot` — Launch Agent Teams now (review + implement + merge)
2. Leave label and move to next task
```

STOP here. Do not proceed further.

---

## Status Output

**Autopilot mode only** (ARGUMENTS contains `--autopilot`). Skip in standalone mode.
**Inline Mode exception:** When called inline from discover, do NOT output `skill-status`. Discover owns status.

Output a `skill-status` fenced code block as the **last element** of your response at every terminal point.

Terminal points:
- **COMPLETE:** Plan posted and `ready-for-plan-review` label added.
- **PENDING:** Waiting for user input.
- **BLOCKED:** State Gate failed.
- **FAILED:** Unrecoverable error (e.g., `gh issue comment` auth failure).

```skill-status
SKILL_STATUS: COMPLETE | PENDING | BLOCKED | FAILED
PHASE: plan
RECOMMENDATION: <next action or error description in one sentence>
```

Examples:

```skill-status
SKILL_STATUS: COMPLETE
PHASE: plan
RECOMMENDATION: Plan posted. Proceed to ATDD implementation.
```

```skill-status
SKILL_STATUS: BLOCKED
PHASE: plan
RECOMMENDATION: Issue #N has no discover deliverables. Run discover first.
```

See `docs/guides/skill-status-spec.md` for full field definitions, BLOCKED vs FAILED distinction, and autopilot action matrix.

---

## Handling Large Plans

If 7 or more ACs are mapped, suggest splitting the Issue. AskUserQuestion — header: "Split?", options: "(Recommended) Split into smaller Issues", "Continue as-is (document reason)"

Recommended: Split — reply 'ok' to accept, or provide alternative

---

## Mandatory Checklist

- [ ] Not editing code or files (Issue comments only)
- [ ] Not writing test or implementation code
- [ ] All ACs have test layer mappings
- [ ] Test layer choices have rationale
- [ ] File paths are exact ("somewhere" / "appropriate location" is banned)
- [ ] Outer loop story test defined
- [ ] Readiness Check executed
- [ ] `ready-for-plan-review` label added after posting
- [ ] Deliverables posted as Issue comment
