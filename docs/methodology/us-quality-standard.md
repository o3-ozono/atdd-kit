# User Story Quality Standard

> **Loaded by:** discover skill, plan skill
> **See also:** [persona-guide.md](persona-guide.md) — persona definitions and Elastic User Problem
> **See also:** [atdd-guide.md](atdd-guide.md) — AC format and GWT rules
> **See also:** [us-ac-format.md](us-ac-format.md) — spec file format (frontmatter exception)

## Classification Rationale

This document uses two levels of requirement strength:

- **MUST** — Existing format rules enforced by the workflow. Violations break tooling or traceability.
- **SHOULD** — QUS-derived quality goals. Violations reduce story quality but do not break the workflow.

The MUST/SHOULD split is intentional: MUST criteria are already enforced by discover/plan tooling; SHOULD criteria are guidance for authors to internalize.

---

## MUST Criteria

These rules are non-negotiable. A User Story that violates any MUST criterion must be revised before moving to plan.

### MUST-1: Persona Reference

The `As a` field must reference a named persona from [docs/personas/](../personas/) using a relative link or a recognized persona name. Generic placeholders like "As a user" are prohibited.

**Why:** "As a user" causes the Elastic User Problem — the story's audience expands or contracts to justify whatever the team wants to build. A named persona anchors the story to specific goals and constraints.

**Pass:** `As a Kenji (data analyst), I want to export data as CSV so that I can load it into my Excel dashboards.`

**Fail:** `As a user, I want to export data.`

---

### MUST-2: Minimum AC Count

Each User Story must have 3 or more Acceptance Criteria (GWT format). If a story has 7 or more ACs, consider splitting it; document the reason if splitting is inappropriate.

**Why:** Stories with fewer than 3 ACs typically have underspecified requirements. The 3+ rule from [atdd-guide.md](atdd-guide.md) ensures baseline coverage of happy path, edge case, and error path.

**Pass:** A story with AC1 (happy path), AC2 (empty input), AC3 (error state) — 3 ACs.

**Fail:** A story with only 1 AC covering the happy path.

---

### MUST-3: Independent Verifiability

Each Acceptance Criterion must be independently verifiable. Each AC must have a Pass/Fail example pair that demonstrates how to confirm pass and fail states.

**Why:** ACs without clear verification criteria become ambiguous during review and testing. Independent verifiability ensures each AC can be tested in isolation.

**Pass:** AC with `Given: user is logged in / When: user clicks Export / Then: CSV file downloads within 2 seconds` — testable independently.

**Fail:** AC with `Then: the system works correctly` — "correctly" is not independently verifiable.

---

### MUST-4: US Traceability

Each Acceptance Criterion must be traceable to at least one element of the User Story — either the persona's primary goal (`I want to`) or the benefit (`so that`). ACs that cannot be mapped to a specific User Story element do not belong in the AC set.

**Why:** Three Amigos reviews (Developer/QA perspectives) tend to drift toward boundary conditions, project conventions, and implementation safety nets. Without an explicit traceability requirement, these concerns enter the AC set and dilute the story's focus. A named mapping forces the author to justify each AC against observable user value.

**Exclusion categories** — candidates that must be re-routed, not added as ACs:

| Category | Examples | Correct location |
|----------|---------|-----------------|
| Project conventions | CI green, zero warnings, lint, coverage thresholds | DoD |
| Trivial / implied consequences | "feature works after previous AC passes" | Consolidate into existing AC or omit |
| Implementation guards | init duplicate check, NaN fallback, defensive null check | Implementation note |
| Future Story concerns | extensibility, DI wiring, upcoming features | Plan's test strategy |

**Pass:** `Given: Hiro runs the export flow / When: the dataset has 0 rows / Then: the UI shows "No data to export" instead of a blank file` — maps directly to the persona's primary goal "I want to export data reliably."

**Fail:** `Given: the CI pipeline runs / When: the export feature is deployed / Then: all lint checks pass` — this is a project convention (CI green), not traceable to the user's goal. Move to DoD.

> **Retroactive application:** This criterion applies only to ACs derived in new `discover` runs. Existing approved specs under `docs/specs/` are not subject to retroactive MUST-4 evaluation.

---

## SHOULD Criteria

These are quality goals derived from the Quality User Story (QUS) framework. Violations degrade story quality but are not workflow blockers. During discover, the skill should prompt the author to address SHOULD violations before approval.

### SHOULD-1: Well-Formed

A User Story must follow the canonical template: `As a [persona], I want to [goal], so that [benefit].` All three parts must be present and non-empty.

**Rationale:** The three-part structure encodes the who, what, and why. Missing the `so that` clause removes the business rationale, making prioritization harder.

**Pass:** `As a Kenji (data analyst), I want to filter reports by date range, so that I can focus on quarterly data without manual scrolling.`

**Fail:** `As a Kenji, I want to filter reports.` (missing benefit clause)

---

### SHOULD-2: Atomic

A User Story should describe a single, cohesive piece of user value. Stories that combine multiple independent goals should be split.

**Rationale:** Atomic stories are easier to estimate, implement, and test. Compound stories often lead to partially-done work that cannot be shipped independently.

**Pass:** `As a Kenji, I want to export filtered data as CSV, so that I can load it into Excel.`

**Fail:** `As a Kenji, I want to export data as CSV and configure the column order and schedule a weekly export, so that I can automate my reporting.` (three independent goals)

---

### SHOULD-3: Minimal

A User Story should contain only the information necessary to express the goal and benefit. Avoid embedding implementation details, technical constraints, or design specifications in the story itself.

**Rationale:** Implementation details in stories constrain the team's solution space prematurely. They belong in ACs or technical notes, not in the story statement.

**Pass:** `As a Kenji, I want to export data as CSV, so that I can use it in Excel.`

**Fail:** `As a Kenji, I want a button in the top-right corner that uses the XYZ library to stream CSV data with UTF-8 encoding, so that I can use it in Excel.` (implementation details embedded)

---

### SHOULD-4: Problem-Oriented

A User Story should describe the user's problem or goal, not the solution. The `I want to` clause should express an outcome the user wants to achieve, not a feature to implement.

**Rationale:** Solution-oriented stories prevent the team from discovering better solutions. Problem-oriented stories open the solution space.

**Pass:** `As a Kenji, I want to see how my report metrics changed over the last quarter, so that I can identify trends.`

**Fail:** `As a Kenji, I want a line chart widget on the dashboard with a quarter-selector dropdown, so that I can see trends.` (solution prescribed, not problem described)

---

### SHOULD-5: Unambiguous

A User Story should use precise, measurable language. Avoid subjective adjectives and comparative terms without baselines.

**Rationale:** Ambiguous stories produce ambiguous ACs, which lead to disagreements during review and acceptance. Precision in stories propagates to precision in ACs.

**Pass:** `As a Kenji, I want export to complete within 5 seconds for datasets under 10,000 rows, so that my workflow is not interrupted.`

**Fail:** `As a Kenji, I want fast exports, so that my workflow is smooth.` ("fast" and "smooth" are undefined)

---

## Anti-Pattern Reference

Requirements Smells that commonly appear in User Stories. Each smell category lists bad examples and suggested rewrites.

### Anti-Pattern Category 1: Subjective Expressions

Subjective words make ACs unverifiable because "good", "fast", "easy", and similar terms have no agreed measurement.

| Bad Example | Suggested Rewrite |
|-------------|-------------------|
| "the system should be fast" | "the system should respond within 2 seconds for requests under 1 MB" |
| "the UI should be user-friendly" | "the user should complete the export flow in 3 steps or fewer" |
| "the export should be smooth" | "the export should complete without visible loading indicators for files under 100 KB" |

**Warning sign:** Adjectives without measurement units (fast, easy, clean, good, simple, seamless).

**Fix:** Add a measurable threshold or a specific observable behavior.

---

### Anti-Pattern Category 2: Unverifiable Terms

Terms that sound specific but cannot be objectively tested.

| Bad Example | Suggested Rewrite |
|-------------|-------------------|
| "users should be satisfied with the result" | "users should be able to complete the task without requesting support" |
| "the system should handle large files" | "the system should handle files up to 50 MB without returning an error" |
| "the feature should work correctly" | "the feature should return a 200 response with a valid JSON payload matching the schema" |

**Warning sign:** "satisfied", "correct", "works", "handles" without quantification.

**Fix:** Replace with an observable, measurable outcome.

---

### Anti-Pattern Category 3: Incomplete References

References to external systems, rules, or standards that are not linked or defined within the story or its ACs.

| Bad Example | Suggested Rewrite |
|-------------|-------------------|
| "comply with the security policy" | "comply with OWASP Top 10 as defined in `docs/security-policy.md`" |
| "follow the design system" | "use components from the design system at `docs/design-system/README.md`" |
| "as per the existing behavior" | "as per the behavior documented in AC3 of Issue #42" |

**Warning sign:** "as per", "according to", "following the" without a specific, linked reference.

**Fix:** Add a direct link or a specific issue/document reference.

---

## LLM Prompt Guidelines

### Scope Overview

This quality standard is intended for use in LLM-driven quality checks during the `discover` skill's User Story derivation phase. An LLM agent can use these criteria to evaluate draft User Stories and ACs before the author submits them for approval.

The MUST criteria provide binary pass/fail checks. The SHOULD criteria provide qualitative assessments where the LLM explains the violation and suggests a rewrite. The Anti-pattern reference provides pattern-matching targets for smell detection.

### Current Status and Defer Note

Detailed prompt design for LLM-driven US quality checks is deferred to Issue #69. The prompt templates, few-shot examples, and evaluation rubric for each criterion will be defined there.

This section documents the intended scope and hook points only. Do not implement LLM prompt logic until Issue #69 specifications are finalized.
