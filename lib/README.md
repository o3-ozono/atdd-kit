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

## Usage

Each script prints its own usage when run without arguments, e.g.:

```bash
bash lib/spec_check.sh derive_slug <issue-number>
bash lib/skill_fix_dispatch.sh query_inflight [<skill> <phase>]
```
