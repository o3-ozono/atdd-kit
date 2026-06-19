# docs/methodology/

Methodology deep-dives: detailed guidance on ATDD, User Story quality, Scrumban workflow, and related practices. These documents are loaded on-demand by skills that need them.

## Documents

| File | Description |
|------|-------------|
| [atdd-guide.md](atdd-guide.md) | ATDD double-loop TDD process, AC format rules, and test layer selection |
| [autopilot-design-gate.md](autopilot-design-gate.md) | The autopilot design-approval User gate — AskUserQuestion presentation, diff-in-body, fallback, and the unchanged approval/rejection semantics |
| [autopilot-iron-law.md](autopilot-iron-law.md) | The autopilot Iron Law (AL-1…AL-6) — overrides the standard Iron Law while autopilot (`autopilot`) runs |
| [autopilot-overview.md](autopilot-overview.md) | autopilot role map and Responsibility Boundary — who owns each concern in the convergence loop |
| [route-eligibility.md](route-eligibility.md) | Single source for express vs autopilot route determination — express-eligible signals, autopilot signals, ambiguous fallback, and the recommendation-only invariant |
| [bug-fix-process.md](bug-fix-process.md) | Bug fix classification (A/B/C) and step-by-step repair process |
| [definition-of-done.md](definition-of-done.md) | Definition of Done — AC gate, CI gate, PR gate, documentation gate |
| [definition-of-ready.md](definition-of-ready.md) | Definition of Ready — criteria for an Issue to enter ready-to-go state |
| [scrumban.md](scrumban.md) | Scrumban + ATDD integrated methodology — terminology, label table, solo adaptations |
| [test-mapping.md](test-mapping.md) | AC-to-test-layer mapping reference |
| [us-ac-format.md](us-ac-format.md) | User Story and AC spec file format (frontmatter schema, status transitions) |
| [us-quality-standard.md](us-quality-standard.md) | User Story quality standard: MUST/SHOULD criteria, anti-patterns, and LLM guidelines |
| [test-execution-policy.md](test-execution-policy.md) | Phase-based test execution doctrine — impact-only during ATDD iterations, full suite before review/merge |
| [skill-loader-split.md](skill-loader-split.md) | SKILL.md loader stub split methodology — split pattern, full skill inventory with urgency ranks, impact analysis, pin operation rules, and rollout plan (#314) |
| [acceptance-test-feasibility.md](acceptance-test-feasibility.md) | Pre-planning feasibility probe doctrine — GUI vs non-GUI bifurcation, flow integration point (Step 3), user escalation gate, tool abstraction, and autopilot alignment (#312) |

## Conventions

- No YAML frontmatter in methodology files (frontmatter is for `docs/specs/` only — see `us-ac-format.md`)
- English only (LLM-facing documents)
- Each document starts with a `> **Loaded by:**` meta-comment listing which skills reference it
