# PR Review Guide

> **Loaded by:** ship, autopilot (QA)

## PR Description Structure

1. **Summary** -- 1-2 sentences describing the change
2. **File table** -- File names and roles
3. **Design decisions table** -- Decisions and rationale
4. **CI evidence link**
5. **E2E test video** (if UI changed)
6. **Before/After screenshots** (if UI changed)

## Inline Comment Rules

- Add a file-header comment explaining the file's role and purpose
- Explain language-specific features for non-specialists
- Skip auto-generated files

## Code Review Checklist

### State Management

| # | Check |
|---|-------|
| S1 | Is the state owner clear? No duplicate state management across locations? |
| S2 | Is the state lifecycle appropriate? No state living longer than needed? |
| S3 | Are presentation flags (modal display, etc.) reset on every dismiss path? |
| S4 | No feedback loops from two-way bindings? |

### Error Handling

| # | Check |
|---|-------|
| E1 | No swallowed errors (empty catch blocks, etc.)? |
| E2 | Is error state properly communicated to the user? |
| E3 | Are retryable operations given a retry mechanism? |

### Security

| # | Check |
|---|-------|
| X1 | Is user input validated? |
| X2 | No secrets (tokens, passwords) in logs? |
| X3 | No OWASP Top 10 vulnerabilities? |

## Review Severity Definitions

| Severity | Meaning | Merge Impact |
|----------|---------|-------------|
| **critical** | Bug, security vulnerability, data loss risk | Blocks merge (must fix) |
| **warning** | Design concern, performance issue, maintainability | Advisory (fix if possible) |
| **suggestion** | Code style, naming improvement, refactoring idea | Advisory (author's judgment) |

## Framework-Specific Checks

Concrete check items should be in the project's `docs/process/code-review-checklist.md`.

Expected sections per framework:

- **SwiftUI**: State management (@State/@Observable), navigation, view implementation, localization
- **React**: Hooks rules, SSR/CSR boundaries, state management (useState/useReducer), accessibility
- **Go**: Goroutine leaks, error wrapping, context propagation, interface design
- **Common**: Framework-specific anti-patterns, project-specific regression prevention rules
