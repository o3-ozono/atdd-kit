# Plan: 固定 reviewer agents の存廃確定と agents/ 配下レガシー記述の #234 整合

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## 方針メモ

- Gate ① 確定事項（PRD Open Questions, Resolved 2026-06-11）: **案 A（6 ファイル削除）採用、version は minor**。
- 実装が正。`skills/reviewing-deliverables/SKILL.md` は変更しない（CS-3）。
- `agents/README.md` の **#259 モデルポリシー blockquote は一字も変更しない**。`tests/test_phase_model_assignment.bats` と `tests/test_issue_105_frontmatter_session_inheritance.bats` AC3 が文言を pin しており、`skills/autopilot/SKILL.md:240` / `skills/running-atdd-cycle/SKILL.md:24` から参照されている。
- レガシー参照の残存箇所（事前 grep 棚卸し済み）: `agents/*.md` 6 ファイル + `agents/README.md`、`README.md`（L22 / L89 / L130-141「Review Subagents」節）、`README.ja.md`（L24 / L91 / L132-143）、`DEVELOPMENT.md`（L87 Agents 節 / L140 tree 注記）、`DEVELOPMENT.ja.md`（同 L87 / L140）、`docs/methodology/definition-of-ready.md`（L30）、`docs/guides/getting-started.md`（L130）、`tests/test_reviewer_subagents.bats`、`tests/test_issue_105_frontmatter_session_inheritance.bats`（AC1/AC2 が削除対象 6 ファイルを loop）、`tests/README.md`（L53）。`CHANGELOG.md` / `docs/issues/` は歴史的記録として不変。
- 設計ドキュメントは作らない: 存廃トレードオフは Gate ① で確定済みで PRD Open Questions に記録されているため。

## Implementation

### US-1: 固定 reviewer agent 6 ファイルの削除

- [ ] `git rm agents/prd-reviewer.md agents/us-reviewer.md agents/plan-reviewer.md agents/code-reviewer.md agents/at-reviewer.md agents/final-reviewer.md` を実行する
- [ ] verify: `ls agents/` の出力が `README.md` のみ

### US-2: agents/README.md の再構成

- [ ] `agents/README.md` を再構成する: 「Available Agents」固定 roster 表と「Usage」節（「dispatches the five specialist reviewers … the final reviewer aggregates」）を削除し、(a) ディレクトリの現行役割（将来のカスタム agent 置き場。現在 agent 定義ファイルなし）、(b) #259 モデルポリシー blockquote（既存記述を**そのまま**維持）、(c) レビューは `reviewing-deliverables`（Step 5）の動的レンズパネル × 並列 Workflow が担う旨（#234）、の 3 点構成にする。「Frontmatter Fields」表は将来のカスタム agent 規約として存置してよい
- [ ] verify: `grep -cE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer|five specialist' agents/README.md` が 0、かつ `grep -qi 'dynamic' agents/README.md && grep -qF 'Sonnet 1.0 : Opus 2.2 : Fable 4.1' agents/README.md` が成功

- [ ] `bats tests/test_phase_model_assignment.bats` を実行し #259 pin が無傷であることを確認する
- [ ] verify: 7 件すべて green

### US-3: docs / DEVELOPMENT / README のレガシー参照置換

- [ ] `docs/methodology/definition-of-ready.md` L30 の「The prd-reviewer (spawned by reviewing-deliverables, Step 5) checks R1–R5」を動的パネル記述（例: reviewing-deliverables (Step 5) の動的レビューパネルの該当レンズ（documentation / functional-correctness 等）が R1–R5 を検査する）に置換する
- [ ] verify: `grep -c 'prd-reviewer' docs/methodology/definition-of-ready.md` が 0、`grep -qi 'panel\|lens' docs/methodology/definition-of-ready.md` が成功

- [ ] `docs/guides/getting-started.md` L130 の「It spawns dedicated reviewer subagents (such as `code-reviewer` and `at-reviewer`) …」を現行記述（deliverable 内容から動的に生成されたレビューパネルを並列 Workflow で実行し、AC に照らして検査する）に置換する
- [ ] verify: `grep -cE 'code-reviewer|at-reviewer|dedicated reviewer subagents' docs/guides/getting-started.md` が 0

- [ ] `DEVELOPMENT.md` L87 の Agents 節を書き換える: 「Reviewer role definitions live in `agents/`, spawned by …」→ `agents/` は将来のカスタム agent 置き場（現在 agent 定義ファイルなし）であり、レビューは reviewing-deliverables の動的パネルが担う旨 + モデルポリシーは `agents/README.md` 参照
- [ ] verify: `sed -n '85,90p' DEVELOPMENT.md` に reviewer role / spawn 前提の記述がなく、dynamic panel への言及がある

- [ ] `DEVELOPMENT.md` L140 の tree 注記「# Reviewer role definitions (prd/us/plan/code/at/final-reviewer) spawned by reviewing-deliverables」を「# Custom agent definitions (currently README only; review uses dynamic panels — #234)」相当に置換する
- [ ] verify: `grep -c 'final-reviewer' DEVELOPMENT.md` が 0

- [ ] `DEVELOPMENT.ja.md` L87（Agents 節）と L140（tree 注記）に同内容の日本語修正を適用する
- [ ] verify: `grep -cE 'prd-reviewer|final-reviewer|spawn する' DEVELOPMENT.ja.md` の固定 reviewer 参照が 0、英日で記述内容が対応している

- [ ] `README.md` の「### Review Subagents」節（L130-141: 導入文 + 6 agent 表）を「### Review Workflow（動的レンズパネル）」相当に差し替える: Scout → Generate（動的パネル）→ Review（並列）→ Verify（敵対検証）→ Aggregate（PASS/FAIL）の現行フローを 3-6 行で記述し、固定 roster 表を削除する
- [ ] verify: `grep -cE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer|47 criteria|six specialist' README.md` が 0

- [ ] `README.md` L22（「spawns specialist reviewer subagents」）と L89（Step 5 行「Serially review … with specialist reviewer subagents」）を動的パネル × 並列の現行記述に置換する
- [ ] verify: `grep -ci 'specialist reviewer' README.md` が 0

- [ ] `README.ja.md` に同内容の日本語修正を適用する（L24 / L91 / L132-143「### Reviewer Subagent」節）
- [ ] verify: `grep -cE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer|専門 reviewer subagent' README.ja.md` が 0

- [ ] リポジトリ全体の残存参照を棚卸しする: `grep -rEl 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer' --exclude-dir=.git .` を実行する
- [ ] verify: ヒットが歴史的記録（`CHANGELOG.md` / `docs/issues/`）と workflow-detail.md 向け否定 grep テスト（`tests/acceptance/AT-269.bats` / `tests/test_docs_restructure.bats`）と本 Issue の新規回帰 pin テストのみ

## Testing

### US-4: テスト差し替え

- [ ] `git rm tests/test_reviewer_subagents.bats` を実行する（#186 の固定 6 agent 構造 smoke test）
- [ ] verify: `test ! -f tests/test_reviewer_subagents.bats`

- [ ] `tests/test_issue_105_frontmatter_session_inheritance.bats` を更新する: 削除済み 6 ファイルを loop する AC1/AC2 を「`agents/` 配下に README.md 以外の `*.md`（agent 定義）が存在する場合、その frontmatter に `model:` / `effort:` がない」形（または agents/ 全 `*.md` glob ベース）に書き換え、README.md を pin する AC3 × 2 件は無変更で維持する
- [ ] verify: `grep -cE 'prd-reviewer|final-reviewer' tests/test_issue_105_frontmatter_session_inheritance.bats` が 0、`bats tests/test_issue_105_frontmatter_session_inheritance.bats` が green

- [ ] 新規 `tests/test_agents_dynamic_panel_align.bats`（`# @covers: agents/**` ヘッダ付き）を作成し、回帰 pin を実装する: (a) `agents/{prd,us,plan,code,at,final}-reviewer.md` の 6 ファイルが存在しない、(b) `grep -rE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer'` が `agents/ docs/ skills/ commands/ rules/ README.md README.ja.md DEVELOPMENT.md DEVELOPMENT.ja.md` で 0 件（`docs/issues/` は歴史的記録として除外）、(c) `agents/README.md` にレガシー Usage 文言（`five specialist`）がなく動的パネルへの言及がある
- [ ] verify: `bats tests/test_agents_dynamic_panel_align.bats` が green

- [ ] `tests/README.md` を同期する: L53 の test_reviewer_subagents.bats 行を削除し、新規 test_agents_dynamic_panel_align.bats の行を追加し、L176 の test_issue_105 行の説明を更新後の内容に合わせる
- [ ] verify: `grep -c 'test_reviewer_subagents' tests/README.md` が 0、`grep -c 'test_agents_dynamic_panel_align' tests/README.md` が 1

- [ ] `tests/test_tightening_protection.bats` の AC2a を修正する: `agents/[^R]*.md` glob が固定 reviewer agents 削除後にマッチなしでリテラル文字列展開される bash の挙動（`grep: agents/[^R]*.md: No such file or directory`）により AC2a が FAIL するため、guard を追加して「対象ファイルが存在しない場合は skip」する形に書き換える
- [ ] verify: `bats tests/test_tightening_protection.bats` が green

- [ ] BATS suite 全体を実行する: `bats tests/ tests/acceptance/`（CS-2）
- [ ] verify: 全件 green（fail 0）

## Finishing

### CS-1: リリース規律

- [ ] `CHANGELOG.md` の `## [Unreleased]` 下に新バージョン `## [3.12.0]` を起こし、`### Removed` エントリ（固定 reviewer agents 6 ファイル削除 + agents/README.md 再構成 + レガシー参照置換 + テスト差し替え、refs #271 #234 #269）を追加する
- [ ] verify: `grep -A3 '\[3.12.0\]' CHANGELOG.md` に `### Removed` が含まれる

- [ ] `.claude-plugin/plugin.json` の version を `3.11.3` → `3.12.0` に bump する（minor — Gate ① 確定）
- [ ] verify: `grep '"version"' .claude-plugin/plugin.json` が `3.12.0`

### CS-3: Non-Goals 不可侵の確認

- [ ] `git diff main --stat` でスコープを確認する
- [ ] verify: `skills/reviewing-deliverables/SKILL.md` が diff に**含まれない**こと、`CHANGELOG.md` の差分が新エントリ追加のみであること、`docs/issues/` の差分が `271-agents-dynamic-panel-align/` 配下のみであること

- [ ] #259 ポリシーの置き場所・参照の維持を確認する
- [ ] verify: `agents/README.md` のモデルポリシー blockquote が変更前と同一文字列（`git diff main -- agents/README.md` で blockquote 行に差分なし）、`grep -n 'agents/README.md' skills/autopilot/SKILL.md skills/running-atdd-cycle/SKILL.md` が引き続きヒット

- [ ] ドキュメント整合性チェック（README / DEVELOPMENT / docs の英日対と CHANGELOG）
- [ ] verify: 変更した英語ドキュメントすべてに対応する日本語版の修正があり、`docs/guides/doc-sync-checklist.md` の観点で漏れがない
