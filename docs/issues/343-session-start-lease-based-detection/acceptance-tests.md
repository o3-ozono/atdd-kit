# Acceptance Tests: session-start の「別セッション作業中」検出を branch-lease store ベースにする

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [green] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     実体は tests/acceptance/AT-343.bats（テンポラリ BRANCH_LEASE_DIR で exit-code ベース）。 -->

## AT-343: branch-lease store ベースの別セッション検出（Story 1）

- [ ] [green] AT-001: fresh な別セッション lease を保持する branch を検出する
  - Given: テンポラリ `BRANCH_LEASE_DIR` に branch `feat/x` の lease（`session_id` 非空・`timestamp` = 現在）を 1 件用意する
  - When: `scripts/session-lease-scan.sh` を実行する
  - Then: stdout に `feat/x` が 1 行出力され exit 0（検出は branch-lease store の fresh lease が根拠で Draft 状態に依存しない）

- [ ] [green] AT-002: lease が無い branch は検出しない
  - Given: 空のテンポラリ `BRANCH_LEASE_DIR`
  - When: ヘルパを実行する
  - Then: stdout 空・exit 0

## AT-343: 別セッション PR の read-only 表示と推薦除外（Story 2）

- [ ] [green] AT-003: 非 Draft・green・mergeable でも lease 保持 branch は検出される（中核回帰）
  - Given: branch `feat/ready` の fresh 別セッション lease を用意し、当該 PR が非 Draft・CI green・mergeable=MERGEABLE である状況を表現する
  - When: ヘルパを実行する
  - Then: stdout に `feat/ready` が含まれる（「非 Draft = ready = 推薦」「green = マージ」既定を上書きし、推薦対象から除外される根拠になる）

- [ ] [green] AT-004: SKILL.md が lease 保持 PR を read-only 表示・推薦除外と明記する
  - Given: `skills/session-start/SKILL.md`
  - When: Previous Work / Recommended Tasks / Task Recommendation Rules Step 1 を検査する
  - Then: `session-lease-scan` を参照し、ヘルパ出力 branch の open PR を `🔒 別セッション作業中` として read-only 表示・Recommended Tasks から除外する旨が、Draft/green/mergeable を問わず成立すると明記されている

## AT-343: Step 2.1 CONFLICTING rebase 推奨への lease 未保持前提条件（Story 3）

- [ ] [green] AT-005: Step 2.1 が lease 未保持を前提条件にする
  - Given: `skills/session-start/SKILL.md` の Step 2.1（CONFLICTING rebase 推奨）
  - When: 当該ルール本文を検査する
  - Then: 対象 branch がヘルパ出力に含まれない（別セッションの fresh lease を保持していない）ことが rebase 推奨の前提条件として明記され、かつ AT-316 が要求する `@me` / `非 Draft` 制限文言が維持されている

## AT-343: freshness 判定の二重定義禁止（Story 4）

- [ ] [green] AT-006: stale lease（TTL 超過）は検出しない
  - Given: branch `feat/old` の lease を `timestamp` = 現在 - (7200+60)s で用意する
  - When: ヘルパを実行する
  - Then: stdout に `feat/old` を含まない（freshness 判定が `BRANCH_LEASE_TTL_LOCAL` 既定 7200s に従う）

- [ ] [green] AT-007: TTL / encode を二重定義せずフックと同一 env・同一文字セットを使う
  - Given: `scripts/session-lease-scan.sh` と `hooks/branch-lease-guard.sh`
  - When: 両者の env 名と encode 文字セットを検査する
  - Then: ヘルパが `BRANCH_LEASE_DIR` / `BRANCH_LEASE_TTL_LOCAL` を同名で読み、encode が `%2F %2E %20 %23 %7E` の 5 文字セットを実装している（独自 TTL 既定・独自 encode を持たない）

## AT-343: store 本体非変更（Story 5）

- [ ] [green] AT-008: 検出は store を読むだけで write/delete しない
  - Given: テンポラリ `BRANCH_LEASE_DIR` に既存 lease ファイル 1 件
  - When: ヘルパを実行する
  - Then: 実行前後で `BRANCH_LEASE_DIR` 内のファイル一覧・各ファイル内容が不変（fresh lease に対し write_lease / delete_lease を呼ばない）

## AT-343: store 空/未稼働時の fail-safe（Story 6）

- [ ] [green] AT-009: store 未生成でも壊れず従来どおり
  - Given: 存在しないパスを `BRANCH_LEASE_DIR` に指定する
  - When: ヘルパを実行する
  - Then: exit 0・stderr へのエラー出力なし・stdout 空（新フォールバック機構を増やさない）

## AT-343: 回帰の exit-code ベース担保 + 不変条件（Story 7）

- [ ] [green] AT-010: AT-343 スイートが exit-code ベースで全 green
  - Given: `tests/acceptance/AT-343.bats`
  - When: `bats tests/acceptance/AT-343.bats` を実行する
  - Then: 全 test が green（検出系 AT は exit-code とヘルパ stdout で判定し、SKILL 系は grep で判定する）

- [ ] [green] AT-011: plugin.json version が CHANGELOG 最上位 release 見出しと一致する（点値ピン禁止 / #289）
  - Given: `.claude-plugin/plugin.json` と `CHANGELOG.md`
  - When: `helpers/changelog.bash` の `changelog_latest_release` でバージョン整合を検査する
  - Then: version が CHANGELOG 最上位 release 見出しと一致する（`== "3.x.x"` の固定値ピンを使わない不変条件アサーション）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [green] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
