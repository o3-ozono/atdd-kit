# US/AC Spec File Format

This document defines the format for User Story + Acceptance Criteria spec files stored in `docs/specs/`.

A spec file persists the User Story and its ACs beyond Issue closure, serving as Living Documentation with a consistent, LLM-parseable structure.

## Frontmatter Schema

Every spec file opens with a YAML frontmatter block containing exactly these four fields:

```yaml
---
title: "Short title matching the Issue title"
persona: "PersonaName"
issue: "#123"
status: draft
---
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Short title matching the corresponding Issue title |
| `persona` | string | Persona name from `docs/personas/` (see TBD rule below) |
| `issue` | string | Issue reference in `"#NNN"` format (quoted) |
| `status` | enum | One of: `draft`, `approved`, `implemented`, `deprecated` |

### Field Order

Fields must appear in the order: `title`, `persona`, `issue`, `status`.

### Frontmatter Exception

**Frontmatter applies to spec files only.** Other docs (guides, methodology, workflow, personas) do not use YAML frontmatter. Do not add frontmatter to non-spec files.

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

## TBD Persona Rule

When a spec is created before persona research is complete, use:

```yaml
persona: "TBD — replace in #69"
```

This is only permitted when `status: draft`. Before moving to `approved`, the `TBD` placeholder must be replaced with a real persona name from `docs/personas/`.

## Body Section Structure

The body must contain these three sections in this order:

```markdown
## User Story

**As a** [persona],
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

- `## User Story` — must contain a non-empty Constraint Story (As a / I want to / so that).
- `## Acceptance Criteria` — must contain 3 or more ACs, each with non-empty `Given`, `When`, `Then` lines.
- `## Notes` — may be empty or omitted if there are no notes.

Each AC entry uses `**Given:**`, `**When:**`, `**Then:**` bold-prefixed bullet items.

## Filename Convention

Spec files follow the pattern: `<kebab-slug>.md`

The slug is derived from the Issue title's main noun phrase:

- Issue: "docs/specs/ 導入と US/AC format 策定" → `us-ac-format.md`
- Issue: "Add login rate limiting" → `login-rate-limiting.md`

**File name = Spec ID.** The filename is the stable identifier for the spec; do not duplicate the title in an `id` frontmatter field.

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
- `docs/personas/` — persona files referenced in `persona:` field
