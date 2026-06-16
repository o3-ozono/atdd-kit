# User Stories: autopilot impl phase の Sonnet 指定を Workflow スクリプトに恒久反映

Issue: #311
出典: `docs/issues/311-autopilot-impl-sonnet-model/prd.md`（承認済み PRD アンカー）

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US1: impl phase subagent への Sonnet デフォルト恒久注入

**I want to** autopilot の Workflow スクリプトが impl phase のループ内 subagent（gen / review / at-gate / coverage / audit / rails）を Sonnet で起動するよう、スクリプト記述だけで `model: MODEL` を恒久指定できる,
**so that** autopilot を実走するたびに保存済みスクリプトを手修正して `model: 'sonnet'` を注入する必要がなくなり、#259 のモデル方針とコードの乖離が解消される.

<!-- 出典: PRD ## ゴール, ## スコープ In scope 1-2, AC1/AC2 -->

### US2: design phase / orchestrator のセッションモデル維持

**I want to** `MODEL = PHASE === 'impl' ? 'sonnet' : undefined` という分岐で impl phase 以外（design phase の `freeze:anchor` を含むオーケストレーション glue）には `model` を付与しない,
**so that** design phase / orchestrator は従来どおりセッションモデル（Opus/Fable）を継承し、品質が要る設計判断のモデルを下げずに済む.

<!-- 出典: PRD ## スコープ In scope 1,3, AC1/AC3 -->

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。 -->

### CS1: SKILL.md 行数バジェットの維持

**I want to** 上記の変更後も `skills/autopilot/SKILL.md` の総行数が 280 行以下に収まっている（MODEL 定数 +1 行・6 箇所はインライン追記で純増 0 行）,
**so that** line budget pin（≤ 280）が守られ、3 回目の raise 禁止（DEVELOPMENT.md）に抵触せず、ローダ stub 分割（#304）を前倒しせずに済む.

<!-- 出典: PRD ## 制約, AC4 -->

### CS2: 変更を固定する Acceptance Test の追加

**I want to** `tests/test_autopilot_skill.bats` に、`PHASE === 'impl' ? 'sonnet'` の存在・6 箇所の `model: MODEL` 付与・行数 ≤ 280 を検証する AT が追加され緑になっている,
**so that** 将来の編集で Sonnet デフォルトや budget が回帰した場合に CI で検出でき、手修正ギャップの再発を防げる.

<!-- 出典: PRD ## スコープ In scope 4, AC5 -->
