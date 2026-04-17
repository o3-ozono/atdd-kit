# Persona Guide

> **Loaded by:** discover skill, skill authors
> **See also:** [atdd-guide.md](atdd-guide.md) — User Story format and AC conventions

## What Is a Persona?

A persona is a research-based, named character that represents a distinct group of users. Personas are the foundation of Alan Cooper's **Goal-Directed Design** methodology — the premise is that designing for a specific, well-understood person produces better outcomes than designing for an abstract "user."

### The Elastic User Problem

Without personas, user stories refer to a vague "user" that expands or contracts to justify whatever the team wants to build. This is the **Elastic User Problem**: the user becomes whoever is convenient.

> "As a user, I want to export data" — which user? In what format? For what purpose?

A concrete persona prevents this by anchoring the story to a specific person with specific goals and constraints.

> "As Kenji (data analyst), I want to export data as CSV so that I can load it into my existing Excel dashboards."

---

## Persona Format

Each persona file must include the following fields.

| Field | Description |
|-------|-------------|
| **Name** | Fictional name (not a real person). Use a name consistent with the target locale. |
| **Role / Job Title** | The person's job and organizational context. |
| **Goals** | What the persona is trying to accomplish. Split into Primary and Secondary. |
| **Context** | Technical level, working environment, tools used, and key constraints. |
| **Quote** | A one-sentence quote in the persona's voice that captures their core frustration or motivation. |

### Goals: Primary and Secondary

- **Primary Goal:** The main outcome the persona needs from the product. Everything else should serve this.
- **Secondary Goal:** Supporting outcomes that matter but do not define the core need.

### Context: Key Dimensions

Describe at least these three dimensions:

| Dimension | Examples |
|-----------|---------|
| Technical level | Beginner / Intermediate / Expert |
| Environment | Mobile-first, desktop, offline-capable required, low-bandwidth |
| Constraints | Time pressure, compliance requirements, accessibility needs |

---

## Persona Types

atdd-kit recognizes three persona types. Each Issue and User Story should identify which type applies.

### Primary Persona

The person the product is primarily designed for. If the design satisfies this persona without frustrating others, the design is correct.

- **One per feature.** If you find yourself with two primary personas, you likely have two features.
- **Usage:** The subject of the core User Story (`As a [Primary Persona]...`).

### Secondary Persona

A person who uses the product occasionally or for a subset of features. Secondary personas must be accommodated but cannot drive design decisions that conflict with the Primary.

- **Usage:** Mentioned in edge-case ACs or documented as a known secondary audience.

### Negative Persona

A person the product is explicitly *not* designed for. Defining the negative persona prevents scope creep by making exclusion intentional.

- **Examples:** A security researcher probing for vulnerabilities; a power user who prefers CLI over GUI.
- **Usage:** Documented in the persona guide to explain why certain requests are out of scope.

---

## Creation Process

### When to Create a Persona

Create a persona when:
- Starting a new feature area that targets a distinct user group
- The team disagrees about who the user is
- A User Story relies on assumptions about user behavior that are not shared

Do not create a persona for every Issue. Personas represent *groups of users*, not individual features.

### Who Creates Personas

Personas are created collaboratively by the team (PO + developer + QA) based on user research, interviews, or data. The discover skill facilitates persona selection during User Story derivation.

### Update Frequency

Review personas when:
- User research reveals the persona's goals or context have changed
- A new user group emerges that does not fit any existing persona
- A persona has not been referenced in any User Story for 6+ months

---

## Anti-Patterns

These are signs that personas are being misused. Treat them as warnings during creation and review.

### Anti-Pattern 1: Persona Without Research

A persona invented from assumptions rather than evidence. These personas reinforce existing biases instead of revealing user needs.

**Warning sign:** "We know our users" without supporting data.

**Fix:** Ground each field in at least one data source (interview, support ticket, analytics).

### Anti-Pattern 2: Persona Proliferation

Creating a new persona for every feature until the persona library becomes unmanageable.

**Warning sign:** More than 5 personas for a single product area, or personas that differ only superficially.

**Fix:** Merge overlapping personas. If two personas have the same Primary Goal and Context, they are likely the same persona.

---

## Discover Skill Reference Method

### File Path Convention

Persona files live in `docs/personas/`. One file per persona, named after the persona:

```
docs/personas/
  README.md          — directory index and conventions
  TEMPLATE.md        — blank template for new personas
  kenji-analyst.md   — example persona file
```

### User Story Persona Selection Flow (Intended Convention)

During the `discover` skill's User Story Derivation step (Development Flow, Step 3), the skill should:

1. List available personas from `docs/personas/` (excluding README.md and TEMPLATE.md)
2. Present them as options for the `As a [persona]` field
3. Allow the author to select an existing persona or propose a new one
4. If a new persona is needed, prompt creation following this guide's format

> **Note:** SKILL.md integration (adding the persona lookup step to `skills/discover/SKILL.md`) is deferred to Issue F. This section documents the intended convention only. The current discover skill does not yet perform the lookup automatically.

---

## Autopilot Requirements

Autopilot (`/atdd-kit:autopilot`) has no interactive dialogue, so it cannot ask the user to supply the fields needed to create a persona. If it were allowed to bootstrap one on its own, it would have to synthesise the persona from the Issue body, producing an Issue-specific persona invented without user research — the exact failure mode described in Anti-Pattern 1 (Persona Without Research) and, when repeated, Anti-Pattern 2 (Persona Proliferation).

To prevent this, persona bootstrap is disabled under autopilot. The rule is enforced in two layers that share the same valid-persona definition via `lib/persona_check.sh`:

| Layer | Where | Behaviour when `docs/personas/` has 0 valid personas |
|-------|-------|------------------------------------------------------|
| Phase 0.9 prerequisite check | `commands/autopilot.md` | Fail-fast: emit guidance, STOP before TeamCreate / EnterWorktree |
| Step 3a-precheck (defense-in-depth) | `skills/discover/SKILL.md` | Emit the same guidance and return `SKILL_STATUS: BLOCKED` |

The check applies to flows that require a persona — `development` and `bug`. `refactoring`, `research`, and `documentation` skip the check because they do not derive a User Story.

### Valid Persona Definition

A file counts as a valid persona when all of the following hold:

- Located directly under `docs/personas/` (not in a subdirectory)
- File name ends with `.md`
- Not a hidden file (does not start with `.`)
- Not `README.md` or `TEMPLATE.md`
- Non-empty
- The `TEMPLATE.md` placeholder `[Persona Name]` has been replaced

Symlinks are followed. A missing `docs/personas/` directory counts as zero valid personas.

### Creating a Persona Before Running Autopilot

The failure mode tells you what to do: do the user research, then write the persona. Start from `docs/personas/TEMPLATE.md`, ground each field in evidence, and commit the file before invoking autopilot. One persona is enough for autopilot to proceed — add more only when a genuinely distinct user group surfaces (see "Creation Process" above).
