# AC Review — Developer Perspective

## Architecture Integrity

The proposed DoD → User Story → AC three-layer structure is consistent with the existing skill chain. `discover` produces structured deliverables consumed by `plan` (Step 1: "Development/bug/refactoring: User Story + ACs"). `plan` does not reference "Completion Criteria" by label — it reads whatever discover posts. The Documentation/Research flow change (Completion Criteria → DoD) requires verifying that `plan`'s Step 1 read logic still works when the heading changes. Currently `plan` distinguishes flows by "User Story + ACs" vs "completion criteria" — if discover's doc/research output heading changes to "DoD", plan's detection logic may silently misclassify the task type.

**Downstream impact to assess:**
- `skills/plan/SKILL.md` Step 1: reads discover deliverables by content pattern; must tolerate new "DoD" heading in doc/research outputs.
- `skills/verify/SKILL.md`: verify checks against ACs; no structural change expected for dev tasks.
- `skills/atdd/SKILL.md`: atdd reads ACs from Issue comments; no change expected.

The shared prefix (DoD first in all task types) is architecturally sound and will make the Issue comment format more consistent.

## Technical Feasibility

Implementable as markdown changes to SKILL.md. The approach requires:

1. Extracting a new "DoD Derivation" step that runs after Approach Exploration across **all** flows (Development, Bug, Refactoring, Documentation, Research).
2. Updating the Documentation/Research flow Step 3 ("Define Completion Criteria") to "Derive DoD" with matching output format.
3. Updating the Issue comment templates (Step 5/8 format blocks) in both dev and doc/research flows to add a DoD section at the top.
4. Updating the Mandatory Checklist to add a DoD check item.
5. Renaming "Completion Criteria" terminology throughout the doc/research flow sections.

No new files need to be created. The change is confined to `skills/discover/SKILL.md` with potential follow-on edits to `skills/plan/SKILL.md`.

## Edge Cases

**Gap 1 — Refactoring tasks with internal-only changes:**
The draft ACs (AC2, AC3) cover "development / bug / refactoring" together for three-layer output, and "research / documentation" for DoD-only output. Refactoring typically has no user-facing behavior change. The current Refactoring Flow note says "User story perspective: The subject is a developer or team." The AC set does not address whether DoD for a pure refactoring task looks different from a feature task, or whether the User Story in the refactoring case should be optional (given it is developer-facing). This is not a blocker but should be clarified in the implementation.

**Gap 2 — Existing "Completion Criteria" in live Issue comments:**
AC4 covers terminology removal from the SKILL.md definition, but does not cover backward compatibility of already-posted Issue comments that use "Completion Criteria." `plan`'s Step 1 looks for discover deliverables by content pattern. If old comments use "Completion Criteria" and new SKILL.md produces "DoD," there is a potential plan state-gate ambiguity. This is an operational edge case (not a blocker) but plan's detection should be made robust.

**Gap 3 — Bug flow DoD derivation:**
The Bug Flow in the current SKILL.md goes: Understand Bug → Root Cause → Fix Approach → Fix AC Derivation. The draft does not specify where DoD is inserted in the Bug Flow. AC1 says "discover が任意のタスクタイプで実行されたとき" which implies the Bug Flow must also include DoD, but the draft AC set does not have a concrete test for the Bug Flow Issue comment format containing DoD.

**Gap 4 — AC count threshold interaction:**
The existing "Split heuristic: if AC count reaches 7 or more" applies to ACs only. With DoD items added, the total item count in the deliverables increases. No AC addresses whether DoD items should be counted separately from ACs for the split heuristic.

## Implementation Complexity

**Files requiring changes:**

| File | Sections | Scope |
|------|----------|-------|
| `skills/discover/SKILL.md` | Development Flow Steps 3-8, Bug Flow Steps 4-6, Refactoring Flow, Documentation/Research Flow Steps 3-5, Mandatory Checklist | Medium — ~6-8 sections, all within one file |
| `skills/plan/SKILL.md` | Step 1 (deliverable detection logic) | Small — 1 section, verify "DoD" heading is handled |

The change scope is reasonable. SKILL.md is a single large file; the edits are additive (inserting DoD derivation step) plus renaming (Completion Criteria → DoD in doc/research sections). No new files needed.

**Eval implications (critical):**
`skills/discover/evals/baseline.json` shows pass_rate=1.0 across all evals. The `documentation` eval (eval id=2) has assertion C2: "Given/When/Then 形式ではなくチェックリスト形式を使用している" and C1: verifiable checklist. If the documentation flow output heading changes from "Completion Criteria" to "DoD" but the format stays checklist, C1/C2 remain valid. However, if the output format changes structurally (DoD items use different list semantics), C1/C2 may need updating. A before/after eval run is mandatory per DEVELOPMENT.md rules.

## Missing ACs

**AC6: Bug Flow Issue comment contains DoD section**
- **Given:** discover が bug タスクで実行されたとき
- **When:** 成果物が提示されると
- **Then:** DoD セクションが Issue コメントの先頭に含まれている（Root Cause の前）

**AC7: plan スキルが DoD ヘッダを含む discover 成果物を正しく読み取れる**
- **Given:** discover が documentation タスクを完了し、"DoD" ヘッダを含む Issue コメントを投稿したとき
- **When:** plan が Issue コメントを読み取ると
- **Then:** タスクタイプが documentation と正しく判定され、plan が適切な doc/research フローで動作する

**AC8: Eval regression guard (DoD as implementation constraint)**
- **Given:** skills/discover/SKILL.md に変更を加えたとき
- **When:** auto-eval を実行すると
- **Then:** pass_rate が baseline (1.0) から 10% 以上低下しない

(AC8 is an implementation constraint rather than a user-visible behavior, but it should be documented as a DoD item per DEVELOPMENT.md Skill Changes Require Eval Evidence rules.)

## Verdict

APPROVE WITH CHANGES

Architectural fit is sound and the implementation is technically feasible, but the AC set has gaps in Bug Flow DoD coverage (AC6) and plan downstream compatibility (AC7) that should be added before implementation to prevent silent regressions in the skill chain.
