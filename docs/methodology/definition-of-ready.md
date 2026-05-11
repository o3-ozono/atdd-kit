# Definition of Ready (DoR)

> **Loaded by:** discover skill, plan skill

An Issue is **Ready** when all of the following criteria are met. `ready-to-go` label is applied only after DoR is confirmed.

> v1.0 (#216 / #218) note: persona / INVEST / Story Splitting (US methodology) は v1.0 で不採用。User Story は persona 抜き Connextra (`I want to <goal>, so that <benefit>`)。

## DoR Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| R1 | **Impact link** — Issue declares which Impact in [impact-map.md](../product/impact-map.md) it contributes to | `Impact:` line in Issue body |
| R2 | **User Story present** — `I want to [goal], so that [benefit]` in persona-less Connextra form | Issue body or linked spec file |
| R3 | **ACs generated** — 3 or more Given/When/Then ACs with no `TBD` placeholders | discover skill output |
| R4 | **Questions = 0** — no open questions or ambiguities remain | discover skill Q&A complete |
| R5 | **No `blocked-ac` label** — all AC ambiguities resolved | GitHub label check |

## AC Notation

For the authoritative AC format (Given/When/Then), see [us-ac-format.md](./us-ac-format.md).

For AC quality standards (MUST criteria including independent verifiability and US traceability), see [us-quality-standard.md](./us-quality-standard.md).

## Transition to Ready

The discover skill drives the DoR check. When all criteria are met:

1. discover skill outputs `DISCOVER_COMPLETE`
2. autopilot transitions Issue to AC Review Round
3. Reviewer checks R1–R5
4. On PASS: `ready-to-go` label applied → plan skill can start

If any criterion fails, the Issue stays in `in-progress` with `blocked-ac` if AC-related, or returns to discover.

## Relationship to Autopilot Labels

| Label | DoR Relationship |
|-------|-----------------|
| `in-progress` | discover active; DoR not yet met |
| `blocked-ac` | R4 or R5 fails; waiting for AC clarification |
| `ready-for-plan-review` | DoR met; plan being reviewed |
| `ready-to-go` | DoR confirmed + plan review PASS |

See [scrumban.md](./scrumban.md) for the full label correspondence table.

## References

- [us-ac-format.md](./us-ac-format.md) — AC notation authority (format + status transitions)
- [us-quality-standard.md](./us-quality-standard.md) — AC quality MUST criteria
- [scrumban.md](./scrumban.md) — Full methodology context and label table
- [impact-map.md](../product/impact-map.md) — R1 Impact reference
