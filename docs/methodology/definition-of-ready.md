# Definition of Ready (DoR)

> **Loaded by:** defining-requirements (Step 1), writing-plan-and-tests (Step 3)

An Issue is **Ready** when all of the following criteria are met. `ready-to-go` label is applied only after DoR is confirmed.

> v1.0 (#216 / #218) note: persona / INVEST / Story Splitting (as a US methodology) are not adopted in v1.0. User Stories use persona-less Connextra (`I want to <goal>, so that <benefit>`).

## DoR Criteria

| # | Criterion | How to Verify |
|---|-----------|---------------|
| R1 | **Impact link** — Issue declares which Impact in [impact-map.md](../product/impact-map.md) it contributes to | `Impact:` line in Issue body |
| R2 | **User Story present** — `I want to [goal], so that [benefit]` in persona-less Connextra form | Issue body or linked spec file |
| R3 | **ACs generated** — 3 or more Given/When/Then ACs with no `TBD` placeholders | defining-requirements output |
| R4 | **Questions = 0** — no open questions or ambiguities remain | defining-requirements Q&A complete |
| R5 | **No `blocked-ac` label** — all AC ambiguities resolved | GitHub label check |

## AC Notation

For the authoritative AC format (Given/When/Then), see [us-ac-format.md](./us-ac-format.md).

For AC quality standards (MUST criteria including independent verifiability and US traceability), see [us-quality-standard.md](./us-quality-standard.md).

## Transition to Ready

The defining-requirements skill (Step 1) drives the DoR check. When all criteria are met:

1. defining-requirements produces `docs/issues/<NNN>/prd.md` with the AC set
2. The `reviewing-deliverables` skill (Step 5) runs the relevant review lenses (documentation / functional-correctness) of its dynamic panel, which checks R1–R5
3. On PASS: `ready-to-go` label applied → writing-plan-and-tests (Step 3) can start

If any criterion fails, the Issue stays in `in-progress` with `blocked-ac` if AC-related, or returns to defining-requirements.

## Relationship to Scrumban Labels

| Label | DoR Relationship |
|-------|-----------------|
| `in-progress` | defining-requirements active; DoR not yet met |
| `blocked-ac` | R4 or R5 fails; waiting for AC clarification |
| `ready-for-plan-review` | DoR met; plan being reviewed |
| `ready-to-go` | DoR confirmed + plan review PASS |

See [scrumban.md](./scrumban.md) for the full label correspondence table.

## References

- [us-ac-format.md](./us-ac-format.md) — AC notation authority (format + status transitions)
- [us-quality-standard.md](./us-quality-standard.md) — AC quality MUST criteria
- [scrumban.md](./scrumban.md) — Full methodology context and label table
- [impact-map.md](../product/impact-map.md) — R1 Impact reference
- [acceptance-test-feasibility.md](./acceptance-test-feasibility.md) — Feasibility probe doctrine: the bridge between R3/R4 (AC completeness / questions = 0) and committing an AT as `[planned]`. DoR is necessary but not sufficient — a feasibility probe must pass before `[planned]` status is confirmed.
