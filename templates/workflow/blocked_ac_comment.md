## skill-fix: blocked-ac

The skill-fix subagent was unable to reach `ready-to-go` because a quality gate failed.

| Field | Value |
|-------|-------|
| **Phase** | $phase |
| **Failed gate** | $failed_gate |
| **Reason** | $reason |

### What happened

The quality gate `$failed_gate` failed during the `$phase` phase.

The `ready-to-go` label was **not** added. The issue remains in its current state for manual review.

### Next steps

1. Review the failed gate details above
2. Manually revise the ACs or issue description to address `$reason`
3. When resolved, apply `gh issue edit <n> --add-label ready-to-go` manually

This comment was posted automatically by the skill-fix subagent.
