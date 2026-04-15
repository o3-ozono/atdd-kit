---
title: "US/AC spec file format and docs/specs/ directory introduction"
persona: "TBD — replace in #69"
issue: "#66"
status: implemented
---

This spec describes the `docs/specs/` format convention introduced in #66. The User Story and ACs below are the authoritative living record of that format, intended to survive Issue closure.

*Note: AC5 (bats structural tests) and AC7 (CHANGELOG update) are implementation-level delivery obligations, not part of the format contract itself. They are listed here for traceability.*

## User Story

**As a** developer using atdd-kit,
**I want to** persist each Issue's User Story and Acceptance Criteria as a single spec file in `docs/specs/`,
**so that** ACs survive Issue closure and serve as Living Documentation with a consistent, LLM-parseable format.

## Acceptance Criteria

### AC1: format definition document exists

- **Given:** atdd-kit has a `docs/methodology/` directory
- **When:** a reader opens `docs/methodology/us-ac-format.md`
- **Then:** the document defines the required frontmatter fields (`title`, `persona`, `issue`, `status`), section structure (`## User Story`, `## Acceptance Criteria`, `## Notes`), filename convention (`<kebab-slug>.md`), status values and transitions (`draft` / `approved` / `implemented` / `deprecated`), the frontmatter exception (spec files only), the TBD persona rule, and the rename run-book.

### AC2: docs/specs/ directory has README and TEMPLATE

- **Given:** `docs/` exists
- **When:** a reader looks in `docs/specs/`
- **Then:** `docs/specs/README.md` describes purpose, naming convention, and operational rules; `docs/specs/TEMPLATE.md` contains all four frontmatter placeholders with `status: draft` default and `persona: TBD — replace in #69` example, plus empty `## User Story` / `## Acceptance Criteria` / `## Notes` sections.

### AC3: sample spec conforms to format

- **Given:** `docs/methodology/us-ac-format.md` defines the format
- **When:** a reader opens `docs/specs/us-ac-format.md`
- **Then:** the file has all four frontmatter fields (`title`, `persona`, `issue`, `status`); `issue` is `"#66"`; `status` is one of the four allowed values; `## User Story` is non-empty; `## Acceptance Criteria` has 3 or more ACs each with non-empty `Given`, `When`, `Then` lines.

### AC4: docs/README.md index updated

- **Given:** `docs/README.md` has an existing index
- **When:** a reader looks at the index
- **Then:** a `specs/` section is present in the existing table format, and `methodology/` table has a `us-ac-format.md` row.

### AC5: structural bats test (implementation obligation)

- **Given:** `tests/` has existing bats tests
- **When:** a developer runs `tests/test_us_ac_format.bats`
- **Then:** all `@test` blocks pass, verifying directory existence, file existence, frontmatter fields, and `docs/README.md` references.

### AC6: no broken internal links

- **Given:** existing `docs/**/*.md` may reference `docs/methodology/` and `docs/specs/`
- **When:** a developer scans all internal links after adding `docs/specs/` and `docs/methodology/us-ac-format.md`
- **Then:** every referenced file exists (no 404-equivalent broken links).

### AC7: CHANGELOG updated (implementation obligation)

- **Given:** `CHANGELOG.md` exists
- **When:** a reader looks at the latest unreleased section
- **Then:** `### Added` contains an entry for the `docs/specs/` introduction and US/AC format.

## Notes

- This file is the self-referencing sample for the format it describes. The circularity is intentional: the format is proven by its own first use.
- `persona: TBD — replace in #69` is permitted here because personas are being defined in a parallel issue.
- The filename `us-ac-format.md` is derived from the Issue #66 title's main noun phrase.
