# User Stories: UI/E2E テスト基盤原則 doc 新設 — addon が継承する上段レイヤー + LLM 向け注入ルール集

## Functional Story

### US-1: 上段原則 doc の新設（4 原則 + LLM ルール集）

**I want to** `docs/methodology/testing/ui-e2e-foundations.md` に UI/E2E の 4 原則（待機・要素の掴み方・構造化・粒度）と LLM 向け do/don't ルール集を内蔵した上段 doc を用意する,
**so that** プラットフォーム非依存の原則を一箇所に集約し、addon ごとの独立実装・重複・食い違いを防げる.

### US-2: 一次情報の脚注と `[独自]` マーカーの付与

**I want to** 各原則に一次情報の脚注（Playwright / Cypress Best Practices / Testing Library Queries / Fowler PageObject / Selenium POM / Serenity/JS Screenplay / van Deursen State Object / Vocke Practical Test Pyramid / Kent C. Dodds）を付け、独自整理には `[独自]` マーカーを明示する,
**so that** 各原則の根拠が追跡可能になり、独自見解と一次情報由来の原則を読み手が区別できる.

### US-3: role vs `data-testid` 流派分岐の明記と一 addon 内混在禁止

**I want to** 要素の掴み方について Testing Library 流派（role 最優先・`data-testid` は最後の手段）と Cypress 流派（`data-cy` 専用属性を最優先）の両方の根拠と trade-off を明示し、上段 doc は特定流派を推奨せず「一 addon 内での混在禁止」を hard rule とする,
**so that** 各 addon が採用流派を自ら選び明示でき、かつ一つの addon 内でセレクタ方針が混在して破綻することを防げる.

### US-4: LLM 注入用 do/don't ルール集（execution-ready）

**I want to** LLM 向けルール集を命令形の do/don't 形式・各ルールに `[hard rule]` マーカー付き・4 原則から直接導出した実行可能な指示として整理する,
**so that** Claude が E2E テストコードを生成する前段に注入でき、生成物品質を LLM レビューではなくルール制約の段階でコントロールできる.

### US-5: 各 addon ドキュメントの継承（参照）構造整備

**I want to** `addons/web`・`addons/ios`・`addons/discord` の各 README または addon.yml guidance が `ui-e2e-foundations.md` を参照し、プラットフォーム非依存原則を再掲しない構造にする（addon 固有の補足は addon 側に残す）,
**so that** 上段原則の最新化コストが addon の数だけかからず、単一ソースで原則を一元管理できる.

### US-6: 必須節を検証する BATS 構造検証テストピンの追加

**I want to** `ui-e2e-foundations.md` の必須節（4 原則の各見出し + LLM 向けルール集節 + 脚注ブロック）が存在することを検証する BATS テストケースを追加し、既存の BATS 実行フローに組み込む,
**so that** 上段 doc の構造が将来の編集で欠落・退行しないことを機械的に保証できる.

## Constraint Story (Non-Functional)

### CS-1: プラットフォーム非依存原則の単一ソース化（一貫性）

**I want to** UI/E2E のプラットフォーム非依存原則が上段 doc という単一ソースに集約され、addon 側で再掲・重複しない状態が保たれている,
**so that** addon 間で原則が食い違うリスクが解消され、原則の最新化を一箇所の更新だけで完結できる.

### CS-2: LLM 生成品質の一貫性（前段コントロール）

**I want to** Claude が自律的に E2E を生成するとき前提として注入すべき原則が execution-ready なルール集として利用可能な状態にある,
**so that** セッションごとに生成物品質がばらつくことなく、ルール制約の段階で一定水準の E2E 生成品質を担保できる.
