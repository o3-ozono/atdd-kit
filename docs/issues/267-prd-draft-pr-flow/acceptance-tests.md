# Acceptance Tests: 成果物提示を Draft PR ベースに統一 — workflow-detail.md のレガシー記述矛盾と defining-requirements の承認後書き込み順序の修正

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

実装形態: 規定文言の構造検証（BATS pin）。実行可能 AT は既存スイートへの `@test` 追加として
`tests/test_docs_restructure.bats` / `tests/test_defining_requirements_skill.bats` /
`tests/test_autopilot_skill.bats` に実装する（Step 4 が `[planned]` → `[draft]` → `[green]` に進める）。

## AT-001: workflow-detail.md のレガシー記述が Workflow 表と整合する規定に置換されている（US-1）

- [ ] [planned] AT-001: Execution Mode 節からレガシー規定が消え、Draft PR ベースの規定が存在する
  - Given: `docs/workflow/workflow-detail.md` がリポジトリに存在する
  - When: Execution Mode 節の成果物提示規定を grep で検査する
  - Then: 旧文言 `never written to ad-hoc repository paths`（成果物は `gh issue comment` / `gh pr comment` 経由）が存在せず、「成果物はブランチコミット + Draft PR 差分、Issue/PR コメントは状態通知・承認依頼のみ」を意味する新規定が存在する

## AT-002: defining-requirements の Flow が draft 書き込み → commit/push → Draft PR → 承認ゲートの順序になっている（US-2）

- [ ] [planned] AT-002: Flow の順序が承認前書き込み + Draft PR 提示に変更されている
  - Given: `skills/defining-requirements/SKILL.md` の Flow 節
  - When: draft 書き込みステップ / commit・push・Draft PR 作成ステップ / 承認ゲートステップの出現行番号を比較する
  - Then: 行番号が「draft 書き込み < commit/push/Draft PR 作成 < 承認ゲート」の順であり、承認ゲートが PR 上のレビューを前提とした文言になっている（通常フロー・autopilot 共通の規定として記述されている）

## AT-003: autopilot Dialog economy に Gate ①/② の提示チャネル規定が追記されている（US-3）

- [ ] [planned] AT-003: Dialog economy 節に PR 差分ベース提示の規定が存在する
  - Given: `skills/autopilot/SKILL.md` の `## Dialog economy` 節
  - When: 節内の提示チャネル規定を grep で検査する
  - Then: Gate ①（要件承認）/ Gate ②（設計承認）とも成果物本体を Draft PR 差分として提示する規定が存在する

## AT-004: ターミナル提示は PR リンク + 判断が必要な点のみ（CS-1）

- [ ] [planned] AT-004: 全文展開禁止の規定が両スキルに存在する
  - Given: `skills/defining-requirements/SKILL.md` の承認ゲート規定と `skills/autopilot/SKILL.md` の Dialog economy 節
  - When: ターミナル出力に関する規定を grep で検査する
  - Then: いずれにも「ターミナルには PR リンクと判断が必要な点のみを提示し、成果物の全文展開をしない」を意味する規定が存在する

## AT-005: スキル変更が BATS pin で構造検証されている（CS-2）

- [ ] [planned] AT-005: 変更文言に対応する pin が追加され、全スイートが green
  - Given: AT-001〜AT-004 の pin が `tests/test_docs_restructure.bats` / `tests/test_defining_requirements_skill.bats` / `tests/test_autopilot_skill.bats` に追加済み
  - When: `bats tests/` を実行する
  - Then: 追加 pin を含む全テストが pass し、既存の line budget pin（defining-requirements ≤ 200 行、autopilot ≤ 260 行）も green のまま

## AT-006: 既存ルールの範囲内で実現され、全チャネル内容同期が維持されている（CS-3）

- [ ] [planned] AT-006: rules/atdd-kit.md は無変更で、同期規定は保持される
  - Given: 本 Issue の全変更がコミットされた作業ブランチ
  - When: `git diff main -- rules/atdd-kit.md` を実行し、承認依頼・状態通知の全チャネル同期規定（ターミナル + GitHub に同一内容）の保持を確認する
  - Then: `rules/atdd-kit.md` の diff が空であり、変更後の規定はいずれも成果物本体の置き場所のみを定め、判断材料の全チャネル同期を打ち消す文言を含まない

<!-- 実装開始後は [planned] → [draft] に変更する -->
<!-- テストが通過したら [draft] → [green] に変更する -->
<!-- リグレッション対象になったら [green] → [regression] に変更する -->

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
