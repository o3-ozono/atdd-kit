# Headless Skill-Chain Testing Guide

Verifies that atdd-kit skill chains (`skill-gate → discover`, etc.) fire in the expected order by replaying committed Claude Code `stream-json` transcripts and asserting against a scenario spec. The PR CI runs only the deterministic replay layer; live re-recording happens manually via `workflow_dispatch`.

## Regression Coverage Matrix

What the replay layer catches on every skill-touching PR:

| Scenario | Caught by replay? | How |
|----------|------------------|-----|
| Skill removed / renamed | Yes | `expected_skills` mismatch -> exit 1 |
| Skill order regression (e.g., `plan` before `discover`) | Yes (subsequence) / Yes (strict) | assertion engine |
| Forbidden skill leaked (e.g., `atdd-kit:atdd` appears in discover chain) | Yes | `forbidden_skills` check, mode-independent |
| New optional skill inserted between two expected skills | No (subsequence mode) / Yes (strict mode) | design trade-off |
| `skill-gate` bypassed (first event is not `skill-gate`) | Yes | `expected_skills[0]` mismatch |
| Transcript schema change (Claude Code updates `tool_use` layout) | Yes | parser schema validation -> exit 2 |
| Prompt-text quality regression (wording changed) | No | requires live layer / human review |
| Model quality drift (bad decisions despite correct skill firing) | No | out of scope for skill-chain tests; rely on eval layer |
| Subagent-invoked skills (via `Task` tool) | No (MVP) | `parent_tool_use_id` filtered out; covered by follow-up Issue |
| Parallel `tool_use` in a single assistant message | Partially | ordered by array position; true race conditions not representable |
| `SKILL.md` 本文品質（説明文・例・ガイドラインの劣化） | **NOT CAUGHT** | requires human review; out of scope for structural skill-chain tests |
| skill 実行時間 / トークン消費の増大 | **NOT CAUGHT** | no timing or token assertions; needs separate cost-monitoring layer |
| CI path filter 漏れ（headless filter が必要なファイルを除外） | **NOT CAUGHT** | replay runs only when filter matches; missed files silently skip CI |
| skill args の意味的妥当性（型は合っているが意味が間違っている） | **NOT CAUGHT** | assertion engine checks skill names only; semantic arg validation needs scenario-level checks |

## Prerequisites

- `jq` >= 1.6 on `PATH`
- `bats-core` >= 1.5.0 (BATS 1.11.1 pinned in CI)
- Supported Claude Code CLI version: recorded transcripts track the `--output-format stream-json` schema at the time of capture. Re-record when that schema changes (see [Fixture re-recording](#fixture-re-recording)).

## Running the replay suite locally

```bash
# All four replay-layer BATS files (what PR CI runs)
bats tests/test_skill_transcript_parser.bats \
     tests/test_skill_assertion.bats \
     tests/test_headless_runner.bats \
     tests/test_headless_exit_codes.bats

# A single scenario end-to-end
bash scripts/test-skills-headless.sh --replay \
  tests/fixtures/headless/skill-gate-discover.happy.jsonl \
  tests/fixtures/headless/skill-gate-discover.happy.scenario.json
```

Exit code contract (see `AC5` matrix):

| Code | Category | Meaning |
|------|----------|---------|
| 0 | PASS | assertion satisfied |
| 1 | assertion | mismatch or forbidden skill present |
| 2 | parse_error | malformed transcript / parser schema violation |
| 3 | infra | missing jq/claude, bad scenario schema, unreadable file, usage error |
| 4 | timeout | live claude exceeded scenario.timeout |

## Scenario spec schema

`tests/fixtures/headless/*.scenario.json`:

```json
{
  "version": 1,
  "name": "human-readable label",
  "prompt": "prompt used by --live mode",
  "expected_skills": ["atdd-kit:skill-gate", "atdd-kit:discover"],
  "forbidden_skills": ["atdd-kit:plan", "atdd-kit:atdd"],
  "match_mode": "subsequence",
  "timeout": 1800,
  "model": "claude-haiku-4-5-20251001",
  "fixture": "tests/fixtures/headless/skill-gate-discover.happy.jsonl"
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `version` | yes | bump when schema breaks |
| `name` | yes | |
| `prompt` | `--live` only | string passed to `claude -p` |
| `expected_skills` | yes | ordered list, pinned to `atdd-kit:<name>` ids |
| `forbidden_skills` | no (default `[]`) | any hit -> FAIL regardless of mode |
| `match_mode` | yes | `subsequence` allows intermediate skills; `strict` requires exact equality |
| `timeout` | no (default 1800) | seconds; live mode only |
| `model` | no | live model; replay ignores |
| `fixture` | no | replay-default transcript path |

## Adding a new replay scenario

1. Record a fresh transcript (see [Fixture re-recording](#fixture-re-recording)) or hand-write a minimal jsonl fixture that matches the stream-json shape.
2. Place the jsonl under `tests/fixtures/headless/<scenario>.jsonl`.
3. Write the matching `<scenario>.scenario.json` with `expected_skills` / `forbidden_skills` / `match_mode`.
4. Smoke-test locally:
   ```bash
   bash scripts/test-skills-headless.sh --replay \
     tests/fixtures/headless/<scenario>.jsonl \
     tests/fixtures/headless/<scenario>.scenario.json
   ```
5. (Optional) Add a BATS case to `tests/test_headless_exit_codes.bats` if the scenario exercises a new failure path.

## Fixture re-recording

Fixtures are **immutable test vectors** committed to the repo. Re-record them when:

- Claude Code updates the `stream-json` schema in a way that breaks the parser.
- A shipped skill is renamed or removed (this is a `BREAKING CHANGE` per `DEVELOPMENT.md` -- see "Skill rename = semver-breaking").
- The observed skill chain drifts on purpose (e.g., a new gate is added to `skill-gate`).

### Record `skill-gate-discover.happy.jsonl`

Run from the worktree root with the plugin dir pointed at this worktree:

```bash
claude -p --output-format stream-json --include-partial-messages \
  --verbose --no-session-persistence \
  --plugin-dir . \
  --model claude-haiku-4-5-20251001 \
  "atdd-kit:skill-gate を起動してから、atdd-kit:discover で Issue #9999 の AC を整理してください" \
  > tests/fixtures/headless/skill-gate-discover.happy.jsonl
```

#### Why `--plugin-dir .`

`atdd-kit:*` skill ids only resolve when the plugin is loaded. Without `--plugin-dir .`, the session runs against the user's installed plugins (or none) and the fixture no longer reflects this worktree's state.

#### Why `--verbose`

The transcript stream omits some `tool_use` diagnostic fields without `--verbose`. Fixtures without it are less useful for future parser extensions.

#### Why Haiku, not Sonnet (default)

Sonnet 5-hour rate limits are routinely hit during fixture work. Haiku is the Plan v2 default model for all fixtures -- parser-side tests are model-agnostic so cost/stability wins. If you hit rate limits on Sonnet while experimenting, fall back to Haiku and re-record.

#### Engineered prompt rationale

A natural single-turn input ("start discover for Issue #72") causes `skill-gate` to route the session to `autopilot` (that is the governance behavior of the pre-check), which suppresses a direct `discover` invocation. The recorded `skill-gate → discover` chain therefore uses an **engineered** 2-skill prompt that explicitly names both skills. This is a deliberate test vector, not a claim about typical user behavior. Document this when adding future chain scenarios.

### Sanitize before committing

1. `wc -l <fixture>.jsonl` -- non-empty, reasonable size.
2. `bash lib/skill_transcript_parser.sh <fixture>.jsonl` -- exit 0, expected skills present.
3. Replace host-specific tokens so the fixture stays portable:
   - `/Users/<you>/` -> `/Users/<USER>/`
   - `-Users-<you>-` -> `-Users-USER-`
4. Manual diff review for API keys (`sk-ant-`), emails, hostnames, repo tokens, anything else confidential. Re-record if anything leaks.

### Live CI dispatch

```bash
gh workflow run headless-live.yml --ref <branch> \
  -f scenario=tests/fixtures/headless/skill-gate-discover.happy.scenario.json
```

This runs the real `claude -p` invocation against the `ANTHROPIC_API_KEY` secret and uploads the captured transcript as an artifact on failure.

## Budget notes

- Fixture recording per scenario: ~$0.01-$0.05 on Haiku. Keep total re-recording spend within the $1 Plan v2 budget; bump with the user if a scenario needs more.
- Live CI dispatch: billed against `ANTHROPIC_API_KEY`. Run at most monthly against `main` to confirm live/replay have not drifted.
