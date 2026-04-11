---
name: issue
description: "Auto-triggers when users request new features, improvements, or tasks. Fires on phrases like 'I want...', 'add...', 'implement...', 'create an Issue', etc. Selects template -> creates Issue -> chains to ideate."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.
This ensures duplicate Issues are caught, related PR states are known, and branch status is clear.

# Generic Issue Creation Pipeline

Takes a user request and creates an Issue with the appropriate template.

### Default Recommendation Pattern

At every decision point in issue, present a recommended default based on context analysis. The user can accept with "ok" or provide an alternative.

Format: `Recommended: [X] — reply 'ok' to accept, or provide alternative`

This applies to: priority assignment and other decision points. Task type is auto-detected (see Step 1).

## Step 1: Auto-detect Task Type

Analyze the user's request and auto-detect the task type. **Do NOT ask the user to confirm the type — proceed directly to Step 2.** Never present a type selection menu or ask "is this correct?".

Available types:
- `development` — New features, improvements, enhancements (default fallback)
- `bug` — Bug reports, errors, crashes → **redirect immediately to `/atdd-kit:bug`** (do not proceed to Step 2)
- `investigation` — Research, exploration, analysis
- `documentation` — Documentation improvements, additions
- `development` + refactoring — Code cleanup, restructuring

If the type is ambiguous, default to `development`.

## Step 2: Gather Details

At the very start of Step 2, display the auto-detected task type in exactly this format:

```
Task type: [detected type]
```

If the user wants to correct the type, they can state the correct type at any point during Step 2.

Based on the detected type, ask about each required template field, one question at a time.

## Priority Guidelines

| Priority | Criteria | Examples |
|----------|----------|---------|
| **P1** | Production outage, critical blocker, data loss | App crash, data corruption |
| **P2** | Feature development, important improvements, non-critical | New screen, UX improvement |
| **P3** | Refactoring, documentation, investigation, minor improvements | Code cleanup, tech research |

## Step 3: Create Issue

- Register with `gh issue create`
- Template: follow `${CLAUDE_PLUGIN_ROOT}/templates/issue/en/<type>.yml` format
- Add `type:` label
- Do NOT add `in-progress` label (it is added when work actually starts, e.g. discover)

## Step 3.5: Post Context Block

After creating the Issue, post a Context Block as an Issue comment to pass collected information to discover:

```markdown
## Context Block

| Field | Value |
|-------|-------|
| task_type | [development / investigation / documentation / refactoring] |
| requirements | [user's original request, summarized] |
| environment | [any environment details mentioned] |
| collected_info | [any additional context gathered during intake] |
```

This enables discover to skip redundant questions already answered during Issue creation.

## Step 4: Chain to ideate

"Issue #XX created. Running `atdd-kit:ideate` for design exploration before requirements."
-> Invoke the ideate skill, passing the Issue number so ideate runs in post-Issue mode
