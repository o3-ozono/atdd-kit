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

## Usage

Each script prints its own usage when run without arguments, e.g.:

```bash
bash lib/spec_check.sh derive_slug <issue-number>
bash lib/skill_fix_dispatch.sh query_inflight [<skill> <phase>]
```
