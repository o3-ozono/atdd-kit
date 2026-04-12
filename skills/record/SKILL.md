---
name: record
description: "Generate a Decision Record after ship completes. Automatically chained from ship — not invoked directly."
---

# record Skill -- Decision Record Generation

Generates a permanent Decision Record in `docs/decisions/` after an Issue is shipped.
This skill is automatically chained from `ship` after merge — it is not invoked directly by the user.

## Purpose

Issue comments and LLM conversations contain valuable design context — problem background, approach exploration, rejected alternatives, and decision rationale — that does not survive in the codebase. This skill extracts that context and writes it to a searchable markdown file.

## What to Record

| Include | Exclude |
|---------|---------|
| Problem background and motivation | Code snippets and diffs |
| Considered approaches and trade-offs | Implementation details (in commit history) |
| Rejected alternatives and reasons | Test code or test output |
| User Story | CI/CD logs |
| Acceptance Criteria | Review comments on code style |
| Implementation plan and test plan (strategy level) | |
| Mid-course direction changes and reasons | |

**Rule: Do not include implementation details.** The Decision Record captures *why* decisions were made, not *how* they were implemented. Code-level details are already in the commit history.

---

## Flow

### Step 1: Gather Information

Read the Issue and PR to collect all decision context:

1. **Issue comments:** `gh issue view <number> --json title,body,comments`
   - Extract: discover deliverables (Approach, Discussion Summary, User Story, ACs)
   - Extract: plan deliverables (Test Strategy, Implementation Strategy, Discussion Summary)
   - Extract: any mid-course correction comments
2. **PR body:** `gh pr list --search "<number>" --state merged --json number,title,body,mergedAt`
   - Extract: Goal, Background, Design Decisions table
3. **Issue title and number:** For the record header

### Step 2: Determine File Name

Generate the file name using this convention:

```
docs/decisions/YYYY-MM-DD-<slugified-topic>.md
```

- **Date:** Use the PR merge date (from `mergedAt` field)
- **Slug:** Derive from the Issue title:
  1. Remove the type prefix (e.g., `feat:`, `fix:`, `bug:`)
  2. Convert to lowercase
  3. Replace spaces and special characters with hyphens
  4. Remove consecutive hyphens
  5. Trim to 50 characters max

**Examples:**
- Issue: "feat: Issue 完了時に Decision Record を自動生成する" → `2026-04-12-issue-decision-record-auto-generation.md`
- Issue: "bug: discover の autopilot モード検出" → `2026-04-12-discover-autopilot-mode-detection.md`

### Step 3: Generate Decision Record

Write the Decision Record with this structure:

```markdown
# [Issue title]

| Field | Value |
|-------|-------|
| Issue | #[number] |
| PR | #[pr-number] |
| Date | [merge date] |
| Status | Completed |

## Background

[Problem description and motivation from Issue body and discover deliverables.
Why was this change needed? What problem was the user trying to solve?]

## Discussion Summary

[From discover and plan Discussion Summary sections.
List all considered approaches with their trade-offs and the final selection rationale.]

| Approach | Summary | Verdict |
|----------|---------|---------|
| [approach] | [summary] | [selected/rejected + reason] |

> If no `### Discussion Summary` section exists in any Issue comment, write:
> "No discussion summary recorded. See Issue #N for context."
> Do not fail or skip the record — continue with other sections.

## User Story

[From discover deliverables]

**As a** [persona], **I want to** [goal], **so that** [reason].

## Acceptance Criteria

[From discover deliverables — copy the AC list]

## Implementation Plan

[From plan deliverables — test strategy and implementation strategy at the strategy level.
Omit code-level details.]

## Changes

[Mid-course direction changes that occurred during implementation.
For each change: what was changed and why.
Look for Issue comments that describe scope changes, approach pivots, or AC modifications.]

If no mid-course changes occurred, write: "No mid-course changes."
```

### Step 4: Write and Commit

1. Create the `docs/decisions/` directory if it does not exist
2. Write the Decision Record file
3. Commit: `docs: add decision record for #<number>`
4. Push to main: `git push`

### Step 5: Report

```
Decision Record generated:
- File: docs/decisions/[filename]
- Issue: #[number]
- PR: #[pr-number]
```

---

## Fallback Behavior

The record skill must handle incomplete information gracefully:

| Missing Information | Fallback |
|---------------------|----------|
| Discussion Summary not found in any comment | Write "No discussion summary recorded. See Issue #N for context." |
| Plan deliverables not found | Write "No implementation plan recorded." |
| PR body missing Design Decisions | Omit the field from the metadata table |
| Mid-course changes not found | Write "No mid-course changes." |
| Any other section missing | Write a brief note indicating the section was not available, and continue |

**Never fail or abort due to missing information.** Generate the best possible record from whatever is available.

---

## Constraints

- **No code edits** other than the Decision Record file itself
- **No interactive prompts** — this skill runs fully automatically
- **Pure markdown output** — no external dependencies (zero dependencies principle)
- **Idempotent** — if run again for the same Issue, overwrite the existing file
