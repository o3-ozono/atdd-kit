---
name: merging-and-deploying
description: "Use when a PR has passed review and is ready to merge, deploy, and run post-deploy regression AT."
---

# Merging and Deploying

Step 6 of the atdd-kit v1.0 flow — the flow terminus. Take an Issue whose deliverables passed Step 5 review, then run the ordered ship sequence: **merge → deploy → post-deploy regression**. The post-deploy regression re-runs the Acceptance Tests under `tests/acceptance/` against the deployed build, so production is verified against the same green tests that drove the implementation.

**Scope starts at a PASS verdict.** Producing or fixing deliverables is owned by the earlier steps; this skill assumes review already passed and does not re-open implementation.

## Trigger

- **Explicit:** `/atdd-kit:merging-and-deploying <issue-number>`
- **Keyword-detected (confirm before invoking):** When user messages mention merge / deploy / ship intent (e.g. "マージ", "deploy", "リリース"), confirm before starting via **AskUserQuestion** (header `Merge?`; first option `(Recommended) マージ` for one-tap go, then `保留（レビュー継続）`; `multiSelect: false`):
  ```
  Recommended: マージ — reply 'ok' to accept, or 保留 to hold for more review
  ```
  This **replaces** the previous `Y/n` text confirm — it changes only how the existing confirm is offered, not the Flow (precondition check → squash-merge is unchanged); **no new in-skill gate is added**. The `Other` option is harness-auto — never list it manually; an `Other` free-text comment flows into the existing natural-language route unchanged. On non-selection-UI channels (headless / cron), the `Recommended: ... — reply 'ok'` line is the fallback. Auto-invocation without confirmation is forbidden by the v1.0 Step B progression rule (#179).

## Input

- Issue number (command-line argument or recognized in a user message)
- A PR for the Issue with a **PASS** verdict from `reviewing-deliverables` (Step 5) and green CI.
- The executable Acceptance Tests under `tests/acceptance/` (the regression set).

If the review verdict is not PASS, instruct the user to return to `reviewing-deliverables` (or `running-atdd-cycle` to fix findings) and stop.

## Output

| Artifact | Form |
|----------|------|
| Merged PR | squash-merged to `main`, Issue closed via `Closes #<NNN>` |
| Deployed build | the platform deploy for the merged change |
| Post-deploy regression result | the `tests/acceptance/` suite re-run against the deployed build |

**Output language: Japanese (fixed).** The merge / deploy / regression report is written in Japanese; commit and PR metadata follow the repository's commit conventions.

## Flow

1. **Precondition check.** Confirm the PR carries a PASS verdict from `reviewing-deliverables` and CI is green. Do not merge otherwise.
2. **Merge.** Squash-merge the PR to `main`, closing the Issue (`Closes #<NNN>`).
3. **Deploy.** Deploy the merged change via the project's configured deploy path (platform-specific; see `.claude/config.yml`).
4. **Post-deploy regression.** Re-run the Acceptance Tests in `tests/acceptance/` against the deployed build as a **regression** check. These are the `[regression]`-marked ATs stabilized at Step 4. If any fails, report it immediately and treat the deploy as suspect.
5. **Report + Retrospective.** Summarize merge SHA, deploy result, and the post-deploy regression outcome in one message. Output the same content to both the terminal and as an Issue/PR comment (all-channel sync: terminal + Issue/PR comment). Then run `scripts/retrospective.sh --issue <NNN> --pr <PR>` — this is the **sole entry point** for retrospective execution. The express skill does not call `merging-and-deploying`, so express Issues skip retrospective structurally — no `if non-express` branch is needed (express skip is structural, not a flag).

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Merge + deploy + post-deploy AT regression | **merging-and-deploying** (this skill) |
| PRD / US / Plan / Code / AT review verdict | reviewing-deliverables (Step 5, #192) |
| Plan + AT spec → green AT + production code | running-atdd-cycle (Step 4, #191) |
| Parallel-session conflict, `in-progress` label management | skill-gate (#197) |

This skill **does not** add or remove the `in-progress` label — that is skill-gate's responsibility. This skill **does not** write or fix code — a failing post-deploy regression is reported back to Step 4, not patched here.

## Test Execution Policy (#324 / #323)

**Pre-merge gate: full suite** — run all tests before merging to guarantee full regression coverage:

```
scripts/run-tests.sh --all      # pre-merge gate (full suite — mandatory)
```

**Post-deploy regression: impact scope** — after deploy, re-run the Acceptance Tests using impact scope against the deployed commit:

```
scripts/run-tests.sh --impact --base <merge-sha>   # post-deploy regression (impact scope)
```

The asymmetry is by design: merge gate uses `--all` (fail-safe guarantee); post-deploy regression uses `--impact --base <ref>` (targeted verification of what was deployed). claude-based e2e tests (`tests/e2e/*.bats`) are included in the full suite at merge gate; at post-deploy they follow the impact criterion.

For the full policy doctrine, see [`docs/methodology/test-execution-policy.md`](../../docs/methodology/test-execution-policy.md).

## Integration

- **Upstream:** `reviewing-deliverables` (merges only on its PASS verdict)
- **Downstream:** — (flow terminus; the next Issue restarts at `session-start` → `defining-requirements`)
