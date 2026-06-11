# Plan: workflow-detail.md のレビュー記述を #234 の動的・並列 Workflow パネルへ整合

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## 前提

- 変更対象は `docs/workflow/workflow-detail.md` のみ（CS-2）。`skills/reviewing-deliverables/SKILL.md`（現行実装 = 正）と `agents/` 配下には手を入れない。
- workflow-detail.md は LLM-facing ドキュメントのため、置換文は **英語**で書く（DEVELOPMENT.md Language 規約）。
- 置換内容の正は `skills/reviewing-deliverables/SKILL.md` の現行アーキテクチャ: Scout → Generate（動的レンズパネル）→ Review（並列、Workflow tool の `parallel()` / `pipeline()`）→ Verify（多ラウンド adversarial 検証）→ Aggregate（単一 PASS/FAIL + 観点別ノート）。
- design doc は作成しない（実装が正でありドキュメントを整合させるのみ。競合する選択肢なし）。

## Implementation

- [ ] Execution Mode 節 line 46 の bullet「**Review step** … spawns specialist reviewer subagents (PRD, User Story, Plan, Code, Acceptance Test) **serially**, then a final aggregator returns a single PASS/FAIL.」を現行実装の記述に置換する。置換文（英語）: `- **Review step** (\`reviewing-deliverables\`, Step 5) runs a **Workflow**: Scout inspects the deliverables, a reviewer panel is **generated dynamically** from the change, the lenses review **in parallel** (Workflow tool \`parallel()\` / \`pipeline()\`), findings are **adversarially verified**, and Aggregate returns a single PASS/FAIL plus per-lens notes.`
- [ ] verify: `grep -n 'serially' docs/workflow/workflow-detail.md` が 0 件、line 46 相当の bullet に `dynamically` / `in parallel` / `Aggregate` が含まれる

- [ ] Reviewer Aggregation Flow 節の導入文（line 99）「The review step dispatches five specialist reviewers, then a final reviewer aggregates their verdicts.」を現行フェーズ構成の説明に置換する。置換文（英語）: `The review step runs a dynamic parallel Workflow: Scout → Generate (dynamic lens panel) → Review (parallel) → Verify (adversarial) → Aggregate (single PASS/FAIL + per-lens notes).`
- [ ] verify: `grep -n 'dispatches five specialist reviewers' docs/workflow/workflow-detail.md` が 0 件

- [ ] 同節の mermaid 図（固定 5 reviewer prd/us/plan/code/at → `final-reviewer: aggregate 47 criteria`）を、Scout / Generate / Review (parallel) / Verify (adversarial) / Aggregate の 5 フェーズを描く flowchart に置換する（Aggregate から PASS → `ready-to-go` / FAIL → `needs-plan-revision` の分岐は維持）
- [ ] verify: `grep -n '47 criteria\|prd-reviewer\|final-reviewer' docs/workflow/workflow-detail.md` が 0 件、mermaid 内に `Scout` / `Generate` / `Review` / `Verify` / `Aggregate` ノードが存在する

- [ ] 節見出し「## Reviewer Aggregation Flow」を現行機構を表す「## Review Workflow Flow」へ変更する（旧「Aggregation = 47 基準集約」の含意を除去）
- [ ] verify: `grep -n '## Reviewer Aggregation Flow' docs/workflow/workflow-detail.md` が 0 件

- [ ] Execution Mode 節（lines 40–63）を通読し、旧機構（固定 roster / serial spawn / 47 基準）を前提とするその他の記述が残っていないか確認する。残存があれば同様に現行実装へ置換する（Quality Score / Guardrails 節など他節は PRD Non-Goals のため触らない）
- [ ] verify: `grep -inE 'serial|specialist reviewer|47 criteria|aggregator' docs/workflow/workflow-detail.md` が 0 件

## Testing

- [ ] `tests/test_docs_restructure.bats` に #269 回帰 pin を追加する（#267 pin と同形式）: (a) レガシー文言（`serially` / `dispatches five specialist reviewers` / `aggregate 47 criteria`）が workflow-detail.md に存在しないこと、(b) 新記述（dynamic panel / parallel / Scout〜Aggregate フェーズ）が存在すること
- [ ] verify: `bats tests/test_docs_restructure.bats` が green（既存 #267 pin 含む全件 PASS）

- [ ] `tests/README.md` の test_docs_restructure.bats 行を追加 pin 件数に同期する
- [ ] verify: `grep -n 'test_docs_restructure' tests/README.md` の記述が実ファイルのテスト数・内容と一致する

## Finishing

- [ ] `CHANGELOG.md` の `## [Unreleased]` 直下に `## [3.11.2]` の `### Fixed` エントリを追加する（#269: workflow-detail.md のレビュー記述を #234 の動的・並列 Workflow パネルへ整合）
- [ ] verify: `grep -n '3.11.2' CHANGELOG.md` がエントリを返し、Keep a Changelog 形式に沿っている

- [ ] `.claude-plugin/plugin.json` の version を `3.11.1` → `3.11.2` に bump する（docs-only 修正 = patch、CS-1）
- [ ] verify: `grep '"version"' .claude-plugin/plugin.json` が `3.11.2` を返し、CHANGELOG の最新エントリと一致する

- [ ] Gate ① 承認結果（PRD Open Question 2）に従い、`agents/` 配下のレガシー記述（agents/README.md Usage 節等の固定 5 specialist reviewer 前提 + ファイル群の存廃判断）を追跡する別 Issue を起票する（Refs #234 #269）
- [ ] verify: `gh issue list` に新規 Issue が存在し、本文が #234 Out of Scope 未消化分と #269 Non-Goals を参照している

- [ ] ドキュメント整合性チェック: 置換後の workflow-detail.md の記述が `skills/reviewing-deliverables/SKILL.md` のフェーズ構成・用語（Scout / Generate / Review / Verify / Aggregate、parallel() / pipeline()、PASS/FAIL + per-lens notes）と矛盾しないことを突き合わせる
- [ ] verify: 両ファイルのフェーズ名・実行形態（dynamic / parallel / adversarial）の記述が一致し、`git diff main --stat` の変更ファイルが workflow-detail.md / CHANGELOG.md / plugin.json / tests/ / docs/issues/269-\* に限定されている（CS-2）
