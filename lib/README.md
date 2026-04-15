# lib/

Shell library scripts shared across autopilot and hooks.

## Files

| File | Purpose |
|------|---------|
| `circuit_breaker.sh` | Three-state circuit breaker for autopilot infinite-loop prevention. States: CLOSED → HALF\_OPEN → OPEN. Persists state to `.claude/cb-state.json` (cwd-relative, worktree-scoped). |

## Usage

```bash
# Check if autopilot should halt (exits non-zero when OPEN)
bash lib/circuit_breaker.sh check

# Record events
bash lib/circuit_breaker.sh record_progress       # skill completed successfully
bash lib/circuit_breaker.sh record_no_progress    # iteration made no progress
bash lib/circuit_breaker.sh record_error <fp>     # repeated error fingerprint

# Manual reset after resolving root cause
bash lib/circuit_breaker.sh reset
```

See `docs/guides/circuit-breaker.md` for full specification.
