# Circuit Breaker Guide

The circuit breaker (`lib/circuit_breaker.sh`) prevents autopilot from entering infinite loops by tracking progress signals and repeated errors across iterations.

## State Machine

```
CLOSED ──(no_progress=1)──► CLOSED
CLOSED ──(no_progress=2)──► HALF_OPEN
HALF_OPEN ──(no_progress=3)──► OPEN  ← autopilot halts here
OPEN ──(record_progress)──► OPEN     ← sticky; manual reset required

CLOSED/HALF_OPEN ──(same fp × 5)──► OPEN  ← error threshold
Any state ──(record_progress)──► CLOSED   ← resets all counters (except OPEN)
```

## Thresholds

| Signal | Threshold | Action |
|--------|-----------|--------|
| `record_no_progress` | 3 consecutive | CLOSED → HALF_OPEN (at 2), → OPEN (at 3) |
| `record_error <fp>` | 5 consecutive same fingerprint | → OPEN |
| `record_progress` | any | Reset to CLOSED, clear all counters (sticky in OPEN) |

## State File

State is persisted to `.claude/cb-state.json` (cwd-relative). Because autopilot runs inside a worktree, each worktree has its own state file — parallel autopilot runs on different Issues do not interfere.

```json
{
  "state": "CLOSED",
  "no_progress": 0,
  "error_count": 0,
  "last_error_fingerprint": ""
}
```

## Subcommands

| Subcommand | Description | Exit code |
|-----------|-------------|-----------|
| `check` | Check current state. CLOSED/HALF\_OPEN → 0, OPEN → non-zero with stop message | 0 or 1 |
| `record_progress` | Signal successful completion. Resets to CLOSED (no-op in OPEN). | 0 |
| `record_no_progress` | Signal no progress made. Advances CLOSED→HALF\_OPEN→OPEN. | 0 |
| `record_error <fp>` | Signal repeated error. `<fp>` must match `[a-zA-Z0-9_-]+`. | 0 or 1 |
| `reset` | Manually reset to initial CLOSED state. | 0 |

## Trigger Events in Autopilot

| Autopilot Event | Signal |
|-----------------|--------|
| Agent returns `SKILL_STATUS: COMPLETE` | `record_progress` |
| Iteration ends with same label state (e.g. still `needs-plan-revision`) | `record_no_progress` |
| Reviewer/QA raises the same issue fingerprint in consecutive rounds | `record_error <fingerprint>` |

## Check Points

The circuit breaker `check` command is called at three iteration entry points in `commands/autopilot.md`:

1. **Plan Review Round** — before each iteration (initial and `needs-plan-revision` re-entry)
2. **Phase 3: Implementation** — before each iteration (initial and `needs-pr-revision` re-entry)
3. **Phase 4: PR Review** — before each iteration (initial and after Developer fixes)

If `check` exits non-zero, autopilot prints the stop message (which includes the trip reason and reset instructions) and halts.

## Fingerprint Convention

A fingerprint is a short identifier for a recurring issue. Use only `[a-zA-Z0-9_-]+` characters (1 or more).

Examples:
- `missing-tests` — Reviewer consistently flags missing test coverage
- `type-error-AC3` — same type error recurs on AC3 across iterations
- `plan-scope-creep` — plan review repeatedly rejects scope creep

## Reset Procedure

When autopilot halts with state OPEN:

1. Diagnose the root cause (read the stop message for trip reason)
2. Resolve the underlying issue
3. Reset the circuit breaker:
   ```bash
   bash lib/circuit_breaker.sh reset
   ```
4. Resume autopilot:
   ```
   /atdd-kit:autopilot <issue-number>
   ```

## Initialization

If `.claude/cb-state.json` does not exist, any subcommand auto-creates it with CLOSED defaults. If the file is present but malformed (not valid JSON), the command exits non-zero and prints the file path plus reset instructions to stderr — it does not silently overwrite.
