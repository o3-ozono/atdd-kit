---
name: plan
description: "Create test strategy and implementation strategy from discover's deliverables (DoD + ACs). Second step of the Issue Ready flow."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# plan Skill -- Test Strategy & Implementation Strategy

<HARD-GATE>
Do NOT invoke atdd or write any code until the plan has been REVIEWED and APPROVED (via the QA process or user approval). This skill produces strategy only -- no code, no tests, no file edits. Never suggest skipping plan review or PR review regardless of task complexity or autonomy level -- every plan must go through the QA process.
</HARD-GATE>

<AUTOPILOT-GUARD>
If ARGUMENTS does not contain `--autopilot` (user invoked directly via slash command):
- Display message: "This skill is autopilot-only. Use `/atdd-kit:autopilot <number>` instead."
- **STOP.** Do not proceed with execution.
If ARGUMENTS contains `--autopilot` (invoked by autopilot): skip this guard silently.
</AUTOPILOT-GUARD>

## State Gate (required -- skip only in Inline Mode)

Before executing plan, verify the Issue meets these preconditions:

1. **Check `in-progress` label:** `gh issue view <number> --json labels --jq '[.labels[].name] | index("in-progress")'`
   - If missing: STOP. Report: "Issue #N does not have `in-progress` label. Run `discover` first to start the workflow."
2. **Check discover deliverables comment:** `gh issue view <number> --json comments --jq '[.comments[].body | select(startswith("## discover Deliverables"))] | length'`
   - If 0: STOP. Report: "Issue #N has no discover deliverables. Run `discover` first."
3. Both checks pass: proceed to Core Flow.

> **Inline Mode exception:** When plan is called inline from discover, skip this gate (discover deliverables are being created in the same flow).

The second step of the Issue Ready flow. Takes approved DoD + ACs from discover and produces a test strategy (AC-to-test-layer mapping) and implementation strategy.

> **Code is NOT written here.** plan decides *how* to test and implement. `atdd` writes the actual code.

---

## Core Principles

Follow these **always**. No exceptions.

| # | Principle | Detail |
|---|-----------|--------|
| P1 | **Double-Loop awareness** | Outer loop = Story Test (E2E/Integration) for the User Story. Inner loop = Unit/Integration tests for each AC. |
| P2 | **No code** | Do not write test code or implementation code. Strategy and mapping only. |
| P3 | **YAGNI** | Only plan what the ACs require. Nothing more. |
| P4 | **Exact paths** | "somewhere in src/" is banned. Always use exact file paths. |
| P5 | **No file edits** | This skill edits no code and no files (Issue comments only). |
| P6 | **Post deliverables as Issue comments** | No repository file commits. Use `gh issue comment`. |

### Default Recommendation Pattern

At every decision point in plan, present a recommended default. The user can accept with "ok" or provide an alternative.

Format: `Recommended: [X] �� reply 'ok' to accept, or provide alternative`

This applies to: execution mode selection, test layer choices, and other decision points.

---

## Inline Mode (called from discover)

When plan is invoked inline by discover (AC9 gate integration):
- **Skip Step 1** (discover deliverables are already in context)
- Execute Steps 2-5 (Codebase Analysis, Test Strategy, Implementation Strategy, Readiness Check)
- Return the plan output to discover for combined comment posting
- Skip Steps 7-10 (approval label and execution mode are handled by discover)

---

## Core Flow

Execute these steps **in order**. Do not skip any.

### Step 1: Read discover Deliverables

1. Read Issue comments to find the approved deliverables from discover:
   - Development/bug/refactoring: DoD + User Story + ACs (Given/When/Then)
   - Documentation/research: DoD
2. If deliverables are not found, notify the user that discover is incomplete and suggest running `atdd-kit:discover`

### Step 2: Codebase Analysis

1. Identify files/modules related to the ACs
2. Understand existing test patterns (framework, naming, directory structure)
3. Understand existing implementation patterns (architecture, dependencies, naming)
4. Check `docs/` for design constraints

### Step 3: Test Strategy -- Map ACs to Test Layers

Following the Double-Loop TDD model (`docs/atdd-guide.md`):

#### Outer Loop (Story Test)

Decide the test layer for the User Story as a whole:

| Candidate | When to choose |
|-----------|---------------|
| **E2E** | Full user flow involving UI interaction |
| **Integration** | Cross-module flow without UI, or when E2E is impractical |

Then use AskUserQuestion with:
- header: "Story Test?"
- options:
  1. "(Recommended) [recommended layer] — [brief reason]"
  2. "[alternative layer]"
- multiSelect: false

Recommended: [recommended layer] — reply 'ok' to accept, or provide alternative

#### Inner Loop (AC Tests)

For each AC, decide which test layer covers it:

| Test Layer | Covers | Example |
|-----------|--------|---------|
| **Unit** | Logic, calculations, transformations | Validation, formatting |
| **Integration** | Cross-module interaction | ViewModel + Repository |
| **Snapshot** | Appearance, layout | View snapshots |
| **E2E** | Full user flows, complex interaction | Screen navigation, multi-step scenarios |

Decision criteria:
- AC says "is displayed" / "is visible" -> Snapshot or E2E
- AC says "is calculated" / "is converted" -> Unit
- AC says "is saved" / "is sent" -> Integration
- AC says "navigate to screen..." -> E2E

Present the mapping as a table:

```
### Test Strategy

#### Outer Loop (Story Test)
- **User Story:** [copy from discover]
- **Test layer:** E2E / Integration
- **Rationale:** [why this layer]

#### Inner Loop (AC Tests)

| AC | Test Layer | Rationale |
|----|-----------|-----------|
| AC1: [name] | Unit / Integration / Snapshot / E2E | [why this layer] |
| AC2: [name] | Unit / Integration / Snapshot / E2E | [why this layer] |
| ... | ... | ... |
```

### Step 4: Implementation Strategy

Describe *how* the implementation will be structured:

1. **Target files** -- List all files to create or modify, with one-line descriptions
2. **Architecture decisions** -- Design choices and rationale (e.g., "use existing Repository pattern", "add new ViewModel")
3. **Dependencies** -- Ordering constraints between ACs (e.g., "AC2 depends on AC1's data model")
4. **Risks** -- Anticipated risks and mitigations
5. **Agent Composition** -- Determine the Variable-Count Agents (Reviewer, Researcher) count and focus/themes for Phase 3 and Phase 4.

   Decide concretely based on task type and change scope:

   | Task Type | Variable-Count Agents | Decision Criteria |
   |-----------|-----------------------|-------------------|
   | development / refactoring / bug | Reviewer x N | Number of components affected, security/performance risk |
   | research | Researcher x N (min 2 per theme) | One agent per clearly separated theme |
   | documentation | Reviewer x N | Document scope and target audience perspectives |

   Sizing guide:
   - Single file / single feature change → Reviewer x 1
   - Multiple components / security or performance impact → Reviewer x 2+
   - Clearly separated research themes → Researcher x (number of themes)

   > **Scope:** Only Variable-Count Agents (Reviewer, Researcher) are listed in the `### Agent Composition` section. Fixed-count agents (Writer x 1, Developer x 1, etc.) are determined by the Agent Composition Table in `commands/autopilot.md` and do not need to be listed here.

Present as:

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

**Before** presenting the plan, verify all of these pass. Fix the plan if any fail.

| Check | Bad | Good |
|-------|-----|------|
| All ACs mapped to test layers | AC without mapping | Every AC has a test layer |
| Test layer choices justified | "Unit" with no reason | "Unit -- pure calculation, no dependencies" |
| Target files identified | "improve CI" | "change ci.yml line 100" |
| Design decisions resolved | "choose A or B" | "A chosen (reason: ...)" |
| Outer loop test defined | No story test | Story test layer and rationale specified |
| Variable-Count Agent count and focus are concrete | "Reviewer x N" | "Reviewer x 2: (1) security perspective (2) performance perspective" |

Include check results at the end of the plan:

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

Post the plan with `gh issue comment`.

Format:

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
| [design choice] | [why chosen] | [what else was considered and why rejected] |

> Record key design decisions and trade-offs made during planning. This remains in the Issue comment as the permanent record.

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

> If no Variable-Count Agents are used in a Phase for this task type, write "N/A" in the Focus column.

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

Before requesting approval, classify each item in the plan by risk level to reduce approval burden:

| Indicator | Classification | Criteria | User Action |
|-----------|---------------|----------|-------------|
| 🔴 | Decision required | Design policy change, new architectural pattern, safety tradeoff | Must review and explicitly approve |
| 🟡 | Confirmation | Direction decided but details may need adjustment | Quick scan, approve unless concerns |
| 🟢 | Auto-approve | Previously approved items, technical details, mechanical changes | No action needed |

Present the approval request in this format:

```markdown
## Approval Request

### 🔴 Decision Required
| Item | Detail | Decision Point |
|------|--------|---------------|
| [AC/decision] | [what it does] | [what needs deciding] |

### �� Confirmation
| Item | Detail |
|------|--------|
| [AC/decision] | [what it does] |

### 🟢 Auto-approved
| Item | Reason |
|------|--------|
| [AC/decision] | [why it's pre-approved] |
```

### Step 8: Request Approval and Label

After posting, add the `ready-for-plan-review` label and STOP:

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

## Handling Large Plans

If 7 or more ACs are mapped, suggest splitting the Issue:

```
The plan covers [N] ACs (7 or more -- consider splitting).
Consider splitting the Issue:

- Issue A: [scope] -- [N1] ACs
- Issue B: [scope] -- [N2] ACs
```

Then use AskUserQuestion with:
- header: "Split?"
- options:
  1. "(Recommended) Split into smaller Issues"
  2. "Continue as-is (document reason)"
- multiSelect: false

Recommended: Split — reply 'ok' to accept, or provide alternative

---

## Mandatory Checklist

Do not skip any item.

- [ ] Not editing code or files (Issue comments only)
- [ ] Not writing test code or implementation code
- [ ] All ACs have test layer mappings
- [ ] Test layer choices have rationale
- [ ] File paths are exact ("somewhere" / "appropriate location" is banned)
- [ ] Outer loop story test is defined
- [ ] Readiness Check was executed
- [ ] `ready-for-plan-review` label added after posting
- [ ] Deliverables posted as Issue comment
