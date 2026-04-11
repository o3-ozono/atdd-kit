---
name: ideate
description: "Pre-Issue design exploration. Auto-triggers on exploratory requests like 'I want to build...', 'how should we design...', 'let's think about...'. Guides approach comparison before Issue creation."
---

# ideate -- Design Exploration

Explore ideas, compare approaches, and reach a design decision. This is the brainstorming phase -- no commitments yet.

## Mode Detection

ideate operates in two modes, detected automatically:

| Mode | Condition | Chain |
|------|-----------|-------|
| **Pre-Issue mode** | No Issue exists (auto-triggered by exploratory request) | ideate → `atdd-kit:issue` → discover |
| **Post-Issue mode** | Issue number is provided (chained from `issue` skill) | ideate → `atdd-kit:discover` |

**How to detect:** If an Issue number argument is provided (e.g., from `issue` skill chain), this is **post-Issue mode**. Otherwise, **pre-Issue mode**.

## When to Use

- User has a vague idea but no Issue yet (pre-Issue mode, auto-triggered)
- Issue just created and user wants to brainstorm before requirements (post-Issue mode, chained from `issue`)

## Principles

| # | Principle | Detail |
|---|-----------|--------|
| I1 | **No code edits** | Do not write code, create files, or modify the repository |
| I2 | **No Issue creation** (pre-Issue) | In pre-Issue mode, this skill explores; Issue creation is the next step |
| I3 | **One question at a time** | Do not bundle multiple questions |
| I4 | **Always compare approaches** | Present 2-3 options with Pros/Cons before converging (unless skipped) |

---

## Post-Issue Mode

When an Issue number is provided (chained from `issue` skill):

### Step 0: Offer Skip

Present the option to skip brainstorming:

> Want to brainstorm before diving into requirements? [Yes / Skip to discover]

- If **Skip**: Chain directly to `atdd-kit:discover` (skip Steps 1-3, go to Step 4)
- If **Yes**: Continue to Step 1

### Step 1: Understand the Idea

Ask the user what they want to achieve. Understand:
- **Goal:** What problem are they solving?
- **Context:** What exists today?
- **Constraints:** Time, tech, scope limitations?

One question at a time. Do not assume.

### Step 2: Explore Approaches

Present 2-3 approaches:

```
**A: [Approach name]**
- Summary: [1-2 sentences]
- Pros: [bullet list]
- Cons: [bullet list]
- Impact: [files/modules affected]
- Risks: [anticipated risks]

**B: [Approach name]**
- Summary: ...
- Pros: ...
- Cons: ...

**Recommended: [A/B]** (reason: ...)

Which approach? [A / B / Suggest alternative]
```

Iterate until the user is satisfied with an approach.

### Step 3: Summarize Decision

Present a concise summary of what was decided:

```
## Design Decision

**Goal:** [what we're solving]
**Chosen approach:** [name and summary]
**Key tradeoffs:** [what we accepted]
**Scope:** [what's in and out]

Ready to proceed to requirements? [Yes / Not yet]
```

### Step 4: Transition to discover

Post a Context Block as an Issue comment to pass design context to discover:

```markdown
## Context Block

| Field | Value |
|-------|-------|
| task_type | [derived from design decision] |
| requirements | [goal and chosen approach summary] |
| environment | [any constraints identified] |
| collected_info | [design decision, tradeoffs, scope] |
```

Use `gh issue comment <number> --body "..."` to post the Context Block. Then:

> Design exploration complete. Running `atdd-kit:discover` to explore requirements.

Invoke `atdd-kit:discover` via the Skill tool.

---

## Pre-Issue Mode

When no Issue exists (auto-triggered by exploratory request):

### Step 1: Understand the Idea

(Same as post-Issue Step 1)

### Step 2: Explore Approaches

(Same as post-Issue Step 2)

### Step 3: Summarize Decision

Present a concise summary of what was decided:

```
## Design Decision

**Goal:** [what we're solving]
**Chosen approach:** [name and summary]
**Key tradeoffs:** [what we accepted]
**Scope:** [what's in and out]

Proceed to create an Issue? [Yes / Not yet]
```

### Step 4: Transition to issue

When the user approves:

> Design exploration complete. Creating an Issue with `atdd-kit:issue`.

Post a Context Block as an Issue comment (after issue creation) to pass design context to discover:

```markdown
## Context Block

| Field | Value |
|-------|-------|
| task_type | [derived from design decision] |
| requirements | [goal and chosen approach summary] |
| environment | [any constraints identified] |
| collected_info | [design decision, tradeoffs, scope] |
```

Invoke `atdd-kit:issue` via the Skill tool, passing the design context.

---

## Prohibition Checklist

- [ ] Not editing code or files
- [ ] Not creating Issues directly (pre-Issue mode chains to `issue` skill)
- [ ] Not skipping approach comparison (unless user chooses Skip in post-Issue mode)
- [ ] Asking one question at a time
