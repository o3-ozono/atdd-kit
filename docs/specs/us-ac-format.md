---
title: "US/AC spec file format and docs/specs/ directory introduction"
issue: "#66"
status: draft
---

This spec describes the `docs/specs/` format convention introduced in #66. The User Story and ACs below are the authoritative living record of that format, intended to survive Issue closure. This sample conforms to the format defined in [`docs/methodology/us-ac-format.md`](../methodology/us-ac-format.md).

> v1.0 (#216 / #218) note: the persona field has been dropped. This sample has been rewritten as **persona-less Connextra**.

*Note: AC5 (bats structural tests) and AC7 (CHANGELOG update) are implementation-level delivery obligations, not part of the format contract itself. They are listed here for traceability.*

## User Story

**I want to** persist each Issue's User Story and Acceptance Criteria as a single spec file in `docs/specs/`,
**so that** ACs survive Issue closure and serve as Living Documentation with a consistent, LLM-parseable format.

## Acceptance Criteria

### AC1: format definition document exists

- **Given:** atdd-kit has a `docs/methodology/` directory
- **When:** a reader opens `docs/methodology/us-ac-format.md`
- **Then:** the document defines the required frontmatter fields (`title`, `issue`, `status`), section structure (`## User Story`, `## Acceptance Criteria`, `## Notes`), filename convention (`<kebab-slug>.md`), status values and transitions (`draft` / `approved` / `implemented` / `deprecated`), the frontmatter exception (spec files only), and the rename run-book.

### AC2: docs/specs/ directory has README and TEMPLATE

- **Given:** `docs/` exists
- **When:** a reader looks in `docs/specs/`
- **Then:** `docs/specs/README.md` describes purpose, naming convention, and operational rules; `docs/specs/TEMPLATE.md` contains all three frontmatter placeholders with `status: draft` default, plus empty `## User Story` / `## Acceptance Criteria` / `## Notes` sections.

### AC3: sample spec conforms to format

- **Given:** `docs/methodology/us-ac-format.md` defines the format
- **When:** a reader opens `docs/specs/us-ac-format.md`
- **Then:** the file has all three frontmatter fields (`title`, `issue`, `status`); `issue` is `"#66"`; `status` is one of the four allowed values; `## User Story` is non-empty; `## Acceptance Criteria` has 3 or more ACs each with non-empty `Given`, `When`, `Then` lines.

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
- The filename `us-ac-format.md` is derived from the Issue #66 title's main noun phrase.
- This sample spec remains in `draft` state as a historic record.
- **Updated by #218 (Step E6, 2026-05-11):** persona frontmatter field removed; User Story body rewritten as persona-less Connextra.
