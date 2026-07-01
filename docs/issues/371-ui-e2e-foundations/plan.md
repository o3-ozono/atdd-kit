# Plan: UI/E2E テスト基盤原則 doc 新設 — addon が継承する上段レイヤー + LLM 向け注入ルール集

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## Implementation

### US-1 / US-2 / US-3 / US-4: 上段原則 doc の新設

- [ ] `docs/methodology/testing/` ディレクトリを作成し、`ui-e2e-foundations.md` の骨組み（H1 タイトル + 各節の H2/H3 見出しのみ）を配置する
- [ ] verify: `docs/methodology/testing/ui-e2e-foundations.md` が存在し、`## 4 原則` / `## LLM 向けルール集` / `## 脚注` の 3 節見出しが `grep` で検出できる

- [ ] 原則 1「待機（Waiting）」節を執筆する（固定時間待ち禁止・自動待機・非 DOM 状態の明示的待機・リトライ可能アサーション）
- [ ] verify: `### 原則 1` 見出しと「固定時間待ち」「auto-waiting」「retry-ability」相当の記述が本文に含まれる

- [ ] 原則 2「要素の掴み方（Locators）」節を執筆する（優先順・禁止セレクタ hard rule・Testing Library 流派 vs Cypress 流派の根拠と trade-off・一 addon 内混在禁止 hard rule）
- [ ] verify: `### 原則 2` 見出しに加え、`role`・`data-testid`・`data-cy` の 3 語すべてと「混在」「hard rule」の語が本文に含まれる（US-3 の流派分岐と混在禁止を担保）

- [ ] 原則 3「構造化（Structure）」節を執筆する（Page/Screen Object 集約・Page Object にアサーションを置かない・Screenplay/State Object 発展形・テスト独立性）
- [ ] verify: `### 原則 3` 見出しと「Page Object」「Screenplay」「State Object」の語が本文に含まれる

- [ ] 原則 4「粒度（Granularity）」節を執筆する（テストピラミッド/トロフィー・E2E は少数 critical path・コンポーネント確認は Unit/Integration）
- [ ] verify: `### 原則 4` 見出しと「ピラミッド」「トロフィー」「critical path」の語が本文に含まれる

- [ ] 補助原則（`[独自]`）節を執筆する（1 テスト = その AC の観察可能な結果だけを assert / over-assertion・under-assertion 禁止）
- [ ] verify: `[独自]` マーカーが補助原則節に付いており、`grep -F '[独自]'` で検出できる（US-2 の独自マーカー要件を担保）

- [ ] LLM 向け do/don't ルール集節を執筆する（命令形・各ルールに `[hard rule]` マーカー・4 原則から直接導出した execution-ready な指示。例「`page.waitForTimeout()` を使うな。`expect(locator).toBeVisible()` を使え」）
- [ ] verify: `## LLM 向けルール集` 節配下に `[hard rule]` マーカー付きの命令形ルールが 4 原則分（4 件以上）存在する（US-4 を担保）

- [ ] 脚注ブロックに一次情報 9 出典（Playwright / Cypress Best Practices / Testing Library Queries / Fowler PageObject / Selenium POM / Serenity/JS Screenplay / van Deursen State Object / Vocke Practical Test Pyramid / Kent C. Dodds）を列挙し、各原則本文から脚注参照を張る
- [ ] verify: 脚注ブロックに 9 出典すべての識別語（Playwright, Cypress, Testing Library, Fowler, Selenium, Serenity, van Deursen, Vocke, Kent C. Dodds）が `grep` で検出できる（US-2 の脚注要件を担保）

### US-5: 各 addon ドキュメントの継承（参照）構造整備

- [ ] `addons/web/addon.yml` の `guidance` 節に `docs/methodology/testing/ui-e2e-foundations.md` への参照を追記し、プラットフォーム非依存原則を再掲していないことを確認する（web 固有補足は残す）
- [ ] verify: `addons/web/addon.yml` に `ui-e2e-foundations.md` の文字列が含まれ、原則本文（例「固定時間待ち禁止」）が web addon 内に重複記載されていない

- [ ] `addons/ios/README.md` に `ui-e2e-foundations.md` への参照を追記する（XCUITest 固有補足は残す）
- [ ] verify: `addons/ios/README.md` に `ui-e2e-foundations.md` の文字列が含まれる

- [ ] `addons/discord/README.md` に `ui-e2e-foundations.md` への参照を追記する（discord 固有補足は残す）
- [ ] verify: `addons/discord/README.md` に `ui-e2e-foundations.md` の文字列が含まれる

### ドキュメント index 整合

- [ ] `docs/methodology/README.md` に `testing/ui-e2e-foundations.md` へのエントリを追記する
- [ ] verify: `docs/methodology/README.md` に `ui-e2e-foundations` の文字列が含まれる

## Testing

### US-6: BATS 構造検証テストピンの追加

- [ ] `tests/test_ui_e2e_foundations.bats` を新設し、先頭に `@covers: docs/methodology/testing/ui-e2e-foundations.md` マーカーを付与する（check_bats_covers.sh が全 BATS に `@covers` を要求するため必須）
- [ ] verify: `tests/test_ui_e2e_foundations.bats` の先頭に `# @covers:` 行が存在する

- [ ] 必須節（原則 1〜4 の各見出し + `## LLM 向けルール集` 節 + `## 脚注` ブロック + `[hard rule]` マーカー存在 + `[独自]` マーカー存在）を検証する `@test` ケース群を記述する
- [ ] verify: `bats tests/test_ui_e2e_foundations.bats` が全ケース green

- [ ] 各 addon（web/ios/discord）が `ui-e2e-foundations.md` を参照していることを検証する `@test` を追加する（US-5 の継承構造を機械検証）
- [ ] verify: 3 つの参照検証ケースが green

- [ ] 既存 BATS 実行フローに組み込まれていることを確認する（`scripts/run-tests.sh --all` および check_bats_covers の integration gate に自動で拾われる）
- [ ] verify: `scripts/run-tests.sh --all` の対象に新 bats が含まれ green、かつ `tests/test_check_bats_covers.bats` の integration gate が green のまま

## Finishing

- [ ] `CHANGELOG.md` の最上段リリースブロックに本 doc 新設と addon 継承構造の整備を追記する
- [ ] verify: `CHANGELOG.md` の最上段リリースブロックに #371 相当のエントリが Keep a Changelog 形式で存在する

- [ ] ドキュメント整合性チェック（新 doc・addon 参照・methodology README・CHANGELOG が相互に矛盾しないこと）
- [ ] verify: `scripts/run-tests.sh --all` が全 green で、新旧ドキュメント間に dead link / 原則の重複記載が無い
