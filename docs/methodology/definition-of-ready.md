# Definition of Ready (DoR)

> **Loaded by:** discover skill, plan skill

An Issue is **Ready** when all of the following criteria are met. `ready-to-go` label is applied only after DoR is confirmed.

## DoR Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| R1 | **Impact link** — Issue declares which Impact in [impact-map.md](../product/impact-map.md) it contributes to | `Impact:` line in Issue body |
| R2 | **User Story present** — `As a [persona], I want to [goal], so that [benefit]` using a named persona from `docs/personas/` | Issue body or linked spec file |
| R3 | **ACs generated** — 3 or more Given/When/Then ACs with no `TBD` placeholders | discover skill output |
| R4 | **Questions = 0** — no open questions or ambiguities remain | discover skill Q&A complete |
| R5 | **INVEST passed** — story satisfies Independent, Negotiable, Valuable, Estimable, Small, Testable | discover skill INVEST check |
| R6 | **Size is not L, or if L: split plan documented** — Large stories must have a split plan or explicit justification for not splitting | See [story-splitting.md](./story-splitting.md) |
| R7 | **No `blocked-ac` label** — all AC ambiguities resolved | GitHub label check |

## AC Notation

For the authoritative AC format (Given/When/Then), see [us-ac-format.md](./us-ac-format.md).

For AC quality standards (MUST criteria including persona reference, independent verifiability), see [us-quality-standard.md](./us-quality-standard.md).

## Transition to Ready

The discover skill drives the DoR check. When all criteria are met:

1. discover skill outputs `DISCOVER_COMPLETE`
2. autopilot transitions Issue to AC Review Round
3. Reviewer checks R1–R7
4. On PASS: `ready-to-go` label applied → plan skill can start

If any criterion fails, the Issue stays in `in-progress` with `blocked-ac` if AC-related, or returns to discover.

## Relationship to Autopilot Labels

| Label | DoR Relationship |
|-------|-----------------|
| `in-progress` | discover active; DoR not yet met |
| `blocked-ac` | R4 or R7 fails; waiting for AC clarification |
| `ready-for-plan-review` | DoR met; plan being reviewed |
| `ready-to-go` | DoR confirmed + plan review PASS |

See [scrumban.md](./scrumban.md) for the full label correspondence table.

## References

- [us-ac-format.md](./us-ac-format.md) — AC notation authority (format + status transitions)
- [us-quality-standard.md](./us-quality-standard.md) — AC quality MUST criteria
- [story-splitting.md](./story-splitting.md) — Splitting guide for R6
- [scrumban.md](./scrumban.md) — Full methodology context and label table
- [impact-map.md](../product/impact-map.md) — R1 Impact reference
