# Plan: autopilot 設計承認ゲート（#249）

## Implementation

### skills/autopilot/SKILL.md — 2 フェーズ化 + 設計承認ゲート（F1 / F2 / F3 / C1）

- [ ] description / 冒頭を「人間ゲート 3 点（要求承認 / 設計承認 / merge）」に更新
- [ ] Human gates 節を 3 点構成にし、設計承認ゲートの提示物・承認文言・差し戻し再投入（F3）を記述
- [ ] 埋め込み Workflow script を `args.phase = 'design' | 'impl'` でパラメタ化:
  - design: STEPS = [extracting-user-stories, writing-plan-and-tests] / anchor = prd.md / pin = autopilot-prd.pin / AT・coverage ゲート off
  - impl: STEPS = [running-atdd-cycle] / anchor = prd.md + user-stories.md / pin = autopilot-design.pin / AT・coverage ゲート on
  - fail-closed: impl で AT_STEP ∉ STEPS は throw（既存維持）、design に AT_STEP が混入したら throw（新設）
- [ ] Flow 節（skill 手順）: precondition（PRD 承認済み）→ design Workflow → 設計承認ゲート → impl Workflow → merge 引き渡し
- [ ] verify: 行数 ≤240、既存 BATS 文字列アサーション（後述の更新後セット）を満たす

### docs/methodology/autopilot-iron-law.md — AL-1 / AL-2 更新

- [ ] AL-1: 人間ゲートを「要求承認（discover）/ 設計承認（design deliverables, ATDD 前）/ merge」の 3 点固定に
- [ ] AL-2: 2 段 pin（design anchor = prd.md / impl anchor = 設計承認時の prd.md + user-stories.md、acceptance-tests.md は lifecycle marker 更新のため pin 対象外で coverage gate が内容を守る）に更新
- [ ] 「Skills are unchanged」節・冒頭の 2 ゲート記述を 3 ゲートに同期

## Testing

- [ ] tests/test_autopilot_skill.bats: ゲート 3 点（design approval を含む）/ 2 段 pin（autopilot-prd.pin / autopilot-design.pin）/ phase 分離（design に running-atdd-cycle が入らない fail-closed）アサーションへ更新・追加
- [ ] tests/e2e/autopilot.bats: F1 を 3 ゲート（design approval を含む）の検証に更新
- [ ] tests/README.md: 「two human gates」→「three human gates」
- [ ] verify: `bats tests/test_autopilot_skill.bats tests/test_autopilot_convergence.bats tests/test_rules_workflow.bats` green + コア全 suite green

## Finishing

- [ ] README.md / README.ja.md / skills/README.md の autopilot 行を 3 ゲート記述に同期
- [ ] CHANGELOG.md [Unreleased] に Changed 追記（挙動変更を明記）
- [ ] .claude-plugin/plugin.json 3.6.0 → 3.7.0
- [ ] Draft PR（`Closes #249`）→ reviewing-deliverables → merge は人間ゲート
