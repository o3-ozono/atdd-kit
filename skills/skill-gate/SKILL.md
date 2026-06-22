---
name: skill-gate
description: "Skill enforcement gate. Auto-triggers on every user message to ensure governance rules (Issue-first, skill invocation) are enforced before direct work."
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

# Skill Gate

Enforce governance rules before any action, including clarifying questions.

## Pre-check: Issue Work Routing

1. **Express fast path (check first):** If the message is an explicit `/atdd-kit:express <N>` invocation, this is a recognized legitimate route — do NOT redirect to `defining-requirements`. Let the express skill handle it. Parallel Collision Detection still applies (see below).
2. **Match:** Message contains Issue reference (`#N` or `Issue N`) **AND** a work-start verb ("go ahead", "implement", "fix", "resume", "handle", "do it", "get started", "work on", "start", "continue").
3. **Matched:** Enter the v1.0 6-step flow at Step 1. Guide to `defining-requirements`:
   ```
   Use `/atdd-kit:defining-requirements <number>` to start the v1.0 flow for this Issue.
   ```
   The flow then chains Step 1 → 6 (defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying). Resume mid-flow by invoking the skill for the next incomplete step.
4. **Not matched** (e.g., "What is Issue #16 about?"): Proceed to Governance Rules.

## Pre-check: Route Eligibility (mandatory)

Before routing any Issue to a skill, **evaluate `docs/methodology/route-eligibility.md`** to determine the correct route (express / full-flow / bugfix). This check is mandatory — skipping it may route a behavior-change Issue to express (incorrect) or a doc-only Issue through full ATDD (unnecessarily expensive).

**Steps:**

1. Load `docs/methodology/route-eligibility.md` and evaluate Express-Eligible Signals, Full-Flow Signals, and bugfix Route Signals against the Issue title and body.
2. **If express-eligible** (doc-grade, no behavior change): recommend `/atdd-kit:express <N>` and confirm with the user before proceeding. Do NOT auto-route.
3. **If full-flow / bugfix signals present** (behavior change, code change, CI, etc.): route to the appropriate flow (6-step flow or `/atdd-kit:bugfix`). A message that invokes a non-eligible route (e.g., express for a behavior-change Issue) is **non-compliant** — surface the mismatch and ask the user to confirm or override.
4. **Override:** The user may always override the route recommendation explicitly (e.g., "use express anyway"). Announce the override and proceed.

**Non-compliant example (suppress):** `/atdd-kit:express` on an Issue with `type:development` label or code-change keywords — surface the mismatch ("この Issue は挙動変更を含むため express は不適切です。フル6ステップフローで進めますか？") before proceeding.

## Pre-check: Parallel Collision Detection

Before starting work on Issue `#N` (a matched work-start above), check that no other worktree is already working the same Issue:

```
scripts/check-issue-collision.sh --issue <N>
```

- **Exit 0:** safe — proceed into the v1.0 flow.
- **Exit 1 (collision):** another worktree is already writing `docs/issues/<N>/`. STOP. Surface the emitted guidance (`Issue #N is already in-progress in worktree X`) and do not start a second parallel session on the same Issue — finish/hand off the other worktree or pick a different Issue.

Different Issues run in parallel freely; the check only blocks two worktrees on the **same** Issue.

This check is **best-effort and advisory**: it is a point-in-time scan and cannot prevent a true simultaneous-start race (TOCTOU). A clean (exit 0) result means "no collision seen right now", not a hard guarantee — when two sessions start the same Issue at the same instant, both may pass.

## Governance Rules

### Iron Law #1: No Code Without an Issue

If the user requests code edits with no associated Issue:

1. Do NOT edit code. Do not propose changes.
2. Guide to Issue creation: suggest creating an Issue (invoke `bug` for a bug report), then enter the v1.0 flow via `defining-requirements`.
3. No exceptions for "quick fixes", "one-liners", or "obvious changes."

### The 1% Rule

If there is even a 1% chance a skill applies, invoke it. Non-negotiable.

### Announcement Obligation

Announce every skill before invoking:

> Using [skill-name] for [purpose].

## Red Flags

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check skills. |
| "I need more context first" | Skill check comes BEFORE exploration. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. |
| "This doesn't need a formal skill" | If a skill exists, use it. The 1% rule applies. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This is too simple for a skill" | Simple tasks break. Skills take seconds. No exceptions. |
| "I remember what this skill does" | Skills evolve. Always invoke, never recall. |
| "Let me gather information first" | Skills tell you HOW to gather information. Invoke first. |
| "The user didn't ask for a skill" | Skill invocation is your job. The 1% rule decides. |
| "It's just a quick fix, no Issue needed" | Iron Law #1: No code without an Issue. |
| "I'll create the Issue after the fix" | Issue comes BEFORE code. Not after. Not during. Before. |
| "This is too trivial for an Issue" | Trivial changes break. Issues take 30 seconds. No exceptions. |
