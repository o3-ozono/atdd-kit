> **Loaded by:** `autopilot` skill (FS-2 loader-split — content moved from `skills/autopilot/SKILL.md` ## Responsibility Boundary, #304).

# autopilot — Role Map and Responsibility Boundary

## Responsibility Boundary

Each concern in the autopilot convergence loop has a single owner:

| Concern | Owner |
|---------|-------|
| Looping the flow skills to the **objective** satisfaction oracle (red→green AT + AC→AT coverage) | **autopilot** (this skill) |
| Each artifact's generation | the flow skills (unchanged) |
| Review judgment (PASS/FAIL over deliverables) | the human at the merge gate; `reviewing-deliverables` as an optional standalone Step 5 — **not** in the autopilot loop (#355) |
| Requirements approval / design approval / merge (the three User gates) | the human |
| Parallel-session conflict, `in-progress` label | skill-gate |

autopilot **does not** permanently change the flow skills, **does not** approve its own requirements or design, **does not** run an LLM reviewer in its convergence loop (#355 — convergence is objective-gate-only; self-judgment does not converge), and **does not** merge — merging is the User gate (AL-1).

For the full Iron Law (AL-1…AL-6) that constrains the above, see `docs/methodology/autopilot-iron-law.md`.

## Gate③後フィードバックの正規ルート (#334)

Gate③（merge）後にユーザーの実機フィードバックで新ACが生じた場合は**直接実装しない**。設計アンカー変更の有無で分岐する:

- **設計アンカー不変（少数AC）** → 同一Issue内 design 差し戻し
- **設計アンカー変更を伴う（新機能）** → 新Issue

正典は `docs/methodology/autopilot-iron-law.md` (AL-5b) — 詳細はそちらを参照。本 overview は要約参照であり、iron-law との乖離が生じた場合は iron-law が優先する。
