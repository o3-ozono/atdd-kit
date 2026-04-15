# Footprint Eval

Static byte/token footprint measurement for high-frequency atdd-kit entry points.

## Purpose

Detects silent regressions in context footprint before they reach users.
Every session-start invocation loads these files — 1 KB of bloat is paid by every user on every session.

## This is NOT a behavioral eval

The `evals/footprint/` directory contains **static size measurement** checkpoints.
This is a different category from `skills/*/evals/` which contain **behavioral evals** (LLM pass_rate assertions).

| Category | Location | Measures |
|---|---|---|
| Footprint eval (this dir) | `evals/footprint/*.yml` | bytes, estimated_tokens |
| Behavioral eval | `skills/*/evals/evals.json` | LLM pass_rate against assertions |

## YAML Schema

Each checkpoint file (`<name>.yml`) declares the files to measure:

```yaml
files:
  - repo/root/relative/path.md
  - another/file.md
dynamic:                         # optional
  sub_name:
    script: scripts/foo.sh
    args:
      - arg1
      - arg2
```

- `files:` — list of repo-root-relative paths. All paths must resolve to real files.
- `dynamic:` — optional sub-checkpoints for scripts with variable output (e.g. `check-plugin-version.sh`).
  Each sub-checkpoint name becomes a key under `dynamic` in the JSON output.
- Indentation: exactly 2 spaces for top-level list items, 4 spaces for sub-keys, 6 spaces for arg items.
- No external YAML tool required — pure-bash line-by-line parsing.

## Usage

```bash
# Measure a checkpoint
scripts/measure-footprint.sh measure session-start

# Check regression vs baseline (exit 1 on regression)
scripts/measure-footprint.sh --check session-start

# Update baseline (explicit — never auto-updates)
scripts/measure-footprint.sh --update session-start

# Update all checkpoints
scripts/measure-footprint.sh --update
```

## Regression Threshold

REGRESSION fires when **either** condition is true (OR semantics):

- `current_bytes > baseline_bytes * 1.10`  (+10%)
- `current_tokens - baseline_tokens > 500`  (strictly >)

When `baseline_bytes == 0`, the percent threshold is skipped (no div-by-zero).

## Baseline Updates

- `evals/footprint/baseline.json` is the single source of truth.
- Update it in the same PR that changes a checkpoint or adds files.
- On merge conflict: re-run `scripts/measure-footprint.sh --update` and commit.

## Adding and Splitting Checkpoints

Each `.yml` file in this directory represents one **checkpoint** — a logical group of files loaded together in a single context invocation.

**Naming:** Use the entry-point name (e.g. `session-start.yml`, `autopilot.yml`).

**Split criterion:** When the number of checkpoint files reaches **5 or more**, consider reorganising them into feature-group subdirectories (e.g. `evals/footprint/core/`, `evals/footprint/commands/`). This prevents the baseline.json and YAML listing from becoming hard to scan. Each subdirectory would have its own `baseline.json`.

There is no hard rule — use judgement. The goal is to keep any single directory to fewer than ~5 checkpoints so that a diff of `baseline.json` remains readable in a PR.

## Token Heuristic

`estimated_tokens = ceil(bytes / 3.6)`

Uses `wc -c` (byte count) not character count — atdd-kit files are mostly ASCII so byte ≈ char.
This is a heuristic; tiktoken is not required.
