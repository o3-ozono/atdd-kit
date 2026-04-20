# NL Profile Fixtures (manual verify)

These fixtures pin the expected resolved matrix for a set of natural-language
profile inputs. They complement the drift-detect BATS suite (which verifies
that `commands/autopilot.md` documents the resolution behavior) with concrete
input → output expectations that a human can replay when model choice,
prompting, or parsing heuristics drift.

Issue #122 simplifies the profile UX to 2 paths:

- **default** (flagless) — `.claude/config.yml` の `spawn_profiles.custom` が
  あれば自動適用、無ければ session default 継承
- **`--profile="NL"`** — `spawn_profiles.custom` をベースに NL 指示を重ねる。
  重複 role は NL が優先、どちらにも無い role は session default

## How to use

1. Prepare `.claude/config.yml` — the pre-condition for each fixture specifies
   what `spawn_profiles.custom` must contain.
2. Run `/atdd-kit:autopilot <issue-number> [--profile="..."]` for each entry
   below with an Issue that is safe to cancel (create a scratch Issue labeled
   `in-progress`).
3. Stop at the Profile Confirmation Gate (only fires when `--profile` is
   specified). Do **not** approve — cancel.
4. Record the matrix shown in the gate against the expected matrix here.
5. If all entries match, tick the DoD checkbox on the PR description. If any
   diverge, file a new Issue with the divergence and do not merge.

Scope: only the model dimension is verified. Effort control is out of scope
(Agent tool schema lacks per-spawn effort).

## Legend

- `default` — session default (Agent tool `model` parameter omitted)
- all fixtures assume issue number `123`

## Fixtures

### F1 — Flagless + custom absent (AC2)

- Pre-condition: `.claude/config.yml` has no `spawn_profiles.custom` (or the
  file itself does not exist)
- Input: `/atdd-kit:autopilot 123`
- Expected: all six roles → `default`. Profile Confirmation Gate does NOT fire.

### F2 — Flagless + custom fully defined (AC1)

- Pre-condition: `.claude/config.yml` defines `spawn_profiles.custom` with all
  6 roles, each `{ model: sonnet }`
- Input: `/atdd-kit:autopilot 123`
- Expected matrix (all six roles):
  - developer: sonnet
  - qa: sonnet
  - tester: sonnet
  - reviewer: sonnet
  - researcher: sonnet
  - writer: sonnet
- Profile Confirmation Gate does NOT fire (flagless path).

### F3 — Flagless + custom partially defined (AC1, partial-definition)

- Pre-condition: `.claude/config.yml` defines `spawn_profiles.custom` with
  only `reviewer: { model: opus }`
- Input: `/atdd-kit:autopilot 123`
- Expected:
  - reviewer: opus
  - developer / qa / tester / researcher / writer: default
- Profile Confirmation Gate does NOT fire (flagless path).

### F4 — `--profile` custom-base overlay, role collision (AC3)

- Pre-condition: `.claude/config.yml` defines `spawn_profiles.custom` with all
  6 roles = sonnet
- Input: `/atdd-kit:autopilot 123 --profile="reviewer only heavy"`
- Expected (NL wins on collision):
  - reviewer: opus
  - developer / qa / tester / researcher / writer: sonnet
- Profile Confirmation Gate fires.

### F5 — `--profile` custom-base overlay, role not in custom and not in NL (AC3)

- Pre-condition: `.claude/config.yml` defines `spawn_profiles.custom` with
  only `reviewer: { model: sonnet }`
- Input: `/atdd-kit:autopilot 123 --profile="developer opus"`
- Expected:
  - developer: opus     (from NL)
  - reviewer: sonnet    (from custom, not touched by NL)
  - qa / tester / researcher / writer: default (neither custom nor NL)
- Profile Confirmation Gate fires.

### F6 — `--profile` without custom (AC3 tail clause)

- Pre-condition: `.claude/config.yml` has no `spawn_profiles.custom`
- Input: `/atdd-kit:autopilot 123 --profile="developer opus"`
- Expected:
  - developer: opus
  - qa / tester / reviewer / researcher / writer: default
- Profile Confirmation Gate fires.

### F7 — `--profile` space delimiter, custom base (AC3)

- Pre-condition: `.claude/config.yml` defines `spawn_profiles.custom` with all
  6 roles = sonnet
- Input: `/atdd-kit:autopilot 123 --profile "keep reviewer default, rest heavy"`
- Expected:
  - reviewer: default (NL overrides custom → session default)
  - developer / qa / tester / researcher / writer: opus

### F8 — Legacy preset flag halts (AC5)

- Pre-condition: any
- Input: `/atdd-kit:autopilot 123 --light`
- Expected: halt with
  `Unknown flag: --light (removed in BREAKING change; use --profile="..." instead. supported: --profile)`.
  No Team / worktree is created.
- Repeat with `--heavy` — expected halt text substitutes `--heavy`.

### F9 — NL parse failure, unknown role (AC6)

- Pre-condition: any
- Input: `/atdd-kit:autopilot 123 --profile="architect だけ opus"`
- Expected: halt with `Could not resolve: "architect"` + the literal follow-on
  (`Supported: model override only (sonnet/opus/haiku). Known roles:
  developer/qa/tester/reviewer/researcher/writer.`). No Team / worktree is
  created.

### F10 — NL parse failure, unsupported model (AC6)

- Pre-condition: any
- Input: `/atdd-kit:autopilot 123 --profile="reviewer gpt4"`
- Expected: halt with `Could not resolve: "gpt4"` and the same follow-on
  message.

### F11 — `.claude/config.yml` schema error halt (AC8)

- Pre-condition: `.claude/config.yml` has `spawn_profiles.custom.reviewer: opus`
  (scalar instead of `{ model: opus }`)
- Input: `/atdd-kit:autopilot 123`
- Expected: halt with
  `.claude/config.yml: spawn_profiles.custom.reviewer must be a map of { model: sonnet|opus|haiku }`
  (or equivalent reason text) before any Team / worktree is created.
