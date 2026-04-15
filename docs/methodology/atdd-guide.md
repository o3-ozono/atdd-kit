# ATDD Guide

> **Loaded by:** atdd skill, Issue templates

## Issue / PR Granularity

- **Split by user flow, not by technical layer.**
- 1 PR does 1 thing.

### Anti-patterns

| Pattern | Problem |
|---------|---------|
| Layer-based split (Model PR -> View PR -> ViewModel PR) | Reviewer can't see the full picture |
| Separating E2E tests into a different PR | Breaks test-implementation traceability |
| 1 screen = 1 Issue | Granularity varies wildly by screen complexity |

## User Story

### Format

> "As a [persona], I want to [goal], so that [reason]."

### Constraint Stories

Stories that define quality standards. No Story Test needed.

Example: "As a developer, I want zero build warnings, so that quality regressions are caught early."

## AC (Acceptance Criteria) Format

### Given / When / Then

```
Given: <precondition>
When:  <action>
Then:  <expected result>
```

### Rules

- 3 or more ACs per story (if 7+, consider splitting the story; document the reason if splitting is inappropriate)
- Derive boundary values and edge cases from the happy path
- Each AC must be independently verifiable

## UX Heuristic Checklist

| # | Aspect | Check |
|---|--------|-------|
| U1 | Visibility | Does the system status reach the user? |
| U2 | Control | Can the user undo or redo actions? |
| U3 | Consistency | Are terms, layout, and interactions uniform? |
| U4 | Error Prevention | Does the design prevent mistakes? |
| U5 | Efficiency | Can frequent actions be completed in few steps? |

## Interruption Scenarios

| # | Scenario | Check |
|---|----------|-------|
| I1 | Tab switch | Is state preserved when the user leaves and returns? |
| I2 | Cancel state | Is state properly reset when the user cancels mid-operation? |
| I3 | Background resume | Does the app work correctly after returning from background? |
| I4 | Modal escape | Can the user dismiss modals/dialogs (including gestures)? |

## Double-Loop TDD

> For detailed AC-to-test-layer mapping, see [test-mapping.md](test-mapping.md).

```
Outer loop: Story Test (E2E / Integration)  <- 1 AC = 1 Outer Loop cycle
  -> RED:  Write an E2E test for the AC -> Confirm failure
  -> Inner loop: Unit TDD                   <- runs N times per AC
      -> RED:   Write a unit test -> Confirm failure
      -> GREEN: Minimal implementation to pass
      -> REFACTOR
  -> GREEN: Story Test passes
  -> REFACTOR: Full refactoring
```

### Inner Loop Rules

- **Never write implementation code before its test.**
- **Never weaken a test to make it pass.**

## ATDD Applicability

The default is **write tests.** If you realize mid-implementation that something needs a test, stop and write the test first.

### Cases Where Tests Are Not Required

- Config-only changes (CI config, linter config, etc.)
- Auto-generated code updates
- Documentation-only changes

Everything else: write tests. When in doubt, write tests.
