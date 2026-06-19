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

### Step 5: Summary

```
Web addon setup complete:
- Scripts: 1 deployed (scripts/impact_map.sh)
- Config: 1 deployed (config/impact_rules.yml)

Next: customize config/impact_rules.yml to match your project structure.
Run impact-scoped tests: scripts/impact_map.sh --platform web --config config/impact_rules.yml --base <ref> --layer skill-e2e
```
