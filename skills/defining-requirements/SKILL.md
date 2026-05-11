---
name: defining-requirements
description: "Use when starting a new Issue to explore the problem space, define the PRD, and produce a structured requirements document."
---

# Defining Requirements

Step 1+2 of the atdd-kit v1.0 flow. Translate an Issue into a structured PRD stored at `docs/issues/<NNN>/prd.md` using the template at `templates/docs/issues/prd.md`.

This skill is intentionally thin: it shepherds the author through the 6 PRD sections (Problem / Why now / Outcome / What / Non-Goals / Open Questions) one question at a time, then writes the artifact and posts an Issue comment summary.

## Auto-trigger

- Explicit invocation: `/atdd-kit:defining-requirements <issue-number>`
- Session-start recommendation when an Issue has `type:development`, `type:bug`, `type:research`, or `type:documentation` and no PRD artifact exists yet.

## Prerequisites

- Issue exists and is open
- `in-progress` label is held by this session (acquire on Step 0)
- `docs/issues/<NNN>/` directory may or may not exist (created on Step 8)
- v1.0 (#216 / #218): no persona machinery — User Stories use **persona-less Connextra** `I want to <goal>, so that <reason>`

## Core Principles

| # | Principle | Detail |
|---|-----------|--------|
| D1 | One question at a time | Never bundle PRD sections in a single prompt |
| D2 | Recommended default | Each step offers an explicit `Recommended:` answer; user can accept or replace |
| D3 | No code edits during this step | Only PRD artifact and Issue comment writes are allowed |
| D4 | Section-by-section approval | Each of the 6 sections is confirmed before moving on |
| D5 | Spec template authority | The artifact must follow `templates/docs/issues/prd.md` section order verbatim |

## Core Flow

### Step 0: Lock and read context

```bash
gh issue edit <NNN> --add-label "in-progress"
gh issue view <NNN> --json title,body,labels
```

If `in-progress` is already set by another session, report and exit. Read the Issue title and body as the seed for Step 1.

### Step 1: Problem

Ask the user: "What is the concrete pain or blocker this Issue addresses? Separate the current state from the consequence."

Capture two sub-points: (a) current state, (b) consequence.

### Step 2: Why now

Ask: "Why does this need to happen now? Deadlines, external triggers, or opportunity cost?"

If the Issue body already states timing, propose it as the `Recommended:` answer.

### Step 3: Outcome

Ask: "What state is reached when this is done? List measurable indicators if any."

Push back on vague language ("works correctly", "is fast") — request a concrete check that an external reader could perform.

### Step 4: What

Ask: "What is in scope? List the features or changes as bullets."

Bullet list, one item per line. Push back if items mix concerns or describe implementation instead of scope.

### Step 5: Non-Goals

Ask: "What is intentionally out of scope, and why? List each excluded item with a one-line rationale."

If the user cannot name at least one Non-Goal, explain that explicit exclusions reduce review ambiguity and try once more.

### Step 6: Open Questions

Ask: "Are there unresolved design decisions? List each with a placeholder answer if known."

Empty list is acceptable if the user explicitly states "none remain."

### Step 7: Approval gate

Present the 6 sections in a single combined view and ask:

> "Approve this PRD? Reply `ok` to write the artifact, or specify which section to revise."

If revisions are requested, loop back to the specific step. Do not advance to Step 8 without explicit `ok`.

### Step 8: Write artifact and post Issue comment

```bash
mkdir -p "docs/issues/<NNN>"
cp templates/docs/issues/prd.md "docs/issues/<NNN>/prd.md"
# then edit the file in place, filling each section
```

After writing the file, post an Issue comment with the same content (so the deliverable is visible without checking out the branch). Comment header: `## defining-requirements deliverables`.

## Output

| Artifact | Path |
|----------|------|
| PRD file | `docs/issues/<NNN>/prd.md` |
| Issue comment | `## defining-requirements deliverables` |

## User Story Note

User Story derivation is **out of scope for this skill** — it is owned by `extracting-user-stories` (Step 3). However, if the user volunteers a story during dialogue, capture it in `## Notes` of the PRD using **persona-less Connextra** (`I want to <goal>, so that <reason>`). Do **not** add the legacy persona prefix — persona was dropped in v1.0 (#216 / #218).

## Mandatory Checklist

Before emitting `SKILL_STATUS: COMPLETE`:

- [ ] `in-progress` label acquired in Step 0
- [ ] All 6 PRD sections filled (Problem / Why now / Outcome / What / Non-Goals / Open Questions)
- [ ] No section contains the literal placeholder strings from `templates/docs/issues/prd.md`
- [ ] Approval `ok` recorded in Step 7
- [ ] `docs/issues/<NNN>/prd.md` exists and matches the template section order
- [ ] Issue comment posted with `## defining-requirements deliverables` header
- [ ] Legacy persona prefix is NOT introduced in the artifact (v1.0 persona-less rule)

## Integration

- **Upstream:** `session-start` — provides Issue and label state
- **Downstream:** `extracting-user-stories` — consumes `docs/issues/<NNN>/prd.md` to derive User Stories

## Status Output

Emit a `skill-status` fenced code block as the final element of the response:

```skill-status
SKILL_STATUS: COMPLETE | PENDING | BLOCKED | FAILED
PHASE: defining-requirements
RECOMMENDATION: <one-line next action>
```

Terminal points:

- **COMPLETE** — artifact written, Issue comment posted, user approved
- **PENDING** — waiting on user input for the next section
- **BLOCKED** — `in-progress` label already held by another session, or Issue missing
- **FAILED** — file write or `gh` API failure

See `docs/guides/skill-status-spec.md` for field definitions.
