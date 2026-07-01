# Prioritization — Feature Priority Methodology

> **Loaded by:** defining-requirements skill

## Positioning

This doc treats **MoSCoW (DSDM: Dynamic Systems Development Method)** as primary source material and extends it for atdd-kit's context. Points where it deviates from the DSDM original are marked `[独自]` (atdd-kit-specific extension).

Reference: DSDM Consortium, *MoSCoW Prioritisation* — https://www.agilebusiness.org/dsdm-project-framework/moscow-prioritisation.html

## 5 段階 (5 Stages)

| Label | Meaning |
|-------|---------|
| MUST | Required for this scope. Do not ship without it. |
| SHOULD | Important, but an alternative exists; shippable without it. |
| WANT | Nice to have; low priority. |
| 次回以降 `[独自]` | Impact is acknowledged, but effort doesn't fit this scope. Explicitly deferred to the next scope. |
| 破棄 `[独自]` | Not adopted. Kept in the core-feature table with a reason (see [Discard Handling](#discard-handling) below). |

The DSDM original MoSCoW has 4 stages (MUST/SHOULD/COULD/WON'T). atdd-kit reinterprets COULD as WANT for solo-development practice, and adds 次回以降 ("defer to next scope") and 破棄 ("discard") as `[独自]` extensions.

## 2 軸判定 (2-Axis Judgment) `[独自]`

Impact (効き — how strongly the change solves the essential problem) and effort (工数 — the implementation cost for this scope) are judged **separately**. The DSDM original uses a single priority axis, so this axis split is an atdd-kit `[独自]` extension.

- **Axis A: 効き (impact)** — how directly this solves the essential problem
- **Axis B: 工数 (effort)** — the implementation cost within this scope

The judgment can be intuitive; the design expects the AI to surface missed perspectives (unconsidered risks, dependencies, alternatives). A rough integrated mapping from the two axes to a recommended label:

| 効き (impact) | 工数 (effort) | Recommended label |
|------|------|-----------|
| 高 | 低〜中 (low–medium) | MUST / SHOULD |
| 高 | 高 | 次回以降 (impactful, but doesn't fit this time) |
| 低 | any | WANT / 破棄 |

(高 = high, 低 = low, 中 = medium)

## anti-pattern

- **Mixing effort into impact**: "効くけど大変だから WANT" (it's impactful but hard, so WANT) is a misuse. If it's impactful, the correct call is MUST/SHOULD or 次回以降 — not a lowered priority.
- **Placing without noticing a missed perspective**: skipping any AI review checkpoint and finalizing classification on human intuition alone.
- **Turning 次回以降 into a junk drawer**: dumping everything there and leaving it unaddressed, using it as an escape hatch for scope decisions.
- **Empty or vague discard reasons**: a bare "not needed" with no traceable rationale for why it wasn't adopted.

## Discard Handling

Discarded feature requirements are **not** deleted from the PRD's core-feature table. They stay in the table with a `破棄` label and a reason.

The purpose is **ゾンビ復活防止 (zombie-revival prevention)**: when a different session or owner re-proposes the same feature later, the rationale for why it was discarded once is available on the spot.

## Connection to `defining-requirements`

The feature-requirement part of the `defining-requirements` skill (Section 4 — What) references this doc's 5-stage / 2-axis frame when classifying priority. The classification algorithm itself stays in `defining-requirements`; this doc supplies the reference definition.

## Non-Goals

- **Quantitative priority scoring**: no numeric scores or weighted calculations. This doc stays limited to codifying the judgment frame.
- **Changing GitHub Issue label design**: the `M/S/C/W priority` labels documented in [scrumban.md](scrumban.md) are unaffected.
