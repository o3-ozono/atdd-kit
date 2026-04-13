---
name: discover
description: "Explore requirements through dialogue and derive ACs (Given/When/Then). First step of the Issue Ready flow. Used for all task types: development, bug, refactoring, documentation, research."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# discover Skill -- Requirements Exploration and AC Derivation

<HARD-GATE>
Do NOT invoke plan, atdd, or any implementation skill until the user has APPROVED the deliverables (DoD, ACs, or both) produced by this skill. This applies to EVERY task regardless of perceived simplicity. "Too simple to need discovery" is a rationalization -- all tasks start here.

**Autopilot exception:** When discover is invoked via autopilot (ARGUMENTS contains `--autopilot`), the approval gate in Step 7 is satisfied by the AC Review Round that follows. The user approves the final AC set after Three Amigos review — not during discover's Step 7. This is NOT a bypass of the approval requirement; it is a relocation of when approval occurs. Both conditions must hold: (1) ARGUMENTS contains `--autopilot`, AND (2) the AC Review Round completes with user approval.
</HARD-GATE>

<AUTOPILOT-GUARD>
If ARGUMENTS does not contain `--autopilot` (user invoked directly via slash command):
- Display message: "This skill is autopilot-only. Use `/atdd-kit:autopilot <number>` instead."
- **STOP.** Do not proceed with execution.
If ARGUMENTS contains `--autopilot` (invoked by autopilot): skip this guard silently.
</AUTOPILOT-GUARD>

The first step of the Issue Ready flow. Through dialogue, understand requirements, explore approaches, and produce structured deliverables (DoD for all tasks; User Story + ACs for code-change tasks; DoD replaces completion criteria for docs/research).

> **Used for all task types.** Development, bug, refactoring, documentation, research -- all start here.

---

## Core Principles

Follow these **always**. No exceptions.

| # | Principle | Detail |
|---|-----------|--------|
| D1 | **One question at a time** | Do not bundle multiple questions in one message |
| D2 | **Offer choices** | Present 2-3 options when possible to reduce user effort |
| D3 | **Explore 2-3 approaches** | Do not rush into one approach. Show tradeoffs and recommend one |
| D4 | **Respect the approval gate** | Do not advance to the next skill until the user approves the deliverables |
| D5 | **Post deliverables as Issue comments** | No repository file commits. Use `gh issue comment`. |
| D6 | **No code edits** | This skill edits no code and no files (Issue comments only) |
| D7 | **Split Issues/PRs by user flow** | Not by technical layer |

---

## Exclusive Lock Acquisition

Before starting any work, acquire the `in-progress` lock on the Issue:

```bash
gh issue edit <number> --add-label "in-progress"
```

If the Issue already has `in-progress`, another process is working on it. **Do not proceed.** Report to the user and exit.

## Task Type Detection

Detect the task type from Issue labels or user description at skill startup.

| Label | Task Type | Flow |
|-------|-----------|------|
| `type:development` | Development | Development flow |
| `type:bug` | Bug | Bug flow |
| `type:development` + `refactoring` | Refactoring | Refactoring flow |
| `type:documentation` | Documentation | Docs/research flow |
| `type:research` | Research | Docs/research flow |

If unclear, ask with AskUserQuestion:

```
What type of task is this?
1. Development (new feature / enhancement)
2. Bug fix
3. Refactoring
4. Documentation
5. Investigation
```

---

## Default Recommendation Pattern

At every decision point in discover, present a recommended default. The user can accept with "ok" or provide an alternative.

Format: `Recommended: [X] — reply 'ok' to accept, or provide alternative`

This applies to: approach selection, user story confirmation, AC approval, and all other decision points.

---

## Context Block Reading

Before starting the task-type-specific flow, check the Issue comments for a `## Context Block` section posted by issue/bug/ideate skills. If found:

1. Read the Context Block fields (task_type, requirements, environment, collected_info)
2. Skip redundant questions that are already answered in the Context Block
3. Use the collected information as starting context for the flow

This prevents re-asking questions that the user already answered during Issue creation or bug intake.

---

## Development Flow (type:development)

Execute these steps **in order**. Do not skip any.

### Step 1: Understand the Requirements

1. Read the Issue to understand what (What), why (Why), and who (Who)
2. Ask questions **one at a time** if information is missing
3. Explore the codebase for existing implementations and design patterns
4. Check `docs/` for technical documentation to avoid contradicting established designs

### Step 2: Approach Exploration

> **Equal-detail rule:** All approaches must be described with the same level of detail for Summary, Pros, Cons, Impact, and Risks. Do not give the recommended approach more detail than alternatives.
>
> **Minimum detail guard:** Each Pros and Cons section must contain at least 2 bullet items per approach. Single-item lists indicate insufficient analysis.

1. Consider 2-3 approaches
2. **For Complex classification only:** Use the Agent tool to launch parallel subagents (2-3) to investigate each approach's feasibility simultaneously. Each agent explores one approach and reports back. Collect results into a comparison table.
3. For each approach:
   - **Summary:** 1-2 sentence description
   - **Pros:** bullet list
   - **Cons:** bullet list
   - **Impact:** files/modules that need changes
   - **Risks:** anticipated risks
4. **Recommend** one approach and explain why
5. Ask the user to choose (as a single question):

```
I've considered these approaches:

**A: [Approach name]**
- Summary: ...
- Pros: ...
- Cons: ...

**B: [Approach name]**
- Summary: ...
- Pros: ...
- Cons: ...

**Recommended: A** (reason: ...)

Which approach? [A / B / Suggest alternative]
```

5. Repeat until the user approves

### Step 2.5: DoD Derivation

Based on the approved approach, derive the **Definition of Done** for this task.

DoD items describe *when the task is complete* (delivery conditions), not *how* the feature behaves.

Typical DoD items:
- Implementation satisfies all ACs
- All new code has tests at the appropriate layer
- No regression in existing tests
- PR reviewed and merged

Confirm with the user or proceed with defaults:

```
Recommended DoD:
- [ ] [condition 1]
- [ ] [condition 2]
...

Reply 'ok' to accept, or suggest additions/changes.
```

### Step 3: User Story Derivation

Based on the approved approach, derive a user story.

Format:

```
**As a** [persona],
**I want to** [goal],
**so that** [reason].
```

Confirm with the user:

```
Does this user story look right?

**As a** [persona], **I want to** [goal], **so that** [reason].

[OK / Suggest revision]
```

### Step 4: Acceptance Criteria Derivation

Derive ACs from the user story in Given/When/Then format.

- **3 or more ACs** per story
- Cover happy path, error cases, and boundary conditions
- Each AC must be independently verifiable

> **Split heuristic:** If the AC count reaches 7 or more, consider splitting the story. If splitting is inappropriate, document the reason and continue.

Format:

```
#### AC1: [Name]
- **Given:** [precondition]
- **When:** [action]
- **Then:** [expected result]
```

### Step 5: UX Heuristic Check

**Required for development tasks. Do not skip.**

Check the following 5 items for AC coverage. Add ACs where gaps exist.

| # | Aspect | Check |
|---|--------|-------|
| U1 | **Visibility of System Status** | Is processing/completion/error state communicated to the user? |
| U2 | **User Control and Freedom** | Can the user undo or redo? |
| U3 | **Consistency** | Does it match existing UI patterns and terminology? |
| U4 | **Error Prevention** | Are there safeguards against mistakes? |
| U5 | **Efficiency of Use** | Can frequent actions be performed efficiently? |

For each item:
- **Applicable:** Describe specifics. Add an AC if coverage is missing.
- **Not applicable:** State why (briefly).

### Step 6: Interruption Scenario Check

**Required for development tasks. Do not skip.**

Check the following 4 items. Add ACs where gaps exist.

| # | Scenario | Check |
|---|----------|-------|
| I1 | **Tab switch tolerance** | Is state preserved when the user navigates away and returns? |
| I2 | **Cancel state cleanup** | Is intermediate state cleared when the user cancels? |
| I3 | **Background resume** | Does the app work correctly after returning from background? |
| I4 | **Modal escape** | Can modals/dialogs be dismissed (including gestures)? |

For each item:
- **Applicable:** Describe specifics. Add an AC if coverage is missing.
- **Not applicable:** State why (briefly).

### Step 7: Present Deliverables and Get Approval

**Autopilot mode** (ARGUMENTS contains `--autopilot`): Skip the approval request. Output the draft AC set and return to the caller. The AC Review Round in autopilot will handle user approval. Do NOT proceed to Step 8.

**Standalone mode** (ARGUMENTS does not contain `--autopilot` — user invoked discover directly): Present the full AC set to the user:

```
Please review these ACs:

[AC list]

[UX check results]

[Interruption scenario check results]

Approve? [Approve / Needs revision]
```

- **Needs revision:** Confirm revision details one at a time, update ACs, re-present
- **Approve:** Proceed to Step 8

### Step 8: Post to Issue Comment and Inline Plan Execution

> **Autopilot mode skip:** When ARGUMENTS contains `--autopilot`, this step is skipped entirely. Issue comment posting and plan execution are handled by the autopilot AC Review Round after user approval.

Post the approved deliverables with `gh issue comment`.

**Inline plan mode (AC9 — approval gate integration):** After posting ACs, automatically execute plan's Core Flow (Steps 2-5) inline. Produce a combined comment containing both AC set and implementation plan, so the user can approve both in a single review.

Format:

```markdown
## discover Deliverables

### DoD (Definition of Done)
- [ ] [verifiable DoD item 1]
- [ ] [verifiable DoD item 2]
- ...

### Approach
[Description of chosen approach]

### Discussion Summary

| Approach | Summary | Verdict |
|----------|---------|---------|
| A: [name] | [1-line summary] | ✅ Selected — [rationale] / ❌ Rejected — [reason] |
| B: [name] | [1-line summary] | ✅ Selected — [rationale] / ❌ Rejected — [reason] |

> Record all considered approaches, rejected options, and the selection rationale here. This section is consumed by the `record` skill to generate a permanent Decision Record in `docs/decisions/`.

### User Story
**As a** [persona], **I want to** [goal], **so that** [reason].

### Acceptance Criteria

#### AC1: [Name]
- **Given:** [precondition]
- **When:** [action]
- **Then:** [expected result]

#### AC2: [Name]
- **Given:** [precondition]
- **When:** [action]
- **Then:** [expected result]

...

### UX Check Results
- U1: [applicable/not applicable + details]
- U2: [applicable/not applicable + details]
- U3: [applicable/not applicable + details]
- U4: [applicable/not applicable + details]
- U5: [applicable/not applicable + details]

### Interruption Scenario Check Results
- I1: [applicable/not applicable + details]
- I2: [applicable/not applicable + details]
- I3: [applicable/not applicable + details]
- I4: [applicable/not applicable + details]

### Implementation Plan (inline from plan)
[Test Strategy + Implementation Strategy — produced by plan Core Flow]
```

---

## Bug Flow (type:bug)

### Step 1: Understand the Bug

1. From the Issue or user report, identify:
   - **Symptom:** What is happening
   - **Reproduction steps:** How to reproduce
   - **Environment:** OS, device, version
   - **Expected behavior:** What should happen
2. Ask questions **one at a time** if information is missing

### Step 2: Root Cause Investigation

1. Investigate the codebase to identify the root cause
2. Classify the root cause:

| Class | Description | Example |
|-------|-------------|---------|
| **A: AC Gap** | Not covered by any AC | Undefined input pattern |
| **B: Test Gap** | AC exists but tests are insufficient | Missing test case |
| **C: Logic Error** | Tests exist but implementation is wrong | Incorrect conditional |

3. Report to the user:

```
Root cause identified.

**Classification:** [A / B / C] -- [class name]
**Cause:** [description]
**Code:** [file path and line number]

Is this analysis correct? [Yes / Needs correction]
```

### Step 3: Fix Approach Exploration

Same as development flow Step 2: explore 2-3 approaches and get approval.

### Step 3.5: DoD Derivation

Same as development flow Step 2.5: derive DoD items for this bug fix. Always include:
- The bug no longer reproduces under the original reproduction steps
- Regression test passes

### Step 4: Fix AC Derivation

Based on the approved approach, derive fix ACs in Given/When/Then format.

- **Regression test AC:** Describe the bug's reproduction condition as an AC (must pass after fix)
- **Normal behavior AC:** Verify correct behavior after the fix

### Step 5: Present Deliverables and Get Approval

Present the full AC set (same as development flow Step 7).

### Step 6: Post to Issue Comment

Post approved deliverables with `gh issue comment`.

Format:

```markdown
## discover Deliverables

### DoD (Definition of Done)
- [ ] The bug no longer reproduces under the original reproduction steps
- [ ] Regression test for this bug passes
- [ ] [other verifiable DoD item]

### Root Cause
**Classification:** [A / B / C] -- [class name]
**Cause:** [description]
**Code:** [file path and line number]

### Fix Approach
[Description of chosen approach]

### Acceptance Criteria

#### AC1: [Name] (regression test)
- **Given:** [bug precondition]
- **When:** [action that triggers the bug]
- **Then:** [expected result after fix]

#### AC2: [Name]
- **Given:** [precondition]
- **When:** [action]
- **Then:** [expected result]

...
```

---

## Refactoring Flow (type:development + refactoring)

Same steps as development flow, with these differences:

- **User story perspective:** The subject is a developer or team (e.g., "As a developer, I want X to be easier to test")
- **AC focus:** Always include an AC verifying that externally observable behavior is unchanged
- **UX / Interruption checks:** Mark as not applicable for pure internal refactoring (don't skip -- explicitly state not applicable with a reason)

---

## Documentation / Research Flow (type:documentation / type:research)

### Step 1: Understand the Scope

1. Read the Issue to understand the scope of the research/documentation
2. Ask questions **one at a time** if information is missing

### Step 2: Approach Exploration

1. Consider 2-3 approaches, present to user
2. Get approval

### Step 3: DoD Derivation

Define the **Definition of Done** — verifiable completion conditions. Vague criteria are not allowed.

| Bad | Good |
|-----|------|
| "investigate" | "post conclusion about X to Issue comment" |
| "improve docs" | "add section Y to docs/X.md with code examples for Z" |
| "improve" | "lint errors reach zero" |

### Step 4: Present Deliverables and Get Approval

Present DoD items:

```
Are these DoD items acceptable?

- [ ] [DoD item 1]
- [ ] [DoD item 2]
- ...

[Approve / Needs revision]
```

### Step 5: Post to Issue Comment

Post approved deliverables with `gh issue comment`.

Format:

```markdown
## discover Deliverables

### DoD (Definition of Done)
- [ ] [verifiable DoD item 1]
- [ ] [verifiable DoD item 2]
- ...

### Scope
[Investigation/documentation scope]

### Approach
[Description]
```

---

## Skill Completion and Transition

After deliverables are posted and approved:

1. Show:
   ```
   discover complete. Next: `atdd-kit:plan` to create the implementation plan.
   ```
2. Invoke `atdd-kit:plan` via the Skill tool.

---

## Mandatory Checklist

Do not skip any item.

- [ ] Not editing code or files (Issue comments only)
- [ ] Not bundling multiple questions in one message
- [ ] Approach exploration done (2-3 approaches presented)
- [ ] DoD derivation step completed (Step 2.5 for dev/bug/refactoring; Step 3 for docs/research)
- [ ] DoD section is at the top of the Issue comment
- [ ] Not skipping UX check (U1-U5) for development tasks
- [ ] Not skipping interruption scenario check (I1-I4) for development tasks
- [ ] ACs are in Given/When/Then format
- [ ] If ACs are 7 or more, the split self-check has been performed
- [ ] User approved the deliverables
- [ ] Deliverables posted as Issue comment
