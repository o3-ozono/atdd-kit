# PRD: UI/E2E テスト基盤原則 doc 新設 — addon が継承する上段レイヤー + LLM 向け注入ルール集

## Problem

`addons/{web,ios,discord}/` は各プラットフォーム個別の設定を保持しているが、**UI/E2E テストのプラットフォーム非依存の原則を集めた共有上段レイヤーが存在しない**。

現状の二つの課題：

1. **原則の散在・重複**：「固定時間待ち禁止」「role 優先セレクタ」「Page Object パターン」「テストピラミッド」などのプラクティスが各 addon ドキュメントに独立して書かれる（または書かれずに暗黙知化する）。内容が addon 間で食い違うリスクがあり、最新化コストも addon の数だけかかる。

2. **LLM 生成品質の非一貫性**：Claude に E2E テストコードを書かせるとき、前提として注入すべき原則がまとまった場所に無い。結果として、セッションごとに異なる品質の生成物が出る。`skills/ui-test-debugging/SKILL.md` は CI 失敗の診断手順であって原則集ではなく、このギャップを埋めるドキュメントが欠けている。

## Why now

`addons/web` の Playwright ベース E2E 整備と `addons/ios` の XCUITest 拡充が並行して進んでおり、**今この段階で上段原則を定めなければ addon ごとに原則が独立実装される**。一度 addon 側に書かれた原則は重複・競合が生じてから刈り取ることになり、コストが高くなる。

また、autopilot / full-autopilot の定着によって Claude が自律的に E2E を生成する頻度が増加している。前段コントロール（SKILL.md 実行前に注入するルール集）を確立することで、生成物品質を LLM レビューではなくルール制約の段階でコントロールできる。

## Outcome

以下の状態がすべて観察可能な形で達成されていること：

- `docs/methodology/testing/ui-e2e-foundations.md` が存在し、4 原則（待機・要素の掴み方・構造化・粒度）と LLM 向け do/don't ルール集を内蔵している
- 各原則には一次情報の脚注（Playwright / Cypress Best Practices / Testing Library Queries / Fowler PageObject / Selenium POM / Serenity/JS Screenplay / van Deursen State Object / Vocke Practical Test Pyramid / Kent C. Dodds）が付いており、独自整理には `[独自]` マーカーが明示されている
- 各 addon ドキュメントが上段 doc を参照（継承）し、同一原則を再掲しない構造になっている
- `ui-e2e-foundations.md` の必須節が存在することを検証する BATS テストピンが追加されている

## What

### 1. `docs/methodology/testing/ui-e2e-foundations.md` の新設

以下の節構成で作成する。

#### 4 原則

**原則 1 — 待機（Waiting）**
- 固定時間待ち（`sleep` / `wait(N ms)`）禁止。条件成立まで待つ自動待機（Playwright auto-waiting / Cypress retry-ability）を使う
- UI の「見える・有効・安定」以外の状態（API 完了・ストア更新・WebSocket 受信など非 DOM 状態）は明示的な待機条件を書く
- アサーションはリトライ可能な形式（web-first assertion / `should` チェーン）を使う
- 出典：Playwright Best Practices — Auto-waiting / Cypress Best Practices — Flake Avoidance

**原則 2 — 要素の掴み方（Locators）**
- **優先順**: role + アクセシブルネーム → ラベル / プレースホルダー / テキスト → `data-testid`
- **禁止（hard rule）**: CSS `id` / `class` / tag / `nth-child` / XPath / 自動生成クラス / レイアウト依存セレクタ
- **流派の分岐点を明記**：Testing Library は「ユーザーが見える属性から掴む → role 最優先、`data-testid` は最後の手段」。Cypress Best Practices は「`data-cy` 属性を専用属性として最優先」とする。本 doc はどちらの流派を採用するかは各 addon の判断に委ねるが、**両流派の根拠と trade-off を明示し、一 addon 内での混在を禁止する**
- 出典：Testing Library Queries — Priority / Cypress Best Practices — Selecting Elements

**原則 3 — 構造化（Structure）**
- 画面ごとの知識（URL・セレクタ・ナビゲーション操作）は Page Object（または Screen Object）に集約する
- **Page Object にアサーションを置かない**（アサーションはテスト側）
- 発展形：状態ベースの抽象が必要な場合は Screenplay Pattern（Serenity/JS）または State Object（van Deursen）を参照する
- 各テストは完全独立・実行順序非依存とする
- 出典：Fowler PageObject / Selenium POM / Serenity/JS Screenplay Pattern / van Deursen State Object

**原則 4 — 粒度（Granularity）**
- テストピラミッド（Fowler / Vocke）またはテストトロフィー（Kent C. Dodds）に従い、E2E は少数・critical path に絞る
- E2E で確認するのは「ユーザーが実際に操作する一連のフロー」であり、個別コンポーネントの挙動確認は Unit / Integration テストで行う
- 出典：Fowler TestPyramid / Vocke Practical Test Pyramid / Kent C. Dodds Testing Trophy

**補助原則（[独自]）**
- 1 テスト = その AC の観察可能な結果だけを assert（over-assertion 禁止 / under-assertion 禁止）

#### LLM 向けルール集（Claude 注入用）

- 命令形の do/don't 形式で記述する（例：「`page.waitForTimeout()` を使うな。`expect(locator).toBeVisible()` を使え」）
- 各ルールに `[hard rule]` マーカーを付ける
- 4 原則から直接導出された実行可能な指示として整理する（散文の要約ではなく execution-ready）

### 2. 各 addon ドキュメントの継承構造整備

- `addons/web/`・`addons/ios/`・`addons/discord/` の各 README または addon.yml guidance が `ui-e2e-foundations.md` を参照し、プラットフォーム非依存原則を再掲しない記述になっていること
- addon 固有の補足（例：Playwright の `getByRole` 具体例、XCUITest での `accessibilityIdentifier` 対応）は addon 側に残してよい

### 3. BATS 構造検証テストピンの追加

- `ui-e2e-foundations.md` に必須節（4 原則の各見出し + LLM 向けルール集節 + 脚注ブロック）が存在することを検証する BATS テストケースを追加する
- 既存の BATS 実行フローに組み込む

## Non-Goals

- **各 addon の E2E テストコード自体の変更**：本 Issue は doc とルール整備であり、既存テストコードのリファクタリングは別 Issue で扱う
- **iOS（XCUITest）・Discord 固有の selector / driver API の詳細化**：ツール固有の具体例は addon 側ドキュメントの責務。本 Issue は抽象原則層の確立のみ
- **Playwright / Cypress の設定ファイルの変更**：設定自体には手を入れない
- **LLM 向けルール集を SKILL.md に埋め込む作業**：本 Issue で作成するのは独立 doc。SKILL.md への参照挿入は別途検討する

## Open Questions

1. **role vs `data-testid` の優先順位：どちらの流派を上段 doc が「推奨」とするか**
   → **Resolved（Gate ① 承認）**: 流派が割れる事実を明記し、「一 addon 内での混在禁止」を hard rule とする。上段 doc は特定流派を推奨しない。各 addon が採用する流派を明示することを義務付ける。

2. **doc の最終パス名**
   → **Resolved（Gate ① 承認）**: `docs/methodology/testing/ui-e2e-foundations.md` で確定。

3. **addon の継承構造：addon.yml の `guidance` 節に書くか、addon 内の README.md に書くか**
   → **Resolved（Gate ① 承認）**: addon 固有のフォーマット制約（web=addon.yml guidance、ios=README、discord=README）に合わせ、各 addon の既存構造を壊さない形で参照を挿入する。実装判断は plan フェーズに委ねる。
