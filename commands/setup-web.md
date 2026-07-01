---
description: "Manually set up the Web addon for this project."
---

# setup-web — Web Addon Setup

Reads `addons/web/addon.yml` from the plugin and applies all Web-specific configuration to the current project.

## Steps

### Step 1: Read Addon Manifest

Read `${CLAUDE_PLUGIN_ROOT}/addons/web/addon.yml`.

### Step 2: Deploy Scripts and Config

Copy addon files to the project:

| Source (plugin) | Destination (project) |
|-----------------|----------------------|
| `scripts/impact_map.sh` | `scripts/impact_map.sh` |
| `addons/web/config/impact_rules.yml` | `config/impact_rules.yml` |

Ensure destination directories exist before copying.

**Re-run protection (existing customized config):** Before copying `config/impact_rules.yml`,
check whether the destination file **already exists**. If it does, this is a re-run of
`setup-web` on a project that has already customized its rules — **do not silently
overwrite** it. Print an overwrite warning and **skip** (preserve) the existing file,
recommending the user diff the template manually if they want to pick up new defaults.
`scripts/impact_map.sh` itself is safe to always overwrite (it is not meant to be edited
per-project).

### Step 3: Customize impact_rules.yml

Open `config/impact_rules.yml` and adjust the path rules to match your project's directory structure:

- `src/**` — application source
- `components/**` — UI components
- `pages/**` — page components
- `tests/**` / `__tests__/**` — test files
- `public/**` — static assets

Customize the `skill-e2e` test identifiers to match your test suite names (e.g., jest group names, vitest describe blocks, or playwright project names).

### Step 4: Display Guidance

Print addon guidance from `addon.yml` (impact-based test runner setup).

**FALLBACK detection:** `scripts/impact_map.sh` conservatively falls back to running the
FULL test suite (not narrowing to impact scope) whenever a changed file matches no rule in
`config/impact_rules.yml`, and it announces this on **stderr** with a line beginning
`FALLBACK:`. If your impact-scoped runs are unexpectedly slow (always the full suite),
your rules are likely stale relative to the project layout. To detect this:

1. **Keep stderr** when invoking `impact_map.sh` (do not redirect it to `/dev/null`) so the
   `FALLBACK:` diagnostic is visible.
2. Check for it explicitly with `grep FALLBACK` against the captured stderr — e.g.
   `impact_map.sh ... 2>&1 1>/dev/null | grep FALLBACK`.
3. In CI, add a step that fails the build when a run is *always* on FALLBACK (i.e. every
   impact-scoped invocation triggers the full suite) — this is a strong signal that
   `config/impact_rules.yml` no longer matches the project's directory structure and needs
   updating, rather than silently paying the full-suite cost on every inner-loop run.

### Step 5: Summary

```
Web addon setup complete:
- Scripts: 1 deployed (scripts/impact_map.sh)
- Config: 1 deployed (config/impact_rules.yml)

Next: customize config/impact_rules.yml to match your project structure.
Run impact-scoped tests: scripts/impact_map.sh --platform web --config config/impact_rules.yml --base <ref> --layer skill-e2e
```
