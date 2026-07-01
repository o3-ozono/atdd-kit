# Acceptance Tests: UI/E2E テスト基盤原則 doc 新設 — addon が継承する上段レイヤー + LLM 向け注入ルール集

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     [regression] AT は将来の全ブランチで走り続けるため、時点値（版番号・日付・行数・出典の総数など）を
     exact-pin してはならない。invariant（不変条件）を assert すること。 -->

## AT-371-1: 上段 doc が存在し 3 大節を備える（US-1）

- [x] [regression] AT-371-1: `ui-e2e-foundations.md` が存在し必須 3 節を持つ
  - Given: リポジトリに `docs/methodology/testing/ui-e2e-foundations.md` が新設されている
  - When: BATS 構造検証テストがファイル存在と節見出しを検査する
  - Then: ファイルが存在し、`## 4 原則` / `## LLM 向けルール集` / `## 脚注` の 3 節見出しがすべて検出される

## AT-371-2: 4 原則の各見出しが揃っている（US-1）

- [x] [regression] AT-371-2: 原則 1〜4 の見出しが欠落なく存在する
  - Given: `ui-e2e-foundations.md` の `## 4 原則` 節
  - When: 原則 1（待機）・原則 2（要素の掴み方）・原則 3（構造化）・原則 4（粒度）の各見出しを検査する
  - Then: 4 つの原則見出しがすべて存在し、それぞれの本文が空でない

## AT-371-3: 一次情報 9 出典の脚注が付いている（US-2）

- [x] [regression] AT-371-3: 9 出典すべての識別語が脚注ブロックに存在する
  - Given: `## 脚注` ブロック
  - When: Playwright / Cypress / Testing Library / Fowler / Selenium / Serenity / van Deursen / Vocke / Kent C. Dodds の各識別語を検査する
  - Then: 9 出典すべての識別語が脚注ブロック内に存在する（不変条件として全語を assert。総数の数値ピンではなく「各語が居る」ことを検証）

## AT-371-4: `[独自]` マーカーが独自整理に付いている（US-2）

- [x] [regression] AT-371-4: 補助原則に `[独自]` マーカーが存在する
  - Given: 独自整理（補助原則: over/under-assertion 禁止）を含む doc
  - When: `[独自]` マーカーの存在を検査する
  - Then: `[独自]` マーカーが doc 内に少なくとも 1 箇所存在する

## AT-371-5: role/data-testid/data-cy の流派分岐が明記されている（US-3）

- [x] [regression] AT-371-5: 原則 2 に両流派の根拠と trade-off が併記される
  - Given: `### 原則 2`（要素の掴み方）節
  - When: `role` / `data-testid`（Testing Library 流派）と `data-cy`（Cypress 流派）の記述を検査する
  - Then: 3 語すべてが原則 2 節に含まれ、両流派の根拠・trade-off が併記されている

## AT-371-6: 一 addon 内でのセレクタ流派混在禁止が hard rule として明記されている（US-3）

- [x] [regression] AT-371-6: 混在禁止が hard rule として記述される
  - Given: `### 原則 2` 節
  - When: 「混在」禁止の記述と `hard rule` マーカーの共起を検査する
  - Then: 「一 addon 内での混在禁止」相当の記述が `hard rule` として明示されている

## AT-371-7: LLM 向けルール集が execution-ready な do/don't で `[hard rule]` 付き（US-4）

- [x] [regression] AT-371-7: `## LLM 向けルール集` 節に `[hard rule]` 付き命令形ルールが 4 原則分以上存在する
  - Given: `## LLM 向けルール集` 節
  - When: `[hard rule]` マーカー付きの命令形（do/don't）ルール数を検査する
  - Then: 4 原則から導出された `[hard rule]` 付きルールが少なくとも 4 件存在する（不変条件: 「各原則に対応する hard rule が居る」を assert。特定文言の完全一致ピンはしない）

## AT-371-8: 各 addon が上段 doc を参照している（US-5）

- [x] [regression] AT-371-8: web/ios/discord の 3 addon が `ui-e2e-foundations.md` を参照する
  - Given: `addons/web/addon.yml`（guidance 節）・`addons/ios/README.md`・`addons/discord/README.md`
  - When: 各ファイルに `ui-e2e-foundations.md` への参照が含まれるか検査する
  - Then: 3 addon すべてに参照文字列が存在する

## AT-371-9: プラットフォーム非依存原則が addon 側で再掲されていない（US-5 / CS-1）

- [x] [regression] AT-371-9: 原則本文が addon ドキュメントに重複記載されていない
  - Given: 上段 doc が単一ソースとして原則を保持する状態
  - When: addon の README / addon.yml に原則本文（例「固定時間待ち禁止」相当）が転記されていないか検査する
  - Then: addon 側には参照のみが存在し、プラットフォーム非依存原則の本文が重複記載されていない（単一ソース化の不変条件）

## AT-371-10: BATS 構造検証ピンが既存実行フローに組み込まれ green（US-6）

- [x] [regression] AT-371-10: 新 BATS がフルスイートで green かつ `@covers` gate を満たす
  - Given: `tests/test_ui_e2e_foundations.bats` が `# @covers:` マーカー付きで追加されている
  - When: `scripts/run-tests.sh --all` と check_bats_covers の integration gate を実行する
  - Then: 新 BATS の全ケースが green で、`@covers` 欠落による整合ゲート違反が発生しない

## AT-371-11: LLM 注入ルールが 4 原則から導出可能な状態にある（CS-2）

- [x] [regression] AT-371-11: ルール集の各 hard rule が 4 原則のいずれかに紐づく
  - Given: `## LLM 向けルール集` 節と `## 4 原則` 節
  - When: ルール集の各 `[hard rule]` が待機・掴み方・構造化・粒度のどの原則由来かをトレースする
  - Then: 4 原則すべてに対応する hard rule が存在し、原則との対応が読み取れる（前段コントロールが execution-ready である不変条件）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
