# tests/claude-code

L4 skill test framework — fast and integration tests that invoke `claude -p` directly.

## Directory Structure

```
tests/claude-code/
  test-helpers.sh              # AC1: fast-test harness (source in test scripts)
  run-skill-tests.sh           # AC2: fast/integration runner
  analyze-token-usage.py       # AC3: per-agent token/cost table from jsonl transcript
  samples/                     # AC5: sample test scripts
    fast-skill-description-lint.sh
    fast-intentional-fail.sh
    integration-discover-minimal.sh
    integration-intentional-fail.sh
  fixtures/                    # AC5: fixture projects for integration tests
    minimal-project/           # README.md + .claude/CLAUDE.md stub
      README.md
      .claude/CLAUDE.md
```

## Prerequisites

- `claude` CLI installed and in PATH (or `SKILL_TEST_CLAUDE_BIN` set)
- For integration layer: `python3` (not required for fast layer)
- `GH_TOKEN`: set via `.claude/settings.local.json` → `env.GH_TOKEN` for GitHub API access.
  The current runner does not enforce `GH_TOKEN` presence at startup; if unset, claude itself
  may fail with a GitHub API error mid-run. Recommended: always set `GH_TOKEN` before running
  integration tests. Future: follow-up Issue to add exit 3 enforcement in integration mode.
- Plugin dir: start claude with `--plugin-dir .` from repo root so atdd-kit skills load
- Integration tests use `--permission-mode bypassPermissions` (required to run headless)
- Fixture project is passed via `--add-dir <fixture-dir>` to make it visible to claude

## Running Tests

```bash
# Fast test (single-turn, no fixture)
tests/claude-code/run-skill-tests.sh --test skill-description-lint

# Integration test (fixture project + full workflow)
tests/claude-code/run-skill-tests.sh --integration --test discover-minimal

# With verbose output (echoes claude invocation)
tests/claude-code/run-skill-tests.sh --verbose --test skill-description-lint
```

## Env Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SKILL_TEST_CLAUDE_BIN` | PATH lookup | Override claude binary path (e.g., for stub in BATS) |
| `SKILL_TEST_TMPDIR` | `~/.claude/projects/` (dynamic) | Override transcript output directory |
| `SKILL_TEST_PYTHON3_BIN` | `python3` | Override python3 binary for presence check (testing only) |

`SKILL_TEST_*` prefix is intentionally separate from `HEADLESS_*` used by `scripts/test-skills-headless.sh`.

## GH_TOKEN Hygiene

`GH_TOKEN` is **not** written to any transcript file. In `--verbose` mode, the claude invocation
command is printed but environment variables are masked. Do not echo `GH_TOKEN` in sample scripts.

## SIGINT / SIGTERM Cleanup

When `run-skill-tests.sh` receives SIGINT or SIGTERM while a `claude -p` subprocess is running:
- The subprocess is killed (SIGTERM to process group, then SIGTERM to PID)
- Any temp transcript file created during the run is removed
- Exit code: 130 (SIGINT) or 143 (SIGTERM)

## Integration Tests in CI

Integration tests invoke real LLM endpoints and cost ~$5 per full run. Guard with `RUN_INTEGRATION=1`:

```bash
RUN_INTEGRATION=1 tests/claude-code/run-skill-tests.sh --integration --test discover-minimal
```

BATS tests under `tests/test_l4_*.bats` use a stub claude (via `SKILL_TEST_CLAUDE_BIN`) and run
in normal CI without LLM cost.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | PASS |
| 1 | Assertion FAIL |
| 3 | Infra error (missing binary, missing test, missing fixture, python3 absent in integration mode) |
| 130 | Killed by SIGINT |
| 143 | Killed by SIGTERM |
