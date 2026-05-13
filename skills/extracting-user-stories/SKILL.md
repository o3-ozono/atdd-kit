---
name: extracting-user-stories
description: "Use when requirements are defined and you need to derive User Stories (Connextra format) from the PRD."
---

# Extracting User Stories

Step 2 of the atdd-kit v1.0 flow. Take an Issue number, read its PRD, present Story candidates in **one batch**, and after the author's approval write `docs/issues/<NNN>/user-stories.md` based on `templates/docs/issues/user-stories.md`.

**Scope ends at the User Stories file.** Plan + Acceptance Tests are owned by `writing-plan-and-tests` (Step 3, #190). This skill does not produce plans or AT.

## Trigger

- **Explicit:** `/atdd-kit:extracting-user-stories <issue-number>`
- **Keyword-detected (confirm before invoking):** When user messages mention User Story intent (e.g. "User Stories", "ユーザーストーリー", "Story 抽出"), ask `Run extracting-user-stories skill on <issue>? Y/n` before starting. Auto-invocation without confirmation is forbidden by the v1.0 Step B progression rule (#179).

## Input

- Issue number (command-line argument or recognized in a user message)
- PRD file at `docs/issues/<NNN>/prd.md` read directly. If missing, instruct the user to run `defining-requirements` first and stop.

No other inputs. No Context Block. No resume of existing `docs/issues/<NNN>/user-stories.md`.

## Output

| Artifact | Path |
|----------|------|
| User Stories file | `docs/issues/<NNN>/user-stories.md` (copied from `templates/docs/issues/user-stories.md`, filled in) |

**Output language: Japanese (fixed).** Connextra phrases `I want to ... so that ...` are kept verbatim for structural recognition; body content (goal / reason) is written in Japanese.

No Issue comment, no `skill-status` fenced block.

## Flow

1. Read the PRD at `docs/issues/<NNN>/prd.md`.
2. **Extract Story candidates** — primarily from PRD `## What`, with `## Outcome` and `## Problem` as supplementary sources for Constraint Stories. Categorize each candidate into:
   - **Functional Story** (persona-less Connextra): `I want to <goal>, so that <reason>`.
   - **Constraint Story** (Pichler 2013): NFR expressed in Story form, no persona field.
3. **Batch presentation.** Render all candidates in **one message** under `## Functional Story` and `## Constraint Story` headings, then ask:
   > `Approve User Stories? Reply 'ok' to write, or name a story to revise / add / drop.`
   Revisions update the affected story and re-present in one message. Do not proceed without explicit `ok`. Do not enter a 1-story-at-a-time loop.
4. **Write artifact.** `cp templates/docs/issues/user-stories.md docs/issues/<NNN>/user-stories.md`, then fill in each story in place.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| PRD → User Stories | **extracting-user-stories** (this skill) |
| Issue → PRD | defining-requirements (Step 1, #188) |
| Plan + Acceptance Tests | writing-plan-and-tests (Step 3, #190) |
| ATDD double-loop implementation | running-atdd-cycle (Step 4, #191) |
| PRD / US / Plan / Code / AT review | reviewing-deliverables (Step 5, #192) |
| Parallel-session conflict, `in-progress` label management | skill-gate (#197) |

This skill **does not** spawn reviewer subagents — US review happens at Step 5. This skill **does not** add or remove the `in-progress` label — that is skill-gate's responsibility.

This skill **does not** include persona fields (`As a [persona]`), INVEST checking, Story Splitting, or Example Mapping — all unadopted in v1.0 (#216 / #218).

## Integration

- **Upstream:** `defining-requirements` (consumes its `docs/issues/<NNN>/prd.md`)
- **Downstream:** `writing-plan-and-tests` (consumes `docs/issues/<NNN>/user-stories.md`)
