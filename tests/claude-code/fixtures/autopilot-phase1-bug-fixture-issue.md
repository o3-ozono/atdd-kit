# bug: tab switch breaks the counter value

## Reproduction

1. Open the counter app.
2. Click increment 3 times; the value shows 3.
3. Switch to a different browser tab, wait 5 seconds, switch back.
4. Expected: value remains 3.
5. Actual: value resets to 0.

## Environment

- Browser: Chrome 125
- App version: 1.4.0

## Notes

This Issue is a minimal bug-type fixture for the autopilot Phase 1
transition integration test (Issue #162). It is intentionally simple so
discover can derive a single-AC bug-flow set and return quickly in
`--autopilot` mode.
