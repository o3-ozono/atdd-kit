# User Stories: 成果物提示を Draft PR ベースに統一 — workflow-detail.md のレガシー記述矛盾と defining-requirements の承認後書き込み順序の修正

## Functional Story

### US-1: workflow-detail.md のレガシー記述を Workflow 表と整合させる

**I want to** `docs/workflow/workflow-detail.md` Execution Mode 節のレガシー記述（成果物は `gh issue comment` / `gh pr comment` 経由で流す）が削除され、Workflow 表と整合する規定（成果物はブランチコミット + Draft PR、状態通知のみ Issue/PR コメント）に置換されている,
**so that** セッションが v1.0 移行前の記述に従って成果物を Issue コメントで提示する逸脱が再発しない.

### US-2: PRD ドラフトは承認前に commit/push → Draft PR で提示される

**I want to** `skills/defining-requirements/SKILL.md` の Flow が「draft を `prd.md` に書き込み → commit/push → Draft PR 作成 → 承認ゲート（PR 上）」の順序になっており、autopilot・通常フローの両方に適用される,
**so that** Gate ①（要件確定）の PRD ドラフトをターミナル長文や Issue コメントではなく Draft PR の差分としてレビューできる.

### US-3: autopilot Gate ①/② の提示チャネルが PR 差分ベースと明文化される

**I want to** `skills/autopilot/SKILL.md` の Dialog economy 節に、Gate ①（要件承認）/ Gate ②（設計承認）とも成果物提示は PR 差分ベースで行うという提示チャネル規定が追記されている,
**so that** autopilot 運用で Gate ごとの提示チャネルがセッション判断で揺れず、レビュー体験の劣化が再生産されない.

## Constraint Story (Non-Functional)

### CS-1: ターミナル出力は PR リンク + 判断が必要な点のみ

**I want to** Gate ①/② のターミナル提示が PR リンクと判断が必要な点のみに抑えられ、成果物の全文展開を行わない,
**so that** レビュー時に長文のターミナル出力を読み解く負荷がなく、PR 差分という単一のレビュー面に集中できる.

### CS-2: スキル変更は BATS pin で構造検証される

**I want to** 変更した SKILL.md の規定文言が、影響する BATS pin の更新・追加（DEVELOPMENT.md「Skill Changes Require Test Evidence」準拠）で構造検証されている,
**so that** 将来の SKILL.md 編集で提示チャネル規定が欠落・改変されてもテストで即座に検知できる.

### CS-3: 既存ルールの範囲内で実現し、全チャネル内容同期は維持される

**I want to** 本変更が `rules/atdd-kit.md` への新規定追加なし（既存 3 規定からの導出で完結）かつ、状態通知・承認依頼など人間の判断材料の全チャネル同期（ターミナル + GitHub）を維持したまま、成果物本体の置き場所の規定のみに限定されている,
**so that** ルールの 60 行予算を消費せず、どこで見ても同じ反応・思考ができる既存のレビュー導線が損なわれない.
