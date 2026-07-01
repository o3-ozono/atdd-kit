# Acceptance Tests: merging-and-deploying — retrospective の actionable findings を Issue 化する手順を正典化する

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

<!-- 本 Issue は docs / skill-content 変更。全 AT は SKILL.md / template の content invariant を
     アサートする（バージョン・日付・行数など時点固定値は pin しない）。実装は Step 4 所管。 -->

## AT-349-1: 壊れた/異常メトリクス → type:bug 起票の手順が SKILL.md にある

- [ ] [green] AT-349-1: SKILL.md Flow Step 5 に「壊れた/異常なメトリクス → `type:bug` 起票」の分類が明記されている
  - Given: `skills/merging-and-deploying/SKILL.md` の Report + Retrospective（Flow Step 5）セクション
  - When: retrospective.sh 出力の分類手順を読む
  - Then: 「壊れた」または「異常」なメトリクス（例として Dialogue Volume=0 等）を `type:bug` で起票する旨が記述されている

## AT-349-2: friction / improvement candidate → skill-fix 起票（atdd-kit:skill-fix 案内）

- [ ] [green] AT-349-2: SKILL.md に friction point / improvement candidate → skill-fix 起票と `atdd-kit:skill-fix` ルート案内がある
  - Given: SKILL.md の Flow Step 5 セクション
  - When: friction point / improvement candidate の扱いを読む
  - Then: skill-fix Issue を起票する旨と `atdd-kit:skill-fix` ルートの案内が記述されている

## AT-349-3: 非アクション → スキップの判定基準が明記されている

- [ ] [green] AT-349-3: SKILL.md に「非アクション → スキップ（起票不要）」と判定基準が明記されている
  - Given: SKILL.md の Flow Step 5 セクション
  - When: 起票不要となる非アクション所見の判定基準を読む
  - Then: 正常メトリクス・参考情報のみはスキップとし、明示的な異常値・閾値超え・エラーメッセージを含まないものを非アクションとする基準（曖昧時は人間が最終確認）が記述されている

## AT-349-4: 起票 Issue 番号のサマリ追記 + 全チャネル同期

- [ ] [green] AT-349-4: SKILL.md に起票 Issue 番号を retrospective サマリへ追記し terminal と Issue/PR コメント両方へ出力する旨がある
  - Given: SKILL.md の Flow Step 5 セクション
  - When: 起票後のサマリ反映手順を読む
  - Then: 起票した Issue 番号を retrospective サマリに追記し、terminal と Issue/PR コメントの両方へ同一内容を出力する（全チャネル同期）旨が記述されている

## AT-349-5: no-auto-routing / 人間最終確認の設計が明文化されている

- [ ] [green] AT-349-5: SKILL.md に auto-routing を行わず actionable 判定を人間が最終確認する旨がある
  - Given: SKILL.md の Flow Step 5 セクション
  - When: 自動化の有無と誤検出抑制の設計を読む
  - Then: auto-routing は行わず、actionable 判定の最終確認を人間が担う（誤検出抑制）旨が記述されている

## AT-349-6: retrospective テンプレートの "Improvement Candidates" 節が積極文言へ更新されている

- [ ] [green] AT-349-6: `templates/docs/issues/retrospective.md` の "Improvement Candidates" 節が 3 分類要点・番号追記・SKILL.md 参照へ更新され、旧消極注記が残っていない
  - Given: `templates/docs/issues/retrospective.md` の "Improvement Candidates" 節
  - When: 節の注記文言を読む
  - Then: 3 分類の要点（bug / skill-fix / skip）と「起票した番号を本サマリに追記する」旨、詳細は SKILL.md を権威とする旨が記述され、かつ旧文言 `No Auto-Routing: 候補を列挙するのみ。自動起票は行わない` が残っていない

## AT-349-7: scripts/retrospective.sh 本体・フォーマットに差分が入っていない（責務分離・regression）

- [ ] [green] AT-349-7: 本 Issue の変更が `scripts/retrospective.sh` に一切の差分を持ち込んでいない
  - Given: 本 Issue のブランチ diff（origin/main...HEAD）
  - When: 変更ファイル一覧を確認する
  - Then: `scripts/retrospective.sh` が変更ファイルに含まれない（#348 との責務重複なし・フォーマット不変）
  - <!-- [regression] 昇格時も不変（invariant）をアサートし、時点固定値は使わない -->

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
