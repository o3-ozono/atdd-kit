# Acceptance Tests: 固定 reviewer agents の存廃確定と agents/ 配下レガシー記述の #234 整合

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

実装形態: BATS（`tests/test_agents_dynamic_panel_align.bats` を中心に grep / ファイル存在検査で機械検証）。AT-006 / AT-007 の一部は suite 実行と `git diff` による検証手順。

## AT-001: 固定 reviewer agent 6 ファイルの削除（US-1）

- [x] [regression] AT-001: 未使用の固定 reviewer agent が存在しない
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `agents/{prd,us,plan,code,at,final}-reviewer.md` の存在を検査する
  - Then: 6 ファイルすべてが存在せず、`agents/` 直下は `README.md` のみである

## AT-002: agents/README.md の再構成（US-2）

- [x] [regression] AT-002a: レガシー Usage / 固定 roster の記述が消えている
  - Given: 再構成後の `agents/README.md`
  - When: `prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer|five specialist` を grep する
  - Then: ヒット 0 件である

- [x] [regression] AT-002b: 現行実装の 3 点構成が記述されている
  - Given: 再構成後の `agents/README.md`
  - When: 内容を検査する
  - Then: (a) ディレクトリの現行役割（将来のカスタム agent 置き場）、(b) #259 モデルポリシー（blockquote 文言は変更前と同一）、(c) レビューは reviewing-deliverables の動的パネルが担う旨、がすべて存在する

- [x] [regression] AT-002c: #259 モデルポリシー pin が無傷である
  - Given: 再構成後の `agents/README.md`
  - When: `bats tests/test_phase_model_assignment.bats` を実行する
  - Then: 7 件すべて green である

## AT-003: リポジトリ全体のレガシー参照 0 件（US-3）

- [x] [regression] AT-003a: docs / skills / commands / rules / ルート文書で参照 0 件
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `grep -rE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer|specialist reviewer|47 criteria'` を `agents/ docs/ skills/ commands/ rules/ README.md README.ja.md DEVELOPMENT.md DEVELOPMENT.ja.md` に対して実行する（`docs/issues/` は歴史的記録として `--exclude-dir=issues` で除外。パターンはファイル名を含まないレガシー表現も検知 — coverage gate 指摘対応）
  - Then: ヒット 0 件である

- [x] [regression] AT-003b: 個別文書が動的パネル記述に置換されている
  - Given: `docs/methodology/definition-of-ready.md` / `docs/guides/getting-started.md` / `DEVELOPMENT.md` / `DEVELOPMENT.ja.md` / `README.md` / `README.ja.md`
  - When: 各ファイルの置換箇所（DoR L30 / getting-started L130 / Agents 節・tree 注記 / Review 節・Step 5 行）を検査する
  - Then: 固定 reviewer・「specialist reviewer subagents」「47 criteria」前提の記述がなく、動的レンズパネル × 並列 Workflow（#234）として説明されている。肯定条件として 6 文書すべてが `dynamic|動的` への言及を持つことを実行可能 pin でも検査する（旧文言の不在 grep は AT-003a の拡張パターンが全域をカバー）

## AT-004: テスト差し替え（US-4）

- [x] [regression] AT-004a: 旧構造テストが削除されている
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `tests/test_reviewer_subagents.bats` の存在を検査する
  - Then: ファイルが存在しない

- [x] [regression] AT-004b: 回帰 pin テストが追加され green である
  - Given: 新規 `tests/test_agents_dynamic_panel_align.bats`（`# @covers: agents/**`）
  - When: `bats tests/test_agents_dynamic_panel_align.bats` を実行する
  - Then: 「6 ファイル不存在」「対象範囲でレガシー参照 0 件」「README に動的パネル言及あり」の pin がすべて green である

- [x] [regression] AT-004c: #105 テストが削除済みファイルを参照していない
  - Given: 更新後の `tests/test_issue_105_frontmatter_session_inheritance.bats`
  - When: 固定 reviewer 名を grep し、`bats` で実行する
  - Then: 固定 reviewer 名への参照 0 件かつ全件 green（README pin の AC3 × 2 件は維持されている）

- [x] [regression] AT-004d: tests/README.md が同期されている
  - Given: 更新後の `tests/README.md`
  - When: テスト一覧表を検査する
  - Then: test_reviewer_subagents.bats の行がなく、test_agents_dynamic_panel_align.bats の行があり、test_issue_105 行の説明が更新後の内容と一致する

## AT-005: リリース規律（CS-1）

- [x] [regression] AT-005: CHANGELOG `### Removed` + minor bump
  - Given: `CHANGELOG.md` と `.claude-plugin/plugin.json`
  - When: 新バージョンエントリと version 値を検査する
  - Then: `## [3.12.0]` に `### Removed` エントリ（refs #271）があり、plugin.json の version が `3.12.0`（3.11.3 から minor bump）である

## AT-006: BATS suite 全体 green（CS-2）

- [x] [regression] AT-006: suite 全体が green で出荷される
  - Given: 本 Issue の全変更（削除・置換・テスト差し替え・version bump）
  - When: `bats tests/` および `tests/acceptance/` 配下の AT ファイル（AT-271.bats 自身を除く）を実行する
  - Then: fail 0 件（`test_phase_model_assignment.bats` / `test_docs_restructure.bats` / `AT-269.bats` を含む既存 pin もすべて green）

## AT-007: Non-Goals 不可侵（CS-3）

- [x] [regression] AT-007: スコープ外変更が混入していない
  - Given: 本 Issue の変更内容
  - When: Non-Goals 対象を検査する
  - Then（実行可能 pin・ブランチ非依存）: `skills/autopilot/SKILL.md` / `skills/running-atdd-cycle/SKILL.md` からの `agents/README.md` 参照が維持されている（AT-271.bats AT-007）。`agents/README.md` の #259 ポリシー blockquote の内容は `tests/test_phase_model_assignment.bats`（7 pin）と AT-002b が文言レベルで恒久 pin
  - Then（手続き検証・merge gate 証跡）: `git diff main` で (i) `skills/reviewing-deliverables/SKILL.md` に差分なし、(ii) `CHANGELOG.md` の差分は新エントリ追加のみ、(iii) `docs/issues/` の差分は `271-agents-dynamic-panel-align/` 配下のみ — `git diff main` 依存の検査は #269→#272 で確立した教訓のとおり恒久回帰 pin にできない（マージ後の任意ブランチで false-fail する一回性保証）ため、本 PR の merge gate で手動検証し証跡を記録する

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
