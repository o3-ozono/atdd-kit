# Spec Reference Guide

Full reference for how atdd / verify / bug skills load and cite
`docs/specs/<slug>.md` via `lib/spec_check.sh`. This guide expands on the
condensed steps in each `SKILL.md` so those files stay under the footprint
budget.

## Canonical Flow

1. Derive the slug from the Issue title:

   ```bash
   slug=$(bash lib/spec_check.sh derive_slug <issue>)
   ```

   - EN titles are kebab-cased automatically after stripping the conventional
     commit prefix.
   - JA / non-ASCII titles exit non-zero unless `SPEC_SLUG_OVERRIDE` is set to
     an English kebab-case slug. See
     [`docs/methodology/us-ac-format.md` § Slug Derivation Rule](../methodology/us-ac-format.md#slug-derivation-rule).

2. Check spec existence:

   ```bash
   if bash lib/spec_check.sh spec_exists "$slug"; then
     count=$(bash lib/spec_check.sh read_acs "$slug")
     bash lib/spec_check.sh get_spec_load_message "$slug" "$count"
   fi
   ```

3. For verify only, resolve the tiebreak:

   ```bash
   status=$(bash lib/spec_check.sh spec_status "$slug")
   ```

## AC6 Fallback Matrix (shared by atdd / verify / bug)

| Case | Condition | Action | Terminal output |
|------|-----------|--------|-----------------|
| (a) missing-new | `spec_exists` fails AND no prior impl commits | STOP, re-run discover | `[spec-warn] missing: ...` |
| (b) continuation-fallback | `spec_exists` fails AND Continuation Path (existing impl branch) | Continue with Issue comment ACs | `[spec-warn] continuation-fallback: ...` |

All three skills use `lib/spec_check.sh::get_spec_warn_message <reason>`.

> v1.0 (#218): the former `tbd-persona` case was removed when persona was dropped.

## verify Status Tiebreak

| Spec status | Authority | Terminal output |
|-------------|-----------|-----------------|
| `approved` / `implemented` | Spec wins | (none — spec is default) |
| `draft` | Issue comments win | `[spec-warn] draft: Issue comment AC preferred for docs/specs/<slug>.md` |
| `deprecated` | Issue comments win | `[spec-warn] deprecated: ...` |

See [`docs/methodology/us-ac-format.md` § Spec ↔ Issue Divergence Matrix](../methodology/us-ac-format.md#spec--issue-divergence-matrix) for the 5-pattern behavior table used by verify.

## bug Classification Citation

- spec present → cite the governing AC number + `Given/When/Then` text as the
  Classification basis. Fix Proposal `Spec AC` field points to
  `docs/specs/<slug>.md#ACN`.
- spec absent → Classification A (AC Gap). Report "no spec found for <area>".
  Never invent ad-hoc ACs to fill the gap.

## Order Invariant

`spec check` runs after State Gate PASS, before first AC / verification / classification.
`tests/test_spec_reference.bats` Group 1 asserts this ordering for atdd.

> v1.0 (#218): the legacy `persona check` precedence was removed when persona was dropped.
