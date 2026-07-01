# Acceptance Tests: docs/methodology/a11y-test-taxonomy.md 新設 — a11y テスト手段の3分割と「自動 green ≠ 達成」の明文化

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-372-1: テスト手段の3分割を参照できる（FS-1）

- [ ] [planned] AT-372-1: 3カテゴリと各実行タイミングが読み取れる
  - Given: `docs/methodology/a11y-test-taxonomy.md` が存在する
  - When: 「テスト手段の3分割」節を読む
  - Then: 「自動・静的」「自動・操作」「手動」の3カテゴリ名が定義され、各カテゴリのカバー対象・粒度・実行タイミングとして「unit」「CI」「E2E」「design review」が対応付けて記述されている

## AT-372-2: 「自動 green ≠ a11y 達成」を一次情報付きで確認できる（FS-2 / CS-1）

- [ ] [planned] AT-372-2: 一次情報引用と design review 必須化の根拠が読み取れる
  - Given: `docs/methodology/a11y-test-taxonomy.md` が存在する
  - When: 「自動 green ≠ a11y 達成」節を読む
  - Then: 自動ツールが WCAG 違反の一部のみ検出する事実が Playwright docs と Deque 分析の両方を一次情報（参照 URL 付き）として引用して記述され、手動 review を design review 必須ゲートとする理由が明示されている

## AT-372-3: 適用基準（WCAG 2.2 AA / JIS 版差）を参照できる（FS-3）

- [ ] [planned] AT-372-3: 適用基準節に基準と版差注記が読み取れる
  - Given: `docs/methodology/a11y-test-taxonomy.md` が存在する
  - When: 「適用基準」節を読む
  - Then: WCAG 2.2 AA を第一候補とする根拠が記述され、JIS X 8341-3:2016 が WCAG 2.0 相当であり版差（WCAG 2.0 ↔ 2.2）に留意が必要である旨の注記が含まれている

## AT-372-4: 「テスト手段の分け方」と「WCAG SC トリアージ」が別軸だと確認できる（FS-4）

- [ ] [planned] AT-372-4: 別軸の明示が読み取れる
  - Given: `docs/methodology/a11y-test-taxonomy.md` が存在する
  - When: 「別軸の明示」節を読む
  - Then: テスト手段の分類（本ドキュメントの主題）と WCAG SC レベルトリアージが独立した設計判断軸であり混同しないことが明記されている

## AT-372-5: ドキュメント構造を自動検証できる（FS-5）

- [ ] [planned] AT-372-5: BATS 構造検証テストが存在し green
  - Given: `tests/test_a11y_taxonomy_structure.bats`（または同等 BATS ファイル）が存在する
  - When: `bats tests/test_a11y_taxonomy_structure.bats` を実行する
  - Then: ファイル存在と4必須セクション（3分割・自動 green ≠ 達成・適用基準・別軸）の構造を検証する `@test` がすべて green になる

## AT-372-6: バージョニング規約の遵守（CS-2）

- [ ] [planned] [regression] AT-372-6: plugin.json version が CHANGELOG 最上部見出しと一致する
  - Given: 本 Issue のマージ後、`.claude-plugin/plugin.json` と `CHANGELOG.md` が更新されている
  - When: `plugin.json` の `version` と CHANGELOG 最上部のリリース見出しの version を比較する
  - Then: 両者が一致する（不変条件を検証。特定 version 値は pin しない — 後続 bump で post-merge regression が永久 red 化するのを防ぐ、#289）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
