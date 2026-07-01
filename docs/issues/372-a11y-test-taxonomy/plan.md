# Plan: docs/methodology/a11y-test-taxonomy.md 新設 — a11y テスト手段の3分割と「自動 green ≠ 達成」の明文化

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## Implementation

### ドキュメント本体（FS-1 / FS-2 / FS-3 / FS-4 / CS-1）

- [ ] `docs/methodology/a11y-test-taxonomy.md` を新規作成し、H1 タイトルと冒頭に `> **Loaded by:**` メタコメント（現状は参照スキルなしのため「(none yet — foundational reference)」等）を置く
- [ ] verify: ファイルが存在し、先頭に H1 と `> **Loaded by:**` 行がある（`head docs/methodology/a11y-test-taxonomy.md`）

- [ ] 「テスト手段の3分割」節を追加し、「自動・静的」「自動・操作」「手動」の3カテゴリを定義。各カテゴリのカバー対象・粒度・実行タイミング（unit / CI ゲート / E2E / design review）を表または箇条書きで記述し、[独自] 整理である旨を明示（FS-1）
- [ ] verify: 節見出しに「3分割」相当の文字列があり、3カテゴリ名すべてと「unit」「CI」「E2E」「design review」の各タイミング語が本文に含まれる

- [ ] 「自動 green ≠ a11y 達成」節を追加し、自動ツールが WCAG 違反の一部のみ検出する事実を Playwright docs・Deque 分析を一次情報として引用（URL 付き）し、手動 review を design review 必須ゲートとする理由を記述（FS-2 / CS-1）
- [ ] verify: 節に「自動 green」相当の文字列があり、Playwright と Deque の両方の参照（URL）が本文に含まれる

- [ ] 「適用基準」節を追加し、WCAG 2.2 AA を第一候補とする根拠と、JIS X 8341-3:2016 が WCAG 2.0 相当・版差（2.0 ↔ 2.2）に留意すべき旨の注記を記述（FS-3）
- [ ] verify: 節に「WCAG 2.2 AA」「JIS X 8341-3:2016」「WCAG 2.0」の各語と版差の注記が含まれる

- [ ] 「別軸の明示」節を追加し、テスト手段の分類（本ドキュメントの主題）と WCAG SC レベルトリアージが独立した設計判断軸であり混同しないことを明記（FS-4）
- [ ] verify: 節に「別軸」相当の記述と「トリアージ」の語があり、混同しない旨が明示される

## Testing

### BATS 構造検証テスト（FS-5）

- [ ] 既存 BATS 命名規約（`test_*_structure.bats`）に倣い `tests/test_a11y_taxonomy_structure.bats` を新規作成。先頭に `#!/usr/bin/env bats` と `# @covers: docs/methodology/a11y-test-taxonomy.md` を置く
- [ ] verify: `bats tests/test_a11y_taxonomy_structure.bats` が実行でき、少なくとも1件のテストが定義されている

- [ ] ファイル存在アサートと、4必須セクション（3分割・自動 green ≠ 達成・適用基準・別軸）それぞれの見出し/キーワードを `grep -q` で検証する `@test` を追加
- [ ] verify: `bats tests/test_a11y_taxonomy_structure.bats` が全 green（ドキュメント本体作成後）

## Finishing

### バージョニング規約（CS-2）

- [ ] `.claude-plugin/plugin.json` の version を patch +1（4.4.0 → 4.4.1）に bump
- [ ] verify: `plugin.json` の version が bump 後の値になっている

- [ ] `CHANGELOG.md` の最上部に本 Issue のエントリ（Added: a11y-test-taxonomy 方法論ドキュメント）を bump 後 version 見出しで追加
- [ ] verify: CHANGELOG 最上部リリース見出しの version が `plugin.json` version と一致する

### ドキュメント整合性チェック

- [ ] `docs/methodology/README.md` の Documents 表に新ドキュメント行を追加
- [ ] verify: README の Documents 表に `a11y-test-taxonomy.md` 行が存在する

- [ ] tests/ ディレクトリ README（存在する場合）に新 BATS ファイルの記載を追加し、全体 BATS スイートを流して既存退行がないことを確認
- [ ] verify: `bats tests/` がフル green（新規テスト含む・既存退行なし）
