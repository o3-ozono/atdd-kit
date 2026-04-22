# Testing Skills

This document describes the L4 skill test framework (`tests/claude-code/`) for atdd-kit.

## (a) Fast vs Integration Layer

Two test layers invoke `claude -p` directly to catch skill-chain drift and LLM behavior bugs.

**Fast layer** — single-turn meta questions, no fixture project, no skill chain.
- Invocation: `tests/claude-code/run-skill-tests.sh --test <name>`
- Purpose: skill content comprehension (does the skill description trigger correctly? are rule references intact?)
- LLM non-determinism: limit to deterministic questions (Yes/No, name references, counts). `assert_contains` accepts regex.
- Example: `fast-skill-description-lint.sh` verifies that `lint_skill_descriptions.sh` exits 0 and produces output.

**Integration layer** — full workflow replay with fixture project + jsonl transcript analysis.
- Invocation: `tests/claude-code/run-skill-tests.sh --integration --test <name>`
- Requires: `python3`, `claude` binary with `--permission-mode bypassPermissions`
- Purpose: catch premature-action bugs, skill-chain wiring drift, and token regression
- Example: `integration-discover-minimal.sh` invokes discover against the minimal-project fixture.

## (b) jsonl Analysis and Pricing Map Update

`tests/claude-code/analyze-token-usage.py` parses a `claude -p` jsonl transcript and outputs a per-agent cost table.

```
python3 tests/claude-code/analyze-token-usage.py <transcript.jsonl>
```

**To update pricing**: edit the `MODEL_PRICES` dict at the top of `analyze-token-usage.py`. Format:

```python
"claude-<model-id>": (input_per_1m, output_per_1m, cache_read_per_1m, cache_create_per_1m),
```

Prices are in USD per 1M tokens. Unknown models report `N/A` in cost column (exit 0).

## (c) Cost Baseline

| Layer | Typical cost per full run |
|-------|--------------------------|
| Fast  | ~$0.10 |
| Integration (full suite) | ~$5.00 |

Run the integration layer selectively during development. Fast layer can run on every commit.

## (d) Adding a New Test

**Fast test:**
1. Create `tests/claude-code/samples/fast-<name>.sh` (executable).
2. Source `tests/claude-code/test-helpers.sh`, call `run_claude`, then `assert_contains` / `assert_order` / `assert_count`.
3. Run via `tests/claude-code/run-skill-tests.sh --test <name>`.
4. Add a BATS file `tests/test_l4_<name>.bats` to verify the sample exits 0.

**Integration test:**
1. Create `tests/claude-code/samples/integration-<name>.sh` (executable).
2. Use `SKILL_TEST_CLAUDE_BIN`, `SKILL_TEST_TMPDIR`, `FIXTURE_DIR` from env.
3. Invoke `claude -p` with `--permission-mode bypassPermissions --add-dir <fixture>`.
4. Optionally run `python3 tests/claude-code/analyze-token-usage.py <transcript>` to assert cost bounds.
5. Run via `tests/claude-code/run-skill-tests.sh --integration --test <name>`.
6. Add a BATS file to verify stub mode exits 0 and real mode exits 0 under `RUN_INTEGRATION=1`.

## (e) Linter WARN to FAIL Escalation

`scripts/lint_skill_descriptions.sh` currently runs in **WARN-only mode** (always exits 0).

Escalation to FAIL mode (exit 1 on any VIOLATION) will be activated when:
- Violation count is 0 across 2 consecutive releases, **and**
- All shipped skills have been audited and confirmed trigger-only.

Track in a follow-up Issue referencing this document.

See `DEVELOPMENT.md` §Skill Description Field Rules for the authoritative detection rule.
