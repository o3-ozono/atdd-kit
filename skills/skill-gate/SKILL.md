---
name: skill-gate
description: "Skill enforcement gate. Auto-triggers on every user message to ensure governance rules (Issue-first, skill invocation) are enforced before direct work."
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

# Skill Gate

Ensure governance rules are enforced before Claude begins direct work. This skill must check rules before any action, including clarifying questions.

## Pre-check: Issue Work Routing

Check if the user's message is an Issue-targeted work instruction:

1. **Match pattern:** The message contains an Issue reference (`#N` or `Issue N`) **AND** a work-start verb (e.g., "進めて", "実装して", "修正して", "再開して", "対応して", "やって", "取りかかって", "implement", "fix", "work on", "start", "resume", "continue").
2. **If matched:** Do NOT invoke discover, plan, or any other skill. Instead, guide the user to autopilot:
   ```
   Use `/atdd-kit:autopilot <number>` to work on this Issue.
   ```
3. **If NOT matched** (e.g., questions like "#16ってどういう Issue？", "#16 の状態を教えて"): Skip this section and proceed to the Governance Rules section below.

## Governance Rules

### Iron Law #1: No Code Without an Issue

If the user asks for code edits (implement, fix, modify, refactor, add, change, update code) and there is no Issue associated with the work:

1. **Do NOT edit code directly.** Do not propose code changes.
2. **Guide to Issue creation:** Suggest creating an Issue first, or invoke the appropriate skill (issue/bug/discover).
3. **No exceptions** for "quick fixes", "one-liners", or "obvious changes."

### The 1% Rule

If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill. This is not negotiable. This is not optional. You cannot rationalize your way out of this.

### Announcement Obligation

When invoking a skill, always announce it before execution:

> Using [skill-name] for [purpose].

Never invoke a skill silently. The user must know which skill is active and why.

## Red Flags

These thoughts mean STOP -- you are rationalizing skipping skills:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check skills. |
| "I need more context first" | Skill check comes BEFORE exploration. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. |
| "This doesn't need a formal skill" | If a skill exists, use it. The 1% rule applies. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This is too simple for a skill" | Simple tasks break. Skills take seconds. No exceptions. |
| "I remember what this skill does" | Skills evolve. Read the current version. Always invoke, never recall. |
| "Let me gather information first" | Skills tell you HOW to gather information. Invoke first. |
| "The user didn't ask for a skill" | Skill invocation is your job, not the user's. The 1% rule decides. |
| "It's just a quick fix, no Issue needed" | Iron Law #1: No code without an Issue. Create the Issue first. |
| "I'll create the Issue after the fix" | Issue comes BEFORE code. Not after. Not during. Before. |
| "This is too trivial for an Issue" | Trivial changes break. Issues take 30 seconds. No exceptions. |
