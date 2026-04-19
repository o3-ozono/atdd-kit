---
title: "LLM US/AC auto-reference mechanism and atdd-kit dogfooding"
persona: "hiro-solo-dev"
issue: "#70"
status: draft
---

This spec is the self-referencing dogfood instance for the US/AC auto-reference mechanism introduced in #70. It is cited by `atdd`, `verify`, and `bug` when working on #70 itself (Continuation Path) per AC6(b) + AC1.

## User Story

**As a** hiro-solo-dev (a solo developer using atdd-kit on a personal project),
**I want to** have atdd / verify / bug automatically load `docs/specs/<slug>.md` through a helper (`lib/spec_check.sh`) and codified SKILL.md steps,
**so that** "implementation guided by AC" is structurally enforced, and AC-external code, forgotten ACs, and spec/Issue divergence are prevented.

## Acceptance Criteria

### AC1: atdd loads the spec

- **Given:** Issue #N has `docs/specs/<slug>.md`
- **When:** atdd passes the State Gate, before the first AC implementation
- **Then:** a `Loaded docs/specs/<slug>.md (AC count: N)` line is emitted; subsequent Outer Loops cite that AC set.

### AC2: verify treats the spec as authoritative (status tiebreak)

- **Given:** both the spec and Issue comment ACs exist
- **When:** verify loads ACs
- **Then:** `status ∈ {approved, implemented}` → spec wins; `status: draft` → Issue comment wins with warning; any divergence is reported diff-style.

### AC3: bug Classification cites spec ACs

- **Given:** bug skill Root Cause Investigation Step 2
- **When:** performing A/B/C Classification
- **Then:** the governing spec AC is cited explicitly; if no spec exists, Classification A (AC Gap) is reported with `no spec found for <area>`.

### AC4: `lib/spec_check.sh` helper is provided

- **Given:** the `lib/persona_check.sh` pattern as a model
- **When:** a developer runs `bash lib/spec_check.sh <function> <args>`
- **Then:** `derive_slug`, `spec_exists`, `read_acs`, `spec_status`, `spec_persona`, `get_spec_load_message`, and `get_spec_warn_message` are documented exports; SKILL.md spec-reference steps call through this helper.

### AC5: slug derivation rule is documented

- **Given:** an Issue title in English or Japanese
- **When:** `lib/spec_check.sh derive_slug` runs
- **Then:** EN → main noun phrase kebab-cased; JA → translated to English first via `SPEC_SLUG_OVERRIDE`. `docs/methodology/us-ac-format.md` documents this rule, the 1 Issue = 1 spec policy, and cross-links the Rename Run-Book.

### AC6: fallback for missing / continuation / TBD cases

- **Given:** one of — (a) new work without a spec, (b) Continuation Path on a branch whose spec is absent, (c) spec with `persona: TBD` + `status: approved`
- **When:** atdd / verify / bug consult the spec
- **Then:** (a) BLOCKED as discover-incomplete; (b) warning + Issue comment fallback; (c) warning + continue with spec ACs. All warnings use the `[spec-warn]` terminal prefix.

### AC7: self-dogfooding on #70

- **Given:** this PR before merge
- **When:** `docs/specs/llm-us-ac-auto-reference.md` is created inside the PR and autopilot is re-run against #70 (manually)
- **Then:** a transcript of atdd loading the newly created spec is attached to the PR description. CI automation is out of scope (follow-up Issue).

### AC8: divergence matrix

- **Given:** the spec and Issue comment ACs disagree
- **When:** verify runs
- **Then:** the 5 divergence patterns (AC added / removed / modified / reordered / status drift) each have defined expected behavior in `docs/methodology/us-ac-format.md` § Spec ↔ Issue Divergence Matrix, and AC10 behavioral evals cover each pattern.

### AC9: footprint budget

- **Given:** `evals/footprint/baseline.json` (autopilot 21,898 tokens as of 2026-04-17)
- **When:** `scripts/measure-footprint.sh --check` runs
- **Then:** atdd / verify / bug SKILL.md token delta ≤ +500 total. `baseline.json` is updated in this PR; `--check` PASSes.

### AC10: behavioral eval + bats structural test

- **Given:** `skills/{atdd,verify,bug}/evals/evals.json` and `tests/test_spec_reference.bats`
- **When:** each is executed
- **Then:**
  - Each evals.json has at least one new spec-reference eval and pass_rate does not regress
  - bats verifies (a) the spec-load step grep in the 3 SKILL.md files, (b) the `lib/spec_check.sh` function exports, (c) the `rules/atdd-kit.md` invariant, (d) the EN-only reference convention, and all `@test` blocks PASS.

## Notes

- Scope: Only the mechanism + this one spec. The remaining 8 skills (discover/plan/verify/ship/autopilot/bug/issue/session-start) get specs under a follow-up tracking Issue — one PR per skill.
- Persona: `hiro-solo-dev` (see `docs/personas/hiro-solo-dev.md`). Not `TBD` because persona research was completed ahead of #70.
- `status: draft` remains until merge; transitions to `implemented` in ship phase after the AC7 dogfood transcript lands in the PR.
- Slug: `llm-us-ac-auto-reference`. Because the Issue title is Japanese, `SPEC_SLUG_OVERRIDE=llm-us-ac-auto-reference` was supplied (see `docs/methodology/us-ac-format.md` § Slug Derivation Rule).
