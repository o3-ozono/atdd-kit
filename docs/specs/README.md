# Specs

User Story + Acceptance Criteria spec files for atdd-kit. Spec files persist the User Story and its ACs beyond Issue closure, serving as Living Documentation.

See [us-ac-format.md](../methodology/us-ac-format.md) for the full format definition, frontmatter schema, status transitions, and filename conventions.

## Directory Purpose

This directory stores one spec file per User Story. Each file contains the User Story, its ACs, and optional notes.

Spec files survive Issue closure and act as the authoritative living record of what was built and why.

## Naming Convention

File name pattern: `<kebab-slug>.md`

The slug is derived from the Issue title's main noun phrase (e.g., Issue #66 "US/AC format" → `us-ac-format.md`).

**File name = Spec ID.** Do not add an `id` frontmatter field.

## Creating a New Spec

1. Copy `TEMPLATE.md` to a new file: `cp docs/specs/TEMPLATE.md docs/specs/<kebab-slug>.md`
2. Fill in all three frontmatter fields (`title`, `issue`, `status`).
3. Replace `status: draft` with the correct status once ACs are approved.

> v1.0 (#216 / #218) note: persona field was removed from spec frontmatter; User Stories use **persona-less Connextra** (`I want to <goal>, so that <reason>`).

## Operational Rules

- **One file per User Story.** Do not combine multiple User Stories in one file.
- **Status must reflect reality.** Update `status` when ACs move through the lifecycle.
- **Do not add frontmatter to non-spec files.** Frontmatter is spec-file-only (see format doc).
- **When renaming a file**, follow the rename run-book in `us-ac-format.md`.

## Directory Contents

| File | Description |
|------|-------------|
| [README.md](README.md) | Directory purpose, naming convention, operational rules |
| [TEMPLATE.md](TEMPLATE.md) | Blank template for new spec files |
| [us-ac-format.md](us-ac-format.md) | Sample spec: US/AC format convention introduced in #66 |
