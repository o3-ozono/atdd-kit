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

1. **Match:** Message contains Issue reference (`#N` or `Issue N`) **AND** a work-start verb ("go ahead", "implement", "fix", "resume", "handle", "do it", "get started", "work on", "start", "continue").
2. **Matched:** Do NOT invoke discover, plan, or any skill. Guide to autopilot:
   ```
   Use `/atdd-kit:autopilot <number>` to work on this Issue.
   ```
3. **Not matched** (e.g., "What is Issue #16 about?"): Proceed to Governance Rules.

## Governance Rules

### Iron Law #1: No Code Without an Issue

If the user requests code edits with no associated Issue:

1. Do NOT edit code. Do not propose changes.
2. Guide to Issue creation: suggest creating an Issue or invoke issue/bug/discover.
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
