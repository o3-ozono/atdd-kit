---
name: ideate
description: "Pre-Issue design exploration. Auto-triggers on exploratory requests like 'I want to build...', 'how should we design...', 'let's think about...'. Guides approach comparison before Issue creation."
---

# ideate -- Design Exploration

Explore ideas, compare approaches, reach a design decision. No commitments yet.

## Mode Detection

| Mode | Condition | Chain |
|------|-----------|-------|
| **Pre-Issue** | No Issue (auto-triggered) | ideate → `atdd-kit:issue` → discover |
| **Post-Issue** | Issue number provided (from `issue` skill) | ideate → `atdd-kit:discover` |

**Detect:** Issue number argument present → post-Issue mode. Otherwise → pre-Issue mode.

## When to Use

- Vague idea, no Issue yet (pre-Issue, auto-triggered)
- Issue just created, user wants to brainstorm (post-Issue, from `issue`)

## Principles

| # | Principle | Detail |
|---|-----------|--------|
| I1 | **No code edits** | Do not write code, create files, or modify the repository |
| I2 | **No Issue creation** (pre-Issue) | In pre-Issue mode, this skill explores; Issue creation is the next step |
| I3 | **One question at a time** | Do not bundle multiple questions |
| I4 | **Always compare approaches** | Present 2-3 options with Pros/Cons before converging (unless skipped) |

---

## Post-Issue Mode

### Step 0: Offer Skip

AskUserQuestion — header: "Brainstorm?", options: "(Recommended) Skip to discover — requirements are clear", "Yes, brainstorm first"

Recommended: Skip to discover — reply 'ok' to accept, or provide alternative

- Skip: chain to `atdd-kit:discover` (go to Step 4)
- Brainstorm: continue to Step 1

### Step 1: Understand the Idea

Ask one question at a time: Goal (what problem?), Context (what exists today?), Constraints?

### Step 2: Explore Approaches

Present 2-3 approaches with Summary, Pros, Cons, Impact, Risks.

AskUserQuestion — header: "Approach?", options: "(Recommended) [approach] — [reason]", "[alternative]", "Suggest alternative"

Recommended: [recommended approach] — reply 'ok' to accept, or provide alternative

### Step 3: Summarize Decision

Present concise summary (Goal, Chosen approach, Key tradeoffs, Scope).

AskUserQuestion — header: "Proceed?", options: "(Recommended) Yes, proceed to requirements", "Not yet, revise"

### Step 4: Transition to discover

Post Context Block as Issue comment:

```markdown
## Context Block

| Field | Value |
|-------|-------|
| task_type | [derived from design decision] |
| requirements | [goal and chosen approach summary] |
| environment | [any constraints identified] |
| collected_info | [design decision, tradeoffs, scope] |
```

Show "Design exploration complete." and invoke `atdd-kit:discover` via the Skill tool.

---

## Pre-Issue Mode

### Step 1: Understand the Idea (same as post-Issue Step 1)

### Step 2: Explore Approaches (same as post-Issue Step 2)

### Step 3: Summarize Decision

AskUserQuestion — header: "Create Issue?", options: "(Recommended) Yes, create Issue", "Not yet, revise"

### Step 4: Transition to issue

Show "Design exploration complete." and invoke `atdd-kit:issue` via the Skill tool. Post Context Block as Issue comment after creation.

---

## Prohibition Checklist

- [ ] Not editing code or files
- [ ] Not creating Issues directly (pre-Issue chains to `issue`)
- [ ] Not skipping approach comparison (unless user chooses Skip in post-Issue)
- [ ] Asking one question at a time
