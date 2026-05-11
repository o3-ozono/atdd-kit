# US/AC Spec File Format

This document defines the format for User Story + Acceptance Criteria spec files stored in `docs/specs/`.

A spec file persists the User Story and its ACs beyond Issue closure, serving as Living Documentation with a consistent, LLM-parseable structure.

> v1.0 (#216 / #218) note: persona フィールドは廃止されました。User Story 本文は **persona 抜き Connextra** (`I want to <goal>, so that <reason>`) を使います。

## Frontmatter Schema

Every spec file opens with a YAML frontmatter block containing exactly these three fields:

```yaml
---
title: "Short title matching the Issue title"
issue: "#123"
status: draft
---
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Short title matching the corresponding Issue title |
| `issue` | string | Issue reference in `"#NNN"` format (quoted) |
| `status` | enum | One of: `draft`, `approved`, `implemented`, `deprecated` |

### Field Order

Fields must appear in the order: `title`, `issue`, `status`.

### Frontmatter Exception

**Frontmatter applies to spec files only.** Other docs (guides, methodology, workflow) do not use YAML frontmatter. Do not add frontmatter to non-spec files.

## Status Values and Transitions

| Status | Meaning |
|--------|---------|
| `draft` | Initial state. Spec is being written or ACs are not yet approved. |
| `approved` | ACs have been reviewed and approved (discover phase complete). |
| `implemented` | All ACs have been implemented and verified (ship phase complete). |
| `deprecated` | Feature was removed, replaced, or the spec is no longer authoritative. |

Allowed transitions:
- `draft` → `approved` → `implemented`
- Any state → `deprecated` (feature removal, spec replacement)

Do not skip states (e.g., `draft` → `implemented`).

## Body Section Structure

The body must contain these three sections in this order:

```markdown
## User Story

**I want to** [goal],
**so that** [benefit].

## Acceptance Criteria

### AC1: [short name]

- **Given:** [precondition]
- **When:** [action]
- **Then:** [expected outcome]

### AC2: [short name]

...

## Notes

[Optional: design decisions, risks, deferred work, references]
```

### Section Rules

- `## User Story` — must contain a non-empty Story in **persona 抜き Connextra** form (`I want to <goal>, so that <benefit>`).
- `## Acceptance Criteria` — must contain 3 or more ACs, each with non-empty `Given`, `When`, `Then` lines.
- `## Notes` — may be empty or omitted if there are no notes.

Each AC entry uses `**Given:**`, `**When:**`, `**Then:**` bold-prefixed bullet items.

## Filename Convention

Spec files follow the pattern: `<kebab-slug>.md`

The slug is derived from the Issue title's main noun phrase:

- Issue: "Introduce docs/specs/ and define US/AC format" → `us-ac-format.md`
- Issue: "Add login rate limiting" → `login-rate-limiting.md`

**File name = Spec ID.** The filename is the stable identifier for the spec; do not duplicate the title in an `id` frontmatter field.

## Slug Derivation Rule

**1 Issue = 1 spec.** One Issue produces at most one spec file. Splitting or merging specs is a rename operation — see [Rename Run-Book](#rename-run-book).

The canonical slug is produced by `lib/spec_check.sh derive_slug <issue>`:

| Title language | Rule |
|----------------|------|
| English (ASCII) | Strip conventional commit prefix (`feat:`, `fix(scope):`) → lowercase → replace non-alphanumeric runs with `-` → trim leading/trailing `-`. |
| Japanese / non-ASCII | Translate the main concept to English first, then kebab-case. The helper exits non-zero unless `SPEC_SLUG_OVERRIDE=<english-slug>` is supplied. |

Examples:

- `"feat: LLM US/AC auto-reference mechanism"` → `llm-us-ac-auto-reference-mechanism`
- `"Add login rate limiting"` → `add-login-rate-limiting`
- A non-ASCII title (e.g., a Japanese Issue title) → requires `SPEC_SLUG_OVERRIDE=auth-token-leak` (or another English kebab-case slug chosen by the author)

When a title would produce a clash with an existing spec (e.g., iterative rework), rename via the [Rename Run-Book](#rename-run-book) instead of creating a parallel file.

## Spec ↔ Issue Divergence Matrix

Issue comment ACs and `docs/specs/<slug>.md` ACs can diverge over time. `atdd-kit:verify` applies the following matrix; `docs/specs/` is the authority when `status ∈ {approved, implemented}`, and Issue comments are preferred only when `status: draft`.

| Pattern | Example | Expected verify behavior |
|---------|---------|--------------------------|
| Added (spec has AC missing from Issue) | spec has AC11; Issue comment lists AC1–10 | Treat spec AC as authoritative (approved/implemented); emit diff note. On `draft`, warn and prefer Issue AC. |
| Removed (Issue has AC missing from spec) | Issue comment lists AC11; spec has AC1–10 | Treat as gap: if spec status is `approved/implemented`, report Classification A candidate in verify output and do not silently accept the Issue-only AC. |
| Modified (same AC number, different Given/When/Then) | Both have AC5 but wording differs | Use spec text when `status ∈ {approved, implemented}`; cite both versions side-by-side in the verify diff section. |
| Reordered (same ACs, different order) | spec AC order: 1,2,3; Issue: 1,3,2 | Normalize by AC identifier; treat as equivalent for matching. No warning unless meaning-changing reorder is detected. |
| Status drift (spec says `implemented`, Issue open) | spec `status: implemented`; Issue still `in-progress` | Flag as `status-drift` in verify output; ship skill must reconcile before marking complete. |

### Status Tiebreak (verify)

- `status ∈ {approved, implemented}` → spec text wins; diffs against Issue comments are reported as informational.
- `status: draft` → Issue comment ACs win; emit `[spec-warn] draft: Issue comment AC preferred for docs/specs/<slug>.md` and proceed.
- `status: deprecated` → spec is non-authoritative; use Issue comments and warn.

## Rename Run-Book

When renaming a spec file:

1. Rename the file: `git mv docs/specs/old-name.md docs/specs/new-name.md`
2. Update all inbound links: `grep -r "old-name" docs/ DEVELOPMENT.md CHANGELOG.md` and fix each hit.
3. Add a note in `## Notes` of the renamed file: `Renamed from old-name.md in #NNN.`
4. Add a CHANGELOG entry noting the rename.

## Directory Structure

```
docs/specs/
├── README.md       — directory purpose, naming convention, operational rules
├── TEMPLATE.md     — blank template for new spec files
└── <kebab-slug>.md — one file per User Story
```

## References

- `docs/specs/README.md` — operational guide for creating and maintaining specs
- `docs/specs/TEMPLATE.md` — blank template
- `docs/specs/us-ac-format.md` — sample spec (self-reference) demonstrating this format
