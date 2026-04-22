# Testing Skills — Impact Scope Detection

`scripts/impact_map.sh` maps a git diff to the set of affected tests, so L4 integration runs and BATS suites only exercise changed surface area.

## Usage

```bash
# diff-based: only tests affected by changes since origin/main
./scripts/impact_map.sh --base origin/main --layer BATS

# diff-based with specific ref
./scripts/impact_map.sh --base HEAD~1 --layer L4

# forced full scan (skips diff analysis)
./scripts/impact_map.sh --all --layer BATS
./scripts/impact_map.sh --all --layer L4

# explicit config path (default: $PWD/config/impact_rules.yml)
./scripts/impact_map.sh --base origin/main --layer BATS --config path/to/rules.yml
```

Output: one test per line, sorted, deduplicated. Exit 0 on success.

## Resolution Strategy

Tests are selected by two complementary methods, then union + deduped:

1. **Path rules** (`config/impact_rules.yml`): central mapping from file path globs to test names
2. **`@covers` metadata**: each test file declares which source files it covers

When any changed file matches neither method, the script falls back to full scan for that layer and logs the unmatched files to stderr.

## Supported Layers

| Layer | Output |
|-------|--------|
| `L4` | L4 integration test names (from `l4:` values in `config/impact_rules.yml`) |
| `BATS` | `.bats` file paths under `tests/` |

## `@covers` Declaration Format

Add `@covers` lines within the **first 5 lines** of a `.bats` file:

```bash
#!/usr/bin/env bats
# @covers: lib/spec_check.sh
# @covers: lib/**
```

### Supported Glob Forms (bash fnmatch subset)

| Form | Example | Matches |
|------|---------|---------|
| Exact path | `lib/spec_check.sh` | Only that file |
| Prefix glob | `lib/**` | Any file starting with `lib/` |
| Simple glob | `scripts/*` | Any file directly under `scripts/` |

`**` is treated as equivalent to `*` in bash fnmatch (non-globstar). Patterns like `lib/**.sh` (recursive + extension) are **not supported** — use `lib/**` instead.

### Deduplication

Multiple `@covers` lines pointing to the same file produce a single output entry. The same applies when both path rules and `@covers` match the same test.

## Fallback Behavior

If any changed file is unmatched (no path rule hit, no `@covers` hit):

- stdout: full set for the requested layer (same as `--all --layer <X>`)
- stderr: `FALLBACK: unmatched files:` followed by the unmatched paths

Files that always trigger fallback regardless of content:
- `config/impact_rules.yml` itself (self-change → intentionally conservative)

## Performance Target

Typical diffs (< a few hundred files) complete in sub-second time. No time assertions in BATS tests (flaky avoidance). Implementation is `O(diff_files × rules + bats_files)`.

## Adding `@covers` to Existing Tests

Place `@covers` lines in the **first 5 lines** of each `.bats` file. One declaration per covered glob is sufficient.

Bulk annotation of existing BATS files is tracked in #136 and #137.

## References

- [config/impact_rules.yml](../../config/impact_rules.yml) — central path rules
- [scripts/impact_map.sh](../../scripts/impact_map.sh) — implementation
- [config/README.md](../../config/README.md) — YAML schema reference
