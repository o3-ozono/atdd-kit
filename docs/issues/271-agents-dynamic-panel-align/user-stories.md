# User Stories: 固定 reviewer agents の存廃確定と agents/ 配下レガシー記述の #234 整合

## Functional Story

### US-1: 未使用の固定 reviewer agent 6 ファイルが削除されている

**I want to** Gate ① で確定した案 A（削除）のとおり `agents/{prd,us,plan,code,at,final}-reviewer.md` の 6 ファイルが削除されている,
**so that** 「Spawned by reviewing-deliverables skill」と自己申告する未使用 agent が Agent ツールのレジストリに常駐し続けず、誤って spawn される余地と将来の記述ドリフト（本 Issue の再発）が構造的になくなる.

### US-2: agents/README.md が現行実装を正しく説明する構成に再構成されている

**I want to** `agents/README.md` から固定 roster の表と Usage 節（「dispatches the five specialist reviewers … the final reviewer aggregates」）が削除され、(a) ディレクトリの現行役割（将来のカスタム agent 置き場）、(b) #259 モデル割り当てポリシー（autopilot SKILL.md から参照されている既存記述を維持）、(c) レビューは reviewing-deliverables の動的パネルが担う旨、の 3 点で再構成されている,
**so that** README を読んだセッションが現行実装（動的パネル + #259 モデルポリシー）どおりの実行像を得て、存在しない実行経路（固定 5 specialist → final-reviewer 47 基準集約）に誤誘導されない.

### US-3: docs / DEVELOPMENT / README のレガシー参照が現行記述に置換されている

**I want to** `docs/methodology/definition-of-ready.md`（prd-reviewer → 動的パネルの該当レンズ）、`docs/guides/getting-started.md`（固定 subagent 記述 → 動的パネル記述）、`DEVELOPMENT.md` / `DEVELOPMENT.ja.md`（Repository Structure・Agents 節・Reviewer Aggregation 言及）、`README.md` / `README.ja.md`（該当があれば）のレガシー参照が置換され、リポジトリ全体で `prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer` への参照が歴史的記録（CHANGELOG / docs/issues/）を除き 0 件になっている,
**so that** どのドキュメントをロードしたセッションも Step 5 を #234 の動的パネルとして理解し、#269 で実証されたレガシー記述による誤誘導パターンが agents/ 起点で再生産されない.

### US-4: 固定 6 agent 構造テストが「参照 0 件」回帰 pin に差し替えられている

**I want to** `tests/test_reviewer_subagents.bats`（#186 の固定 6 agent 構造 smoke test）が削除され、代わりに「固定 reviewer への参照が docs / skills / commands / rules に存在しない」ことを検証する回帰 pin テストが追加され、`tests/README.md` の該当行も更新されている,
**so that** 削除済み機構を前提とするテストが suite に残らず、将来レガシー参照が再混入したときに BATS が即座に検出する.

## Constraint Story (Non-Functional)

### CS-1: リリース規律（CHANGELOG `### Removed` + minor bump）を伴って出荷される

**I want to** `CHANGELOG.md` に `### Removed` エントリが追加され、`.claude-plugin/plugin.json` が **minor** bump（Gate ① で確定。agents はスキルではないため DEVELOPMENT.md のスキル rename = major 規定の対象外）されている,
**so that** プラグイン利用側が機能除去をリリース履歴から追跡でき、バージョンと配布内容の対応が崩れない.

### CS-2: BATS suite 全体が green の状態で出荷される

**I want to** テスト差し替え（US-4）を含む変更後も BATS suite 全体が green である,
**so that** 6 ファイル削除と参照置換が既存のテスト済み挙動（#259 モデルポリシー参照を含む）を壊していないことが機械的に保証される.

### CS-3: 変更が Non-Goals に波及しない

**I want to** `skills/reviewing-deliverables/SKILL.md`（現行実装が正）に変更がなく、`docs/issues/` / `CHANGELOG.md` の過去エントリ（歴史的記録）が書き換えられておらず、#259 モデル割り当てポリシーは内容変更なしで置き場所（agents/README.md）と参照（autopilot SKILL.md）が維持されている,
**so that** 「実装が正でありレガシー記述を実装へ整合させる」という本 Issue の方向が逆転せず、スコープ外の変更が混入しない.
