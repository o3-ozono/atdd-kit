# NL Profile Fixtures (manual verify)

These fixtures pin the expected resolved matrix for a set of natural-language
profile inputs. They complement the drift-detect BATS suite (which verifies
that `commands/autopilot.md` documents the resolution behavior) with concrete
input → output expectations that a human can replay when model choice,
prompting, or parsing heuristics drift.

## How to use

1. Run `/atdd-kit:autopilot <issue-number> <profile-input>` for each entry
   below with an Issue that is safe to cancel (e.g. create a scratch Issue
   labeled `in-progress` and use `--light` first to dry-run).
2. Stop at the Profile Confirmation Gate. Do **not** approve — cancel.
3. Record the matrix shown in the gate against the expected matrix here.
4. If all entries match, tick the DoD checkbox on the PR description. If any
   diverge, file a new Issue with the divergence and do not merge.

Scope: only the model dimension is verified. Effort control is out of scope
(see #109 Release Notes / CHANGELOG `[Unreleased]`).

## Legend

- `default` — session default (Agent tool `model` parameter omitted)
- all fixtures assume issue number `123`

## Fixtures

### F1 — Preset light

- Input: `/atdd-kit:autopilot 123 --light`
- Expected matrix (all six roles):
  - developer: sonnet
  - qa: sonnet
  - tester: sonnet
  - reviewer: sonnet
  - researcher: sonnet
  - writer: sonnet

### F2 — Preset heavy

- Input: `/atdd-kit:autopilot 123 --heavy`
- Expected matrix (all six roles):
  - developer: opus
  - qa: opus
  - tester: opus
  - reviewer: opus
  - researcher: opus
  - writer: opus

### F3 — Positional NL, single-role exclusive

- Input: `/atdd-kit:autopilot 123 reviewer だけ opus`
- Expected:
  - reviewer: opus
  - developer / qa / tester / researcher / writer: default

### F4 — Positional NL, role exclusion with remainder

- Input: `/atdd-kit:autopilot 123 reviewer 以外は sonnet`
- Expected:
  - reviewer: default
  - developer / qa / tester / researcher / writer: sonnet

### F5 — Positional NL, mixed models

- Input: `/atdd-kit:autopilot 123 developer は opus、他は sonnet`
- Expected:
  - developer: opus
  - qa / tester / reviewer / researcher / writer: sonnet

### F6 — `--profile=` delimiter, English

- Input: `/atdd-kit:autopilot 123 --profile="reviewer only heavy"`
- Expected:
  - reviewer: opus
  - developer / qa / tester / researcher / writer: default

### F7 — `--profile` space delimiter, quoted

- Input: `/atdd-kit:autopilot 123 --profile "keep reviewer default, rest heavy"`
- Expected:
  - reviewer: default
  - developer / qa / tester / researcher / writer: opus

### F8 — Mid-phase resume + preset

- Input: Issue at `ready-to-go`, `/atdd-kit:autopilot 123 --heavy`
- Expected: fresh Phase 3 Developer spawn (and Phase 4 Reviewers) pass
  `model: opus` via the Agent tool. Gate still fires before Phase 0.9.

### F9 — NL parse failure (known role typo)

- Input: `/atdd-kit:autopilot 123 architect だけ opus`
- Expected: halt with `Could not resolve: "architect"` message; no Team /
  worktree creation.

### F10 — NL parse failure (effort dimension attempted)

- Input: `/atdd-kit:autopilot 123 reviewer の effort を high に`
- Expected: halt with `Effort control is not supported in this release.`
  fragment surfaced in the error message.
