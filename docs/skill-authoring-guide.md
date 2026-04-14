# Skill Authoring Guide

Reference for designing dialogue UX in atdd-kit skills.
All skills that interact with users through questions must follow these principles.

## (a) Closed Question Priority — Recommended First

**Always use closed questions at key decision points.** A closed question presents concrete options and a recommended choice, so the user can approve or redirect rather than compose an answer from scratch.

**Principle:** Closed question first — Recommended as the first option.

```
# Bad: open question
Which test layer do you want to use?

# Good: closed question with Recommended
Use AskUserQuestion with:
  header: "Test layer?"
  options: ["(Recommended) Integration", "E2E", "Other"]
```

The recommended option must always be explicitly marked and placed first in the options list.

At every decision point, also include the Recommended pattern in the surrounding text so that
`Recommended: [X] — reply 'ok' to accept, or provide alternative` remains visible for users
who prefer text interaction. This ensures backward compatibility with existing bats tests
that grep for the `recommended.*ok` pattern.

## (b) AskUserQuestion Constraints

When using the `AskUserQuestion` tool, follow these constraints:

| Parameter | Constraint |
|-----------|-----------|
| `header` | ≤ 12 characters |
| `options` | 2 to 4 options (use `multiSelect: false` for single-choice, `multiSelect: true` for multi-choice) |
| `label` per option | ≤ 5 words |
| `Other` option | Included **automatically** — do not add it manually |

**header ≤ 12 characters example:**
- Good: `"Approach?"` (9 chars)
- Good: `"Test layer?"` (11 chars)
- Bad: `"Which approach should we use?"` (too long)

**label ≤ 5 words example:**
- Good: `"(Recommended) Integration"`
- Good: `"E2E — full user flow"`
- Bad: `"Integration test covering all cross-module boundaries"` (too many words)

**multiSelect usage:**
- Single decision (approve/select one): `multiSelect: false`
- Multiple items that can all apply: `multiSelect: true`

## (c) Other Option Fallback Behavior

When the user selects the automatically-provided `Other` option:

1. Accept the user's free-text input that follows
2. Incorporate the input as the chosen answer and proceed to the next step
3. Do not re-ask the same question

This ensures the user always has an escape hatch from predefined options.

## (d) Exception Rule for 5+ Options

If a decision point requires 5 or more options (5+ options), **do not** list them all in a single AskUserQuestion.
Use a question split or two-stage selection instead.

Instead, use one of these strategies:

**Strategy 1 — split question:** Break into two sequential questions.
```
Q1: "Category?" → options: ["Feature", "Bug fix", "Other"]
Q2 (if Feature): "Feature type?" → options: ["New screen", "Enhancement", "Other"]
```

**Strategy 2 — Two-stage selection:** Narrow by category first, then by specific option.

This keeps each AskUserQuestion within the 2-4 options constraint.

## (e) Free-Text Fields — Do NOT Use AskUserQuestion

The following fields require free-text input by nature. Do not replace them with AskUserQuestion:

| Skill | Free-text field |
|-------|----------------|
| `issue` | Issue title (Step 2 free input) |
| `bug` | Bug symptom (Phase 1 Q1), reproduction steps (Phase 1 Q3), environment details (Phase 1 Q4), logs/screenshots (Phase 1 Q5) |
| `discover` | Root Cause `Cause` description (Bug Flow Step 2), AC Given/When/Then body text |

**Rule:** If the user must compose a descriptive answer rather than select from a predefined set, use plain text prompting — not AskUserQuestion.

## (f) Key Decision Points by Skill

The following are the **key decision points** where AskUserQuestion must be used.
All other interaction points (information gathering, free-text fields) follow normal text prompting.

### ideate — key decision points

| # | Section | Decision |
|---|---------|---------|
| I-1 | Post-Issue Mode: Step 0 Skip offer | Brainstorm or skip to discover? |
| I-2 | ideate Step 2: Approach selection (Post and Pre mode) | Which approach to pursue? |
| I-3 | Step 3: Design Decision confirmation | Proceed or revise? |

### discover — key decision points

| # | Section | Decision |
|---|---------|---------|
| D-1 | discover Task Type Detection (when unclear) | Which task type is this? |
| D-2 | discover Step 2: Approach selection | Which approach? |
| D-3 | Step 3: User Story confirmation | OK or revise? |
| D-4 | Step 7: AC approval (Standalone mode) | Approve or needs revision? |
| D-5 | Bug Flow Step 2: Root Cause confirmation | Analysis correct or needs correction? |
| D-6 | Docs/Research Flow Step 4: DoD approval | Approve or needs revision? |

### issue — key decision points

| # | Section | Decision |
|---|---------|---------|
| IS-1 | issue Step 2/3: Priority confirmation | P1, P2, or P3? |

Note: issue Step 1 task-type auto-detection and Issue title collection are **not** key decision points.
Auto-detection proceeds without AskUserQuestion. Title input uses free text.

### plan — key decision points

| # | Section | Decision |
|---|---------|---------|
| P-1 | plan Step 3: Outer Loop test layer selection | E2E or Integration? |
| P-2 | plan Handling Large Plans: split decision | Split or continue as-is? |

### bug — key decision points

| # | Section | Decision |
|---|---------|---------|
| B-1 | bug Fix Proposal approval | Proceed with fix or revise? |

## (g) Language Policy

- **Skill authoring guide and all LLM-facing files** (`skills/`, `rules/`, `docs/`, `commands/`, `agents/`): **English only**
- Follow `DEVELOPMENT.md` i18n rules: no `*.ja.md` for LLM-facing files
- AskUserQuestion `header` and `options`: English (consistent with SKILL.md language)
- evals/evals.json `assertion text`: Japanese acceptable (existing convention)

See `DEVELOPMENT.md` § Language for the full language policy.

## AskUserQuestion + Recommended Pattern in SKILL.md

When writing SKILL.md instructions for a key decision point, use this pattern:

```markdown
Use AskUserQuestion with:
- header: "[short question ≤12 chars]"
- options:
  1. "(Recommended) [recommended choice]" — [brief rationale]
  2. "[alternative choice]"
  3. "[another alternative]"
- multiSelect: false

Recommended: [recommended choice] — reply 'ok' to accept, or provide alternative
```

The `Recommended: ... — reply 'ok' to accept` line ensures compatibility with existing
`test_interaction_reduction.bats` AC10 grep patterns.

## Example: Approach Selection (ideate Step 2)

```markdown
Use AskUserQuestion with:
- header: "Approach?"
- options:
  1. "(Recommended) Approach A — [reason]"
  2. "Approach B"
  3. "Suggest alternative"
- multiSelect: false

Recommended: Approach A — reply 'ok' to accept, or provide alternative
```
