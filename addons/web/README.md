# Web Addon

Platform addon for Web (Next.js / Nuxt / Vite / SvelteKit and similar) projects with Claude Code.

## What This Addon Provides

| Component | Description |
|-----------|-------------|
| **impact_map.sh** | Shared impact-mapping script — maps a git diff to affected test identifiers via `config/impact_rules.yml` path rules (`--platform web` adapter) |
| **config/impact_rules.yml** | Web project template mapping source paths (`src/`, `components/`, `pages/`, etc.) to `skill-e2e` test group identifiers (jest/vitest/playwright names) |

## Auto-Detection

This addon activates when the project contains any of:
- `package.json`
- `next.config.js` / `next.config.ts`
- `nuxt.config.ts`
- `vite.config.ts` / `vite.config.js`
- `svelte.config.js`

## Manual Setup

If auto-detection does not work (e.g., new project without a framework config file yet):

```
/atdd-kit:setup-web
```

## Usage

After setup, run impact-scoped tests during ATDD inner-loop iteration:

```
scripts/impact_map.sh --platform web --config config/impact_rules.yml --base <ref> --layer skill-e2e
```

At the merge gate, always run the full suite — impact scope is for inner-loop speed only.

Customize `config/impact_rules.yml` to match your project's directory structure and your
test suite's group/describe/project names. If a changed file matches no rule, `impact_map.sh`
conservatively falls back to the full suite (safe, but signals the rules need updating — see
`scripts/README.md` and `commands/setup-web.md` for FALLBACK detection guidance).

## Files Deployed to User Projects

| Source | Destination | Purpose |
|--------|-------------|---------|
| `scripts/impact_map.sh` | `scripts/impact_map.sh` | Impact-based test selection |
| `config/impact_rules.yml` | `config/impact_rules.yml` | Path → test-identifier rules (customize per project) |
