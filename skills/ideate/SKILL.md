---
name: ideate
description: "Pre-Issue design exploration. Auto-triggers on exploratory requests like 'I want to build...', 'how should we design...', 'let's think about...'. Guides approach comparison before Issue creation."
---

# ideate -- Design Exploration Before Issue Creation

Explore ideas, compare approaches, and reach a design decision **before** creating an Issue. This is the brainstorming phase -- no commitments yet.

## When to Use

- User has a vague idea but no Issue yet
- User wants to compare approaches before committing
- User says "I want...", "how about...", "let's think about...", "what if..."

## Principles

| # | Principle | Detail |
|---|-----------|--------|
| I1 | **No code edits** | Do not write code, create files, or modify the repository |
| I2 | **No Issue creation** | This skill explores. Issue creation is the next step (auto-chain) |
| I3 | **One question at a time** | Do not bundle multiple questions |
| I4 | **Always compare approaches** | Present 2-3 options with Pros/Cons before converging |

## Flow

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

Proceed to create an Issue? [Yes / Not yet]
```

### Step 4: Transition

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

## Prohibition Checklist

- [ ] Not editing code or files
- [ ] Not creating Issues (that's the next skill's job)
- [ ] Not skipping approach comparison
- [ ] Asking one question at a time
