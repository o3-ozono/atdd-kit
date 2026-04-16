---
name: issue
description: "Auto-triggers when users request new features, improvements, or tasks. Fires on phrases like 'I want...', 'add...', 'implement...', 'create an Issue', etc. Selects template -> creates Issue -> chains to ideate."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# Generic Issue Creation Pipeline

## Step 1: Auto-detect Task Type

Auto-detect the task type. Do NOT ask the user to confirm — proceed directly to Step 2.

- `development` — New features, improvements, enhancements (default fallback)
- `bug` — Bug reports, errors, crashes → redirect immediately to `/atdd-kit:bug`
- `research` — Research, exploration, analysis
- `documentation` — Documentation improvements, additions
- `development` + refactoring — Code cleanup, restructuring

If ambiguous, default to `development`.

## Step 2: Gather Details

Display at the start:

```
Task type: [detected type]
```

User may correct the type at any point. Ask about each required template field, one at a time.

## Priority Guidelines

| Priority | Criteria | Examples |
|----------|----------|---------|
| **P1** | Production outage, critical blocker, data loss | App crash, data corruption |
| **P2** | Feature development, important improvements | New screen, UX improvement |
| **P3** | Refactoring, documentation, research, minor improvements | Code cleanup, tech research |

Confirm priority with AskUserQuestion:
- header: "Priority?"
- options:
  1. "(Recommended) [inferred priority] — [brief reason]"
  2. "[next most likely priority]"
  3. "[remaining priority]"
- multiSelect: false

Recommended: [inferred priority] — reply 'ok' to accept, or provide alternative

## Step 3: Create Issue

- `gh issue create`
- Template: `${CLAUDE_PLUGIN_ROOT}/templates/issue/en/<type>.yml` (-ja.yml variants are human-only; do not use)
- Add `type:` label
- Do NOT add `in-progress` label (added when work starts, e.g. discover)

## Step 3.5: Post Context Block

Post as Issue comment:

```markdown
## Context Block

| Field | Value |
|-------|-------|
| task_type | [development / research / documentation / refactoring] |
| requirements | [user's original request, summarized] |
| environment | [any environment details mentioned] |
| collected_info | [any additional context gathered during intake] |
```

## Step 4: Chain to ideate

"Issue #XX created. Running `atdd-kit:ideate` for design exploration before requirements."
-> Invoke ideate, passing the Issue number (post-Issue mode)
