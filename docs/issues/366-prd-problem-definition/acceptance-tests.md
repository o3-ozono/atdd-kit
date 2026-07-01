# Acceptance Tests: defining-requirements / prd テンプレを 4 要素構造へ再編し問題定義品質規律を導入

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     regression AT は将来のブランチで永続実行されるため、時点固定値（現行 version・日付・行数）を
     アサートせず、不変条件（invariant）でアサートする。 -->

## AT-366-1: PRD テンプレが 4 要素構造の見出しを持つ（US-1）

- [x] [green] AT-366-1: `templates/docs/issues/prd.md` に新 4 要素の見出しが順に存在する
  - Given: 再編後の `templates/docs/issues/prd.md`
  - When: 見出し行を走査する
  - Then: `## 1. 基礎項目` / `## 2. 問題定義と背景` / `## 3. ゴールと成功指標` / `## 4. 機能要件` がこの順で存在し、旧見出し `## Problem` / `## Why now` / `## Outcome` / `## What` / `## Non-Goals` が単独見出しとして存在しない（`## Open Questions` は存続）

## AT-366-2: 問題定義節が事実欄と課題欄を分離している（US-1）

- [x] [green] AT-366-2: `## 2. 問題定義と背景` 節に「事実」欄と「課題」欄が別々に存在する
  - Given: 再編後の PRD テンプレ
  - When: 問題定義節の内部ラベル/小見出しを走査する
  - Then: 「事実」欄と「課題」欄が別々の明示ラベルとして存在し、両者を分けて書く旨のガイダンスコメントが含まれる

## AT-366-3: 品質規律 4 原則がテンプレ内に明示されている（US-1）

- [x] [green] AT-366-3: テンプレ内コメントに 4 原則が出現し出典/独自マーカーが付く
  - Given: 再編後の PRD テンプレ
  - When: コメント内の品質規律記述を検索する
  - Then: 「事実と課題の分離」「1 PRD=1（本質）課題」「観察可能なゴール」「下流からの還流」の 4 原則がすべて出現し、[独自] マーカーが「1 PRD=1 課題」と「下流からの還流」に付いている

## AT-366-4: anti-pattern 集がテンプレ内に存在する（US-1）

- [x] [green] AT-366-4: 4 種の anti-pattern が警告として記述されている
  - Given: 再編後の PRD テンプレ
  - When: anti-pattern コメントを走査する
  - Then: 「事実/課題の混在」「複数課題の同居」「内部完了条件のゴール」「観察不可能な成功指標」の 4 種が anti-pattern/警告として存在する

## AT-366-5: ゴール節が観察可能性の規律を持つ（US-1）

- [x] [green] AT-366-5: `## 3. ゴールと成功指標` に内部完了条件を禁じる規律がある
  - Given: 再編後の PRD テンプレ
  - When: ゴール節のガイダンスコメントを読む
  - Then: 内部完了条件（「〜を実装する」「〜ファイルを書く」）を不可とし、利用者側で観察可能な変化を求めるガイダンスが存在する

## AT-366-6: 機能要件節がスコープ外欄と優先度プレースホルダーを持つ（US-1）

- [x] [green] AT-366-6: `## 4. 機能要件` に Non-Goals 統合欄と優先度列プレースホルダーがある
  - Given: 再編後の PRD テンプレ
  - When: 機能要件節を走査する
  - Then: 「スコープ外」欄（旧 Non-Goals 統合）と優先度列（#367 方法論）のプレースホルダーが存在する

## AT-366-7: 旧 6 節 ↔ 新 4 要素の対応表が存在する（US-3）

- [x] [green] AT-366-7: テンプレ内に旧新対応表がある
  - Given: 再編後の PRD テンプレ
  - When: 対応表を検索する
  - Then: 旧 6 節（Problem / Why now / Outcome / What / Non-Goals / Open Questions）と新 4 要素の対応が読み取れる表がテンプレ内コメントに存在する

## AT-366-8: Open Questions 節が Resolved/Unresolved 管理ガイダンスを持つ（US-1）

- [x] [green] AT-366-8: `## Open Questions` に状態管理ガイダンスがある
  - Given: 再編後の PRD テンプレ
  - When: Open Questions 節のガイダンスコメントを読む
  - Then: Resolved / Unresolved を明示し未解決のみ列挙する旨のガイダンス（[独自]）が存在する

## AT-366-9: defining-requirements スキルが 4 要素構造の対話規律を持つ（US-2）

- [x] [green] AT-366-9: SKILL.md の Flow が 4 原則対応の問いかけと 1 質問ずつ規律を含む
  - Given: 更新後の `skills/defining-requirements/SKILL.md`
  - When: Flow セクションと冒頭説明を読む
  - Then: 基礎項目 / 問題定義（事実・課題分離）/ ゴール（観察可能）/ 機能要件（優先度）に対応する問いかけが存在し、「1 質問ずつ」「AskUserQuestion」規律が維持され、旧「6 sections」を前提とする誤導表現が残っていない

## AT-366-10: 既存 PRD 資産が旧 6 節形式のまま温存される（CS-2）

- [x] [green] AT-366-10: 既存 `docs/issues/*/prd.md` が本 Issue で書き換えられていない
  - Given: 本 Issue の変更差分
  - When: 既存 Issue（本 Issue 以外）の `docs/issues/*/prd.md` を確認する
  - Then: 既存 prd.md に変更差分がなく、旧 6 節形式のまま有効であり続ける（後方互換）

## AT-366-11: version と CHANGELOG が整合する（Finishing / 不変条件）

- [x] [green] AT-366-11: plugin.json の version が CHANGELOG 最上位リリース見出しと一致する
  - Given: 本 Issue マージ後の `.claude-plugin/plugin.json` と `CHANGELOG.md`
  - When: version と CHANGELOG の最上位リリース見出しを比較する
  - Then: 両者が一致する（時点固定値を pin せず invariant としてアサート — #289 教訓）

## AT-366-12: ドキュメント整合性 — templates/docs/issues/README.md が旧 6 節構造を前提にした記述を残していない（US-1/US-3）

- [x] [green] AT-366-12: `templates/docs/issues/README.md` が prd.md を新 4 要素構造で説明する
  - Given: 再編後の `templates/docs/issues/prd.md`
  - When: `templates/docs/issues/README.md` の prd.md 説明箇所を読む
  - Then: `Problem / Why now / Outcome / What / Non-Goals` の旧 6 節構造を前提にした記述（「6 セクション」等）が残っておらず、基礎項目 / 問題定義と背景 / ゴールと成功指標 / 機能要件の新 4 要素構造で説明されている

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
