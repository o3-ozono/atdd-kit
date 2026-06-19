# /atdd-kit:flaky-fix

**Explicit entry point for the `fixing-flaky-tests` lightweight route.**

## Usage

```
/atdd-kit:flaky-fix <issue>
```

- `<issue>` — the Issue number (or URL) describing the flaky / intermittent test to determinize.

## What it does

Invokes the `fixing-flaky-tests` skill directly for the given `<issue>`, bypassing the keyword-auto-detection step and the `defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests` definition skills.

The `fixing-flaky-tests` skill chains: `bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying`, with the middle User gate specialized to **cause-agreement** (non-determinism classification + failure rate, not a design-approval). Merge always requires the User gate (AL-1 — never auto-merge).

## When to use

Use `/atdd-kit:flaky-fix` when:
- You already know the Issue is a flaky / intermittent test (not a deterministic defect), and
- You want to start the `fixing-flaky-tests` route without waiting for keyword auto-detection.

For ambiguous or low-confidence cases, let route-eligibility.md determination (via `autopilot` or `session-start`) propose the route and confirm with the #305 one-tap UI.

## Route determination

The canonical signal logic (label `type:flaky`, keywords, low-confidence fallback) lives in `docs/methodology/route-eligibility.md` (SoT). This command is the explicit invocation path that bypasses that detection and goes directly to `fixing-flaky-tests`.
