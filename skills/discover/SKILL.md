---
name: discover
description: "Explore requirements through dialogue and derive ACs (Given/When/Then). First step of the Issue Ready flow. Used for all task types: development, bug, refactoring, documentation, research."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# discover Skill -- Requirements Exploration and AC Derivation

<HARD-GATE>
Do NOT invoke plan, atdd, or any implementation skill until the user has APPROVED the deliverables (DoD, ACs, or both). No exceptions regardless of perceived simplicity.

**Autopilot exception:** When invoked with `--autopilot`, Step 7 approval is satisfied by the AC Review Round. Both conditions must hold: (1) ARGUMENTS contains `--autopilot`, AND (2) AC Review Round completes with user approval.
</HARD-GATE>

<AUTOPILOT-GUARD>
If ARGUMENTS does not contain `--autopilot` (user invoked directly via slash command):
- Display message: "This skill is autopilot-only. Use `/atdd-kit:autopilot <number>` instead."
- **STOP.** Do not proceed with execution.
If ARGUMENTS contains `--autopilot` (invoked by autopilot): skip this guard silently.
</AUTOPILOT-GUARD>

First step of the Issue Ready flow. Understand requirements, explore approaches, and produce structured deliverables (DoD for all tasks; User Story + ACs for code-change tasks).

---

## Core Principles

| # | Principle | Detail |
|---|-----------|--------|
| D1 | **One question at a time** | Do not bundle multiple questions |
| D2 | **Offer choices** | Present 2-3 options to reduce user effort |
| D3 | **Explore 2-3 approaches** | Show tradeoffs and recommend one |
| D4 | **Respect the approval gate** | Do not advance until user approves deliverables |
| D5 | **Post deliverables as Issue comments** | Use `gh issue comment`. No repository commits. |
| D6 | **No code edits** | No code or repository source file edits. **Documentation artifact exception:** Writing to `docs/personas/` (new persona files) and `docs/specs/` (spec files) is permitted. These are the only two exceptions. |
| D7 | **Split Issues/PRs by user flow** | Not by technical layer |

---

## Persona Requirement by Flow

Persona selection and User Story derivation are required only for flows that target user-facing outcomes. Refactoring and docs/research flows are internal or informational and do not require a persona.

| Flow | Persona Required | User Story Required | Reason |
|------|------------------|---------------------|--------|
| development (`type:development`) | Yes | Yes | `As a [persona]` anchors the goal |
| bug (`type:bug`) | Yes | Yes | Impacted user context is needed to judge "what is a bug" |
| refactoring (`type:development` + `refactoring`) | No | No | Externally observable behavior unchanged; subject is developer/team |
| research (`type:research`) | No | No | Not a user-facing deliverable |
| documentation (`type:documentation`) | No | No | Not a user-facing deliverable |

For flows marked "Yes", Step 3a (Persona Selection) runs and the autopilot prerequisite check applies. For flows marked "No", Step 3a is skipped entirely.

## Valid Persona Definition

A persona file is considered **valid** when all of the following hold. The authoritative check lives in `lib/persona_check.sh` and is shared by autopilot Phase 0.9 prerequisite check and Step 3a precheck so both locations agree.

- Located directly under `docs/personas/` (not a subdirectory)
- File name ends with `.md`
- Not a hidden file (does not start with `.`)
- Not `README.md` or `TEMPLATE.md`
- Non-empty
- `TEMPLATE.md` placeholder `[Persona Name]` has been replaced

`count_valid_personas` treats a missing `docs/personas/` directory as zero. Symlinks are followed.

---

## Exclusive Lock Acquisition

```bash
gh issue edit <number> --add-label "in-progress"
```

If `in-progress` already exists, another process owns it. Report and exit.

## Task Type Detection

Detect task type from Issue labels or user description at startup.

| Label | Task Type | Flow |
|-------|-----------|------|
| `type:development` | Development | Development flow |
| `type:bug` | Bug | Bug flow |
| `type:development` + `refactoring` | Refactoring | Refactoring flow |
| `type:documentation` | Documentation | Docs/research flow |
| `type:research` | Research | Docs/research flow |

If unclear, use AskUserQuestion (2-stage split — 5 types exceed 4-option limit):

**Q1:**
- header: "Task Type?"
- options: "(Recommended) Development", "Bug fix", "Other (refactoring / documentation / investigation)"
- multiSelect: false

**Q2** (only if "Other"):
- header: "Detail type?"
- options: "Refactoring", "Documentation", "Investigation"
- multiSelect: false

---

## Default Recommendation Pattern

At every decision point, present a recommended default. Accept with "ok" or provide alternative.

Format: `Recommended: [X] — reply 'ok' to accept, or provide alternative`

---

## Context Block Reading

Before the task-type-specific flow, check Issue comments for `## Context Block` (posted by issue/bug/ideate skills). If found:

1. Read task_type, requirements, environment, collected_info
2. Skip questions already answered
3. Use as starting context

---

## Development Flow (type:development)

Execute in order.

### Step 1: Understand the Requirements

1. Read the Issue: What, Why, Who
2. Ask questions one at a time if missing
3. Explore codebase for existing patterns
4. Check `docs/` for design constraints

### Step 2: Approach Exploration

> **Equal-detail rule:** All approaches get the same depth: Summary, Pros, Cons, Impact, Risks.
> **Minimum detail guard:** At least 2 bullets per Pros/Cons.

1. Consider 2-3 approaches
2. **Complex only:** Agent tool — 2-3 parallel subagents, one per approach; collect into comparison table.
3. For each: Summary, Pros, Cons, Impact, Risks
4. Recommend one and explain why
5. Ask the user to choose:

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
```

Then use AskUserQuestion with:
- header: "Approach?"
- options:
  1. "(Recommended) [recommended approach name] — [brief reason]"
  2. "[alternative approach name]"
  3. "Suggest alternative"
- multiSelect: false

Recommended: [recommended approach] — reply 'ok' to accept, or provide alternative

5. Repeat until the user approves

### Step 2.5: DoD Derivation

Derive the **Definition of Done** — delivery conditions (when complete, not how it behaves).

Typical DoD items: all ACs satisfied, tests at appropriate layer, no regressions, PR merged.

Confirm or proceed with defaults:

```
Recommended DoD:
- [ ] [condition 1]
- [ ] [condition 2]
...
```

AskUserQuestion — header: "DoD?", options: "(Recommended) Accept DoD as listed", "Suggest additions or changes"

Recommended: Accept DoD — reply 'ok' to accept, or provide alternative

### Step 3: User Story Derivation

#### Step 3a: Persona Selection

Before drafting the user story, identify the persona for the `As a` field. Step 3a runs only for persona-required flows — see "Persona Requirement by Flow" above.

**Persona lookup:**

Count valid persona files under `docs/personas/` using `lib/persona_check.sh count_valid_personas` (see "Valid Persona Definition").

```
IF --autopilot AND valid_persona_count == 0:
  → Persona precheck BLOCKED (Step 3a-precheck)
ELSE IF valid_persona_count >= 1:
  → Persona listing flow (Step 3a-listing)
ELSE (standalone AND valid_persona_count == 0):
  → Persona bootstrap flow (Step 3a-bootstrap)
```

**Step 3a-precheck** (autopilot mode with no valid personas):

Do **not** create a new persona. Autopilot has no user dialogue, so bootstrapping would synthesize an Issue-specific persona from the Issue body and violate `docs/methodology/persona-guide.md` ("Creation Process" / Anti-Pattern 1 / Anti-Pattern 2).

1. Emit the guidance from `bash lib/persona_check.sh get_persona_guidance_message`.
2. Output a `skill-status` block with `SKILL_STATUS: BLOCKED` and `PHASE: discover`.
3. STOP. Do not proceed to Step 3b.

**Step 3a-listing** (valid personas exist):

List the valid persona files and present them as options:

```
Available personas:
- [PersonaA] (docs/personas/personaA.md)
- [PersonaB] (docs/personas/personaB.md)
```

Then use AskUserQuestion with:
- header: "Select persona for the User Story:"
- options:
  1. "(Recommended) [most relevant persona name] — [one-line description]"
  2. "[other persona names, one per option]"
  3. "Create a new persona"
- multiSelect: false

Recommended: [most relevant persona] — reply 'ok' to accept, or select another

If only one persona exists, present it as the sole recommended option with "Create new" as the alternative.

**Autopilot auto-selection:** In autopilot mode, do not use AskUserQuestion. Pick the most relevant valid persona (highest-affinity match to the Issue body) and use it as the `As a` subject. Do **not** create a new persona even if affinity is low — the listing flow never creates new personas in autopilot.

**Step 3a-bootstrap** (standalone only — D6 exception: documentation artifact creation in `docs/personas/` is permitted):

> **Autopilot prohibited.** 3a-bootstrap never runs under `--autopilot`. Step 3a-precheck BLOCKs instead.

Prompt the user to define a new persona:

```
No personas found in docs/personas/. Let's create one.
```

Then collect the following fields **one at a time** (D1):
1. **Name** — fictional name (consistent with target locale)
2. **Role / Job Title** — job and organizational context
3. **Goals** — primary goal and secondary goal
4. **Context** — technical level, environment, constraints
5. **Quote** — one-sentence quote in the persona's voice

After collecting all fields, create `docs/personas/` directory if it does not exist, then save `docs/personas/<name>.md` following `docs/personas/TEMPLATE.md` format. Confirm the saved persona to the user.

#### Step 3b: User Story Draft

Based on the approved approach and the selected (or newly created) persona, derive a user story.

Format: `**As a** [persona], **I want to** [goal], **so that** [reason].`

```
**As a** [persona name],
**I want to** [goal],
**so that** [reason].
```

Confirm with the user:

```
Does this user story look right?

**As a** [persona], **I want to** [goal], **so that** [reason].
```

AskUserQuestion — header: "User Story?", options: "(Recommended) Looks good — proceed", "Suggest revision"

Recommended: Looks good — reply 'ok' to accept, or provide alternative

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

### Step 4.5: US/AC Quality Validation (development flow only)

**Scope:** This step applies to **development flow only**. Skip entirely for bug, refactoring, documentation, and research flows.

Load `docs/methodology/us-quality-standard.md` and run the following checks.

#### MUST Criteria (blocking)

Validate all three MUST criteria. Any failure blocks progression.

| Criterion | Check |
|-----------|-------|
| **MUST-1** | `As a` field references a named persona from `docs/personas/` (not a generic placeholder like "user" or "developer" without a persona file). The persona selected or created in Step 3a satisfies this automatically. |
| **MUST-2** | AC count ≥ 3 |
| **MUST-3** | Each AC has a verifiable `Then` clause. Fail markers: vague phrases like "works correctly", "handles it", "is satisfied", or any subjective/unmeasurable outcome. Pass examples: "CSV downloads within 2 seconds", "returns HTTP 400 with error message". |

**On MUST failure:**
1. Report the specific criterion violated with a rewrite suggestion.
2. Ask the user to revise (one revision round).
3. Re-validate after revision.
4. If still failing after 2 revision rounds, escalate to the user with full details and pause for manual resolution.

**In autopilot mode:** Include MUST violation details in the draft deliverables returned to the AC Review Round rather than blocking inline.

#### SHOULD Criteria (non-blocking)

After all MUST criteria pass, check SHOULD-1 through SHOULD-5 and the anti-pattern categories. Report each violation **individually** with:
- Criterion ID (e.g., "SHOULD-2 violation")
- Explanation of the violation
- Specific rewrite suggestion

If all SHOULD criteria pass, report: "All SHOULD criteria pass."

Flow proceeds regardless of SHOULD violations.

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

Applicable: describe specifics, add AC if missing. Not applicable: state why.

### Step 6: Interruption Scenario Check

**Required for development tasks. Do not skip.**

Check the following 4 items. Add ACs where gaps exist.

| # | Scenario | Check |
|---|----------|-------|
| I1 | **Tab switch tolerance** | Is state preserved when the user navigates away and returns? |
| I2 | **Cancel state cleanup** | Is intermediate state cleared when the user cancels? |
| I3 | **Background resume** | Does the app work correctly after returning from background? |
| I4 | **Modal escape** | Can modals/dialogs be dismissed (including gestures)? |

Applicable: describe specifics, add AC if missing. Not applicable: state why.

### Step 7: Present Deliverables and Get Approval

**Autopilot mode** (`--autopilot`): Skip approval. Output a `skill-status` fenced code block with `SKILL_STATUS: COMPLETE` as the **only** output. Do NOT include draft AC listings, UX check results, Interruption check results, or Discussion Summary in terminal output. Do NOT proceed to Step 8.

**Standalone mode:** Present AC set, UX check results, and interruption check results.

AskUserQuestion — header: "Approve ACs?", options: "(Recommended) Approve — proceed to plan", "Needs revision"

Recommended: Approve — reply 'ok' to accept, or provide alternative

- **Needs revision:** Confirm revision details one at a time, update ACs, re-present
- **Approve:** Proceed to Step 8

### Step 8: Post to Issue Comment, Spec File Creation, and Inline Plan Execution

> **Autopilot mode:** Skip entirely. AC Review Round handles posting and plan.

Post approved deliverables with `gh issue comment`.

**Spec file creation (standalone mode only — D6 exception: documentation artifact creation in `docs/specs/` is permitted):**

After posting the Issue comment, create a spec file:

1. Derive the `<kebab-slug>` from the Issue title's main noun phrase:
   - Strip conventional prefixes (`feat:`, `fix:`, `chore:`, etc.)
   - English title: convert main noun phrase to kebab-case (e.g., `feat: Add login rate limiting` → `login-rate-limiting`)
   - Japanese title: translate the main concept to English, then kebab-case (e.g., `feat: discover スキルへのペルソナ統合` → `discover-persona-integration`)
2. Create `docs/specs/` directory if it does not exist.
3. Create `docs/specs/<kebab-slug>.md` with the following structure:

```markdown
---
title: "[Issue title]"
persona: "[selected persona name]"
issue: "#[issue number]"
status: approved
---

## User Story

**As a** [persona],
**I want to** [goal],
**so that** [benefit].

## Acceptance Criteria

### AC1: [short name]

- **Given:** [precondition]
- **When:** [action]
- **Then:** [expected outcome]

### AC2: [short name]

...

## Notes

[Optional: design decisions, risks, deferred work, references]
```

The `status` field is set to `approved` because Step 8 is reached only after user approval (discover phase complete).

**Inline plan mode:** After posting ACs, execute plan's Core Flow (Steps 2-5) inline. Produce a combined comment with AC set + implementation plan, so the user can approve both in a single review.

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

> Record all considered approaches, rejected options, and the selection rationale here. This remains in the Issue comment as the permanent record.

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

1. Identify: Symptom, Reproduction steps, Environment (OS/device/version), Expected behavior
2. Ask questions one at a time if missing

### Step 2: Root Cause Investigation

1. Investigate the codebase
2. Classify:

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
```

Then use AskUserQuestion with:
- header: "Root Cause?"
- options:
  1. "(Recommended) Correct — proceed to fix approach"
  2. "Needs correction"
- multiSelect: false

Recommended: Correct — reply 'ok' to accept, or provide alternative

### Step 3: Persona Selection and User Story Derivation

Bug flow requires a persona because "is this a bug?" is a judgement about user impact. Without a named user, the same behaviour can be read as a bug for one audience and working-as-intended for another. Run the same Persona Selection logic as the development flow.

**Persona Selection:** Apply development flow **Step 3a** verbatim — the precheck / listing / bootstrap branches, the valid-persona definition, and the autopilot auto-selection rule all apply identically. When the precheck BLOCKs, emit the shared guidance from `lib/persona_check.sh get_persona_guidance_message` and STOP.

**User Story Derivation (bug context):** Once a persona is selected, derive a bug-focused User Story that names both the impacted persona and the failure condition:

```
**As** [persona],
**when I** [action that triggers the bug],
**I expect** [correct behaviour],
**but** [observed buggy behaviour].
```

The mandatory elements are: the selected persona from Step 3a, the action/state that reproduces the bug, and the gap between expected and observed behaviour. This story feeds Step 5 (Fix AC Derivation) — the Regression test AC should correspond to "when I ... I observed ..." and the Normal behavior AC to "I expect ...".

### Step 4: Fix Approach Exploration

Same as development flow Step 2.

### Step 4.5: DoD Derivation

Same as development flow Step 2.5. Always include:
- Bug no longer reproduces under original reproduction steps
- Regression test passes

### Step 5: Fix AC Derivation

Derive fix ACs in Given/When/Then format:
- **Regression test AC:** Bug's reproduction condition (must pass after fix)
- **Normal behavior AC:** Correct behavior after fix

Each AC's `Given`/`When`/`Then` should reference the persona selected in Step 3 (e.g., "Given [persona] is on [state], When they [action], Then [result]").

### Step 6: Present Deliverables and Get Approval

**Autopilot mode** (`--autopilot`): Output a `skill-status` fenced code block with `SKILL_STATUS: COMPLETE` as the **only** output. Do NOT include draft deliverables in terminal output. Do NOT proceed to Step 7.

**Standalone mode:** Present the full AC set to the user (same approval flow as development flow Step 7 standalone mode).

### Step 7: Post to Issue Comment

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

Same as development flow, with these differences:
- **DoD:** Always include "externally observable behavior is unchanged — verified by regression test suite"
- **User story:** Subject is developer or team (e.g., "As a developer, I want X to be easier to test")
- **ACs:** Always include an AC verifying unchanged external behavior
- **UX / Interruption checks:** Mark not applicable for pure internal refactoring — explicitly state reason

---

## Documentation / Research Flow (type:documentation / type:research)

### Step 1: Understand the Scope

Read the Issue. Ask questions one at a time.

### Step 2: Approach Exploration

Consider 2-3 approaches, present, get approval.

### Step 3: DoD Derivation

Define the **Definition of Done** — verifiable completion conditions only. Vague criteria are not allowed.

| Bad | Good |
|-----|------|
| "investigate" | "post conclusion about X to Issue comment" |
| "improve docs" | "add section Y to docs/X.md with code examples for Z" |
| "improve" | "lint errors reach zero" |

### Step 4: Present Deliverables and Get Approval

AskUserQuestion — header: "DoD?", options: "(Recommended) Approve DoD", "Needs revision"

Recommended: Approve DoD — reply 'ok' to accept, or provide alternative

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

## Status Output

**Autopilot mode only** (ARGUMENTS contains `--autopilot`). Skip in standalone mode.

Output a `skill-status` fenced code block as the **last element** of your response at every terminal point.

Terminal points:
- **COMPLETE:** Deliverables returned to AC Review Round (autopilot) or posted as Issue comment (standalone).
- **PENDING:** Waiting for user approval (standalone mid-flow).
- **BLOCKED:** HARD-GATE triggered or precondition not met.
- **FAILED:** Unrecoverable error (e.g., `gh issue comment` auth failure).

```skill-status
SKILL_STATUS: COMPLETE | PENDING | BLOCKED | FAILED
PHASE: discover
RECOMMENDATION: <next action or error description in one sentence>
```

Examples:

```skill-status
SKILL_STATUS: COMPLETE
PHASE: discover
RECOMMENDATION: Proceed to plan with approved ACs
```

```skill-status
SKILL_STATUS: BLOCKED
PHASE: discover
RECOMMENDATION: Issue is already locked by another in-progress process. Wait or remove the in-progress label to proceed.
```

```skill-status
SKILL_STATUS: BLOCKED
PHASE: discover
RECOMMENDATION: No valid personas in docs/personas/. Create at least one persona file before running autopilot. See docs/methodology/persona-guide.md.
```

```skill-status
SKILL_STATUS: FAILED
PHASE: discover
RECOMMENDATION: gh issue comment failed with authentication error. Check GH_TOKEN configuration.
```

See `docs/guides/skill-status-spec.md` for full field definitions, BLOCKED vs FAILED distinction, and autopilot action matrix.

---

## Skill Completion and Transition

After deliverables are posted and approved, show `"discover complete. Next: atdd-kit:plan"` and invoke `atdd-kit:plan` via the Skill tool.

---

## Mandatory Checklist

Do not skip any item.

- [ ] Not editing code or repository source files (D6: only docs/personas/ and docs/specs/ exceptions permitted)
- [ ] Not bundling multiple questions in one message
- [ ] Approach exploration done (2-3 approaches presented)
- [ ] DoD derivation done (Step 2.5 for dev/bug/refactoring; Step 3 for docs/research)
- [ ] DoD section at top of Issue comment
- [ ] Persona selected from docs/personas/ — Step 3a complete (persona-required flows: development and bug)
- [ ] Autopilot mode + 0 valid personas → Step 3a-precheck BLOCKED (no bootstrap, see persona-guide.md)
- [ ] UX check (U1-U5) not skipped for development tasks
- [ ] Interruption scenario check (I1-I4) not skipped for development tasks
- [ ] ACs in Given/When/Then format
- [ ] Split self-check done if ACs ≥ 7
- [ ] Step 4.5 quality validation executed — MUST-1/2/3 checked (development flow only)
- [ ] SHOULD advisory reviewed — SHOULD-1 through SHOULD-5 (development flow only)
- [ ] User approved deliverables
- [ ] Deliverables posted as Issue comment
- [ ] Spec file created at docs/specs/<kebab-slug>.md with status: approved (standalone mode, development flow only)
