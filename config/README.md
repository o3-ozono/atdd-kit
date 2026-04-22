# Config

Central configuration files for atdd-kit tooling. All files use formats parseable by pure bash (no external tools required).

## Files

| File | Purpose |
|------|---------|
| [impact_rules.yml](impact_rules.yml) | Path glob → L4/BATS test mapping for `scripts/impact_map.sh` |

## impact_rules.yml Schema

```yaml
rules:
  - path: <glob>        # bash fnmatch pattern (e.g. skills/**)
    l4: <names>         # space-separated L4 test names
    bats: "@covers <token>"  # token to look for in @covers declarations
```

Constraints:
- Indentation: 2 spaces (no tabs)
- `l4:` and `bats:` values are plain scalars (space-separated, no YAML array syntax)
- Comments (`#`) and blank lines are ignored
- The `rules:` top-level key is required; at least one entry is required

For schema extensions (e.g. `timeout`, `tags`), open a new Issue rather than modifying the parser inline.

## References

- [scripts/impact_map.sh](../scripts/impact_map.sh) — consumer of these rules
- [docs/guides/testing-skills.md](../docs/guides/testing-skills.md) — `@covers` format definition and usage
