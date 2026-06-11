# Acceptance Tests: workflow-detail.md のレビュー記述を #234 の動的・並列 Workflow パネルへ整合

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-001: Execution Mode 節のレビュー記述が現行アーキテクチャを伝える（US-1）

- [ ] [planned] AT-001: Execution Mode 節の Review step bullet がレガシー記述を含まず現行実装を記述する
  - Given: `docs/workflow/workflow-detail.md` の Execution Mode 節
  - When: Review step の bullet を検査する（`grep -n 'serially\|specialist reviewer subagents' docs/workflow/workflow-detail.md`）
  - Then: 「specialist reviewer subagents (PRD, User Story, Plan, Code, Acceptance Test) を serially spawn → final aggregator」の記述が存在せず、代わりに動的パネル生成（dynamically generated）・並列実行（in parallel / `parallel()` / `pipeline()`）・adversarial 検証・Aggregate による単一 PASS/FAIL + 観点別ノートの記述が存在する

## AT-002: Review Workflow 節の mermaid 図が現行フェーズ構成を描く（US-2）

- [ ] [planned] AT-002: mermaid 図と導入文が Scout / Generate / Review / Verify / Aggregate を描く
  - Given: `docs/workflow/workflow-detail.md` の旧 Reviewer Aggregation Flow 節（lines 97–120）
  - When: 節の導入文と mermaid 図を検査する（`grep -n '47 criteria\|prd-reviewer\|us-reviewer\|plan-reviewer\|code-reviewer\|at-reviewer\|final-reviewer\|dispatches five specialist reviewers' docs/workflow/workflow-detail.md`）
  - Then: 固定 5 reviewer（prd/us/plan/code/at）ノードと `final-reviewer: aggregate 47 criteria` ノードが存在せず、mermaid 図に Scout / Generate / Review (parallel) / Verify (adversarial) / Aggregate のフェーズノードと、Aggregate からの PASS → `ready-to-go` / FAIL → `needs-plan-revision` 分岐が存在する

## AT-003: ドキュメント全体にレガシー記述が残っていない（US-3）

- [ ] [planned] AT-003: 旧機構（固定 roster / serial / 47 基準）前提の記述が workflow-detail.md のどこにも残らない
  - Given: 置換後の `docs/workflow/workflow-detail.md` 全文
  - When: レガシー語彙を全文検索する（`grep -inE 'serial|specialist reviewer|47 criteria|aggregator' docs/workflow/workflow-detail.md`）
  - Then: ヒット 0 件であり、置換後の記述が `skills/reviewing-deliverables/SKILL.md`（#234 実装）のフェーズ名・実行形態と矛盾しない。回帰 pin として `tests/test_docs_restructure.bats` の #269 テストが green である

## AT-004: リリース規律 — CHANGELOG + patch bump（CS-1）

- [ ] [planned] AT-004: docs-only 変更でも CHANGELOG 更新と patch version bump を伴う
  - Given: 本 Issue の変更を含む PR #270 の diff
  - When: `CHANGELOG.md` と `.claude-plugin/plugin.json` を検査する
  - Then: CHANGELOG.md に `[3.11.2]` の `### Fixed` エントリ（#269 参照付き）が存在し、plugin.json の `version` が `3.11.2`（3.11.1 からの patch bump）で CHANGELOG 最新エントリと一致する

## AT-005: 変更スコープがドキュメント側に限定される（CS-2）

- [ ] [planned] AT-005: 実装と Non-Goals 対象ファイルに変更が波及していない
  - Given: 作業ブランチと main の差分（`git diff main --name-only`）
  - When: 変更ファイル一覧を検査する
  - Then: 変更が `docs/workflow/workflow-detail.md` / `CHANGELOG.md` / `.claude-plugin/plugin.json` / `tests/`（回帰 pin + README 同期）/ `docs/issues/269-*`（Issue 成果物）に限定され、`skills/reviewing-deliverables/SKILL.md` と `agents/` 配下に変更がない。agents/ レガシー記述は別 Issue が起票され追跡されている

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
