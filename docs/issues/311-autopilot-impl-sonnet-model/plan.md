# Plan: autopilot impl phase の Sonnet 指定を Workflow スクリプトに恒久反映

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

出典: `docs/issues/311-autopilot-impl-sonnet-model/user-stories.md`（承認済み User Stories）, `prd.md`（承認済み PRD アンカー）
対象: `skills/autopilot/SKILL.md`（Workflow スクリプト本文）, `tests/test_autopilot_skill.bats`

事前検証済みの行番号（PRD §6）: `const PHASE = A.phase` = 96 行目 / impl agent() 6 箇所 = gen(201,203) / review(205) / at-gate(210) / coverage(217) / audit(235) / rails(242) / 除外対象 `freeze:anchor` = 180 行目。現行 279 行・pin `≤ 280`。

## Implementation

- [ ] US2/AC1: `const PHASE = A.phase`（96 行目）の直後に `const MODEL = PHASE === 'impl' ? 'sonnet' : undefined` を 1 行追加する
- [ ] verify: `grep -nF "const MODEL = PHASE === 'impl' ? 'sonnet' : undefined" skills/autopilot/SKILL.md` が 1 件ヒットし、その行が `const PHASE = A.phase` の直後である

- [ ] US1/AC2: `gen:${step}` agent() の opts（201/203 行の `{ label: gen:${step}, phase: 'Generate' }`）に `model: MODEL` をインライン付与する
- [ ] verify: `grep -n 'label: `gen:' skills/autopilot/SKILL.md` のヒット行に `model: MODEL` が含まれる

- [ ] US1/AC2: `review:${step}` agent() の opts（205 行）に `model: MODEL` を付与する
- [ ] verify: 205 行付近の `label: `review:` を含む行に `model: MODEL` が含まれる

- [ ] US1/AC2: `at-gate:${step}` agent() の opts（210 行）に `model: MODEL` を付与する
- [ ] verify: `label: `at-gate:` を含む行に `model: MODEL` が含まれる

- [ ] US1/AC2: `coverage:${step}` agent() の opts（217 行）に `model: MODEL` を付与する
- [ ] verify: `label: `coverage:` を含む行に `model: MODEL` が含まれる

- [ ] US1/AC2: `audit:${step}` agent() の opts（235 行）に `model: MODEL` を付与する
- [ ] verify: `label: `audit:` を含む行に `model: MODEL` が含まれる

- [ ] US1/AC2: `rails:${step}` agent() の opts（242 行）に `model: MODEL` を付与する
- [ ] verify: `label: `rails:` を含む行に `model: MODEL` が含まれる

- [ ] US2/AC3: `freeze:anchor`（180 行）の opts には `model` を付与しない（無変更を確認）
- [ ] verify: `freeze:anchor` を含む行に `model:` が含まれない。かつ SKILL.md 全体で `model: MODEL` の出現回数がちょうど 6 である

- [ ] CS1/AC4: SKILL.md の総行数が 280 行以下に収まることを確認する（MODEL 定数 +1 行・6 箇所はインライン追記で純増 0 行 → 280/280）
- [ ] verify: `wc -l < skills/autopilot/SKILL.md` が 280 以下

## Testing

- [ ] CS2/AC5: `tests/test_autopilot_skill.bats` に AT-001（`PHASE === 'impl' ? 'sonnet'` 定義の存在）を追加する
- [ ] verify: 追加した @test が単体で green

- [ ] CS2/AC5: AT-002（6 つの impl agent ラベル行すべてに `model: MODEL` が付与され、出現回数 = 6）を追加する
- [ ] verify: 追加した @test が green

- [ ] CS2/AC5: AT-003（`freeze:anchor` 行に `model:` が無い = design/orchestrator は不付与）を追加する
- [ ] verify: 追加した @test が green

- [ ] CS2/AC5: AT-004（行数 ≤ 280 維持・既存 line budget pin と整合）を追加または既存 pin で担保する
- [ ] verify: 追加した @test が green、かつ既存 line budget pin（131 行目）も green のまま

- [ ] AT スイート全体を実行する
- [ ] verify: `bats tests/test_autopilot_skill.bats` が全 green（新規 AT 含む・既存 pin 非回帰）

## Finishing

- [ ] CHANGELOG.md / バージョン整合性チェック（DEVELOPMENT.md: feature PR は plugin.json + CHANGELOG 更新が必須）
- [ ] verify: `.claude-plugin/plugin.json` の version が CHANGELOG.md の最上位リリース見出しと一致する

- [ ] ドキュメント整合性チェック
- [ ] verify: SKILL.md 本文 Model assignment セクション（impl=Sonnet）とスクリプト挙動（`MODEL = PHASE==='impl'?'sonnet'`）が整合している
