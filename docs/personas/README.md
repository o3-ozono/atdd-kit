# Personas

Persona files for atdd-kit. Personas anchor User Stories to specific, research-based characters and prevent the Elastic User Problem.

See [persona-guide.md](../methodology/persona-guide.md) for the full guide on what personas are, how to create them, and how they are used in the discover skill.

## Directory Purpose

This directory stores one persona file per persona. Each file represents a distinct user group that atdd-kit serves or explicitly does not serve.

## Template Usage

To create a new persona:

1. Copy `TEMPLATE.md` to a new file named after the persona (e.g., `kenji-analyst.md`)
2. Fill in all fields following the format defined in [persona-guide.md](../methodology/persona-guide.md)
3. Reference the persona in User Stories using the persona's Name field

## Convention: One File Per Persona

Each persona lives in its own file. Do not combine multiple personas in one file.

File naming: `<first-name>-<role>.md` (lowercase, hyphen-separated)

| File | Description |
|------|-------------|
| [TEMPLATE.md](TEMPLATE.md) | Blank template for new personas |
| [hiro-solo-dev.md](hiro-solo-dev.md) | **Primary** — solo developer running atdd-kit on personal projects as the sole maintainer |
| [rin-freeform-coder.md](rin-freeform-coder.md) | **Negative** — freeform coder who rejects Issue-driven and AC-first process (explicitly out of scope) |
