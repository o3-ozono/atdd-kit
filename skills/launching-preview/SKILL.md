---
name: launching-preview
description: "Use when you need to spin up a local preview environment for the current branch during development or review."
---

# Launching Preview

On-demand skill (not part of the 6-step chain). Spin up a **local** preview of the current branch so a human can exercise the running app during development or review. Preview is **local only** — no global URL is ever provisioned (#179 PRD Non-Goal).

**Scope is launch + report.** This skill starts the preview and tells the user how to reach it. It does not write code, run Acceptance Tests, or merge anything — those belong to the flow skills.

## Trigger

- **Explicit:** `claude skill atdd-kit:launching-preview [--port <n>] [--no-open]`
- **Keyword-detected (confirm before invoking):** When a user message asks to "preview", "プレビュー", "起動して確認", "run it locally", ask `Run launching-preview skill? Y/n` before starting. Never auto-launch without confirmation.

## Input

| Argument | Meaning | Default |
|----------|---------|---------|
| `--port <n>` | Local port to bind the preview server / tool | platform default (web: `3000`; iOS: n/a) |
| `--no-open` | Do not auto-open a browser / simulator window; only print the local address | open by default |

Platform is **auto-detected from `.claude/config.yml`** (`platform:` field). No platform argument is accepted — the config is the single source of truth.

## Output

| Artifact | Form |
|----------|------|
| Running preview | a local process bound to a localhost address (or a booted simulator) |
| Access instructions | the local URL / simulator name printed for the user |
| Stop instructions | how to terminate the preview (process / Ctrl-C / simulator shutdown) |

**Output language: Japanese (fixed).** The launch report and access instructions are written in Japanese.

## Flow

1. **Detect platform.** Read `platform:` from `.claude/config.yml`. If absent or `other`, stop and report that no local preview path is configured for this project.
2. **Resolve launch command** for the detected platform:
   - **web:** the project's dev server (e.g. `npm run dev`), binding to `--port` when supplied (default `3000`).
   - **ios:** build the current branch and run on a simulator. Acquire exclusive simulator access via `sim-pool` first; `--port` does not apply.
3. **Launch locally.** Start the preview as a local process. **Never** expose a public/global URL or tunnel — localhost only.
4. **Report access.** Print the local address (web: `http://localhost:<port>`) or the booted simulator name. Honor `--no-open`: when set, print the address only and do not open a window.
5. **Report stop.** Tell the user how to terminate the preview.

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Launch a local preview + report access | **launching-preview** (this skill) |
| Exclusive iOS simulator access | sim-pool |
| Writing / fixing code, running Acceptance Tests | running-atdd-cycle (Step 4) |
| Review verdict on deliverables | reviewing-deliverables (Step 5) |

This skill **does not** provision a global URL, deploy, or run tests. A preview that fails to start is reported to the user, not patched here.

## Integration

- **Upstream:** — (on-demand; invoked manually during development or review, no chain predecessor)
- **Downstream:** — (on-demand; returns control to the caller once the preview is running)
