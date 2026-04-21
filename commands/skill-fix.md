---
description: "Explicit entry point for the skill-fix flow. Invokes skill-fix skill directly, bypassing the implicit trigger confirmation step."
---

# /atdd-kit:skill-fix

Explicit entry point for reporting atdd-kit skill defects during an active session without interrupting the current work.

## What it does

1. Starts the skill-fix Interview (Q1/Q2/Q3) immediately
2. Runs duplicate check in the main session
3. Dispatches a background subagent that creates a new Issue and runs `/atdd-kit:discover <n> --skill-fix`
4. Returns control to main session immediately (non-blocking)
5. Reports 1 line at the next phase boundary

## When to use

Use when you notice that an atdd-kit skill behaved unexpectedly and want to queue the fix without interrupting current work.

## Usage

```
/atdd-kit:skill-fix
```

No arguments required. The skill guides you through 3 questions.

## Implicit trigger

The skill-fix skill also triggers implicitly when your message contains both:
- A skill name: `discover / plan / atdd / verify / ship / bug / issue / session-start / autopilot`
- An intent verb: 改善 / 修正 / バグ / おかしい / 直したい / fix / improve / broken / wrong

In that case, a single confirmation question is asked before starting the interview.
