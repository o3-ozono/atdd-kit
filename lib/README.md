# lib/

Shell library scripts shared across skills, hooks, and the BATS test suite.

## Files

| File | Purpose |
|------|---------|
| `scenario_loader.sh` | Validate and echo a headless skill-chain scenario spec (JSON). See `docs/guides/headless-skill-testing.md`. |
| `skill_assertion.sh` | Subsequence / strict / forbidden match engine for skill-chain assertions. |
| `skill_fix_dispatch.sh` | Dispatch, inflight registry, env scrubbing, and cleanup for the `skill-fix` background subagent flow. |
| `skill_transcript_parser.sh` | Extract Skill `tool_use` events from a stream-json transcript. |
| `spec_check.sh` | Single source of truth for spec-file detection and slug derivation (US/AC spec files). |
| `autopilot_convergence.sh` | Convergence safety rails for autopilot (`autopilot`, #246): normalized-fingerprint sameness-detector and stuck detection using **same-step FAIL rows only** (PASS rows are never part of the comparison population — #277), max-iterations, and the JSONL audit log. A corruption guard (#248) refuses (non-zero → halt) when a FAIL row's fingerprint was partial-written / corrupted, instead of silently dropping it (fail-OPEN). Pure bash + coreutils. |
| `lease-store.sh` | Generic capacity-1/key cross-session lease for `full-autopilot` (#318): `issue` pool (one claim per Issue) and `merge` pool (`main-merge`, serializes integration). Acquire is **atomic (`mkdir` lock) + fail-closed** — if the holder cannot be persisted the lock is released and acquire fails, never reporting a non-persisted lease as held. TTL orphan cleanup uses the holder.json timestamp, falling back to the lock-dir mtime so a freshly-created lock is not mis-reclaimed mid-race. Pure bash + coreutils. |
| `merge-coordinator.sh` | merge coordinator failure state machine for `full-autopilot` (#318): records a failure and decides retry vs escalate at threshold N (auto-retry → human escalation), plus a `process` orchestration `rebase → re-gate → merge → regression` whose external steps are env-injectable (`MC_REBASE_CMD` / `MC_REGATE_CMD` / `MC_MERGE_CMD` / `MC_REGRESSION_CMD`). post-merge regression failure surfaces as `merged:regression-failed` (non-zero), never swallowed. Pure bash + coreutils. |
| `full-autopilot-dispatch.sh` | dispatcher select/release for `full-autopilot` (#318): given K slots and a queue of candidate Issues, `select` returns up to K for which an `issue` lease can be acquired (skipping Issues claimed elsewhere); `release` frees an issue-lease when a worker completes. Composes `lease-store.sh`. The parallel-exclusion / 数珠つなぎ core. |
| `full-autopilot-run.sh` | `full-autopilot` dispatcher runtime (#318): the queue-drain loop — get `ready-to-go` → select (issue-lease) → launch headless worker → monitor (bash-3.2-portable `kill -0` poll, no `wait -n`) → merge-ready ⇒ merge coordinator under merge-lease → release issue-lease → refill slots until the queue is empty. All external steps (queue / launch / result / merge / notify) are env-injectable for deterministic testing (`FA_QUEUE_CMD` / `FA_LAUNCH_CMD` / `FA_RESULT_CMD` / `FA_MERGE_CMD` / `FA_NOTIFY_CMD`); the default launcher runs `FA_HANDOFF=1 claude -p "/atdd-kit:autopilot <i> --hand-off"`. Fires `FA_NOTIFY_CMD <event> <issue> <detail>` on dispatch / merge-ready / merged / merge-failed / worker-failed / escalate. Live-validated with real `claude -p` workers. |

## Usage

Each script prints its own usage when run without arguments, e.g.:

```bash
bash lib/spec_check.sh derive_slug <issue-number>
bash lib/skill_fix_dispatch.sh query_inflight [<skill> <phase>]
```
