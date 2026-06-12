# Acceptance Tests: session-start のプラグインバージョン検知 — RESTART_REQUIRED / STALE_SESSION の追加

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。本スキルは [planned] で起票する。 -->

## AT-001: RESTART_REQUIRED の検知（US-1 / 故障モード A）

- [ ] [planned] AT-001: 新版インストール済み + 旧版ロード中で RESTART_REQUIRED が出力される
  - Given: `PLUGIN_ROOT` の `plugin.json` が `3.11.1`（ロード版）、`installed_plugins.json` の `atdd-kit@atdd-kit` で当該 `projectPath` の `version` が `3.12.0`、マーカーは `3.11.1`（ロード版と一致 = 従来なら NO_UPDATE）
  - When: `check-plugin-version.sh "$ROOT" "$CACHE" "$INSTALLED_JSON" "$PROJECT_PATH"` を実行する
  - Then: 出力が 3 行 `RESTART_REQUIRED` / `3.11.1` / `3.12.0` で、マーカーファイルは `3.11.1` のまま不変

## AT-002: STALE_SESSION の検知とダウングレード抑止（US-2 / 故障モード B）

- [ ] [planned] AT-002: ロード版がマーカー版より古いとき STALE_SESSION が出力されマーカーは更新されない
  - Given: ロード版 `CURRENT=3.11.1`、マーカー `CACHED=3.12.0`（`CURRENT < CACHED`）
  - When: `check-plugin-version.sh` を実行する
  - Then: 出力が 3 行 `STALE_SESSION` / `3.11.1` / `3.12.0` で、マーカーは `3.12.0` のまま不変（逆向き UPDATED もマーカー書き戻しも起きない）

## AT-003: STALE_SESSION 時の E2 Auto-Sync スキップ配線（US-2・US-4）

- [ ] [planned] AT-003: session-start が STALE_SESSION を受けたとき E2 Auto-Sync を実行せず再起動を促す
  - Given: `skills/session-start/SKILL.md` の Phase 1-E / E2 配線、スクリプトが `STALE_SESSION` を返す状況
  - When: session-start の Phase 1-E 出力パースと E2 発火条件を評価する
  - Then: SKILL.md 上で STALE_SESSION 時に E2 Auto-Sync（deploy ファイル上書き）がスキップされ、レポートに「ロード版がマーカー版より古い — セッション再起動が必要」の再起動メッセージが表示される配線になっている

## AT-004: CHANGELOG 集計ガード（US-3）

- [ ] [planned] AT-004: UPDATED 経路で CACHED 見出しが CHANGELOG に無いとき件数が UNKNOWN になる
  - Given: ロード版 `CURRENT > CACHED`（UPDATED 経路）で、CHANGELOG に `## [<CACHED>]` 見出しが存在しない
  - When: `check-plugin-version.sh` を実行する
  - Then: 4 行目が `VERSIONS: UNKNOWN`（全エントリを数える `VERSIONS: 63` のような誤集計が出ない）。CACHED 見出しが存在する正常ケースでは従来どおり正しい数値件数が出る

## AT-005: session-start への RESTART_REQUIRED 出力プロトコル配線（US-4）

- [ ] [planned] AT-005: session-start が RESTART_REQUIRED を再起動メッセージとしてレポートに反映する
  - Given: `skills/session-start/SKILL.md` の Phase 1-E パース表、スクリプトが `RESTART_REQUIRED` を返す状況
  - When: Phase 1-E 出力パースと Phase 3 レポート生成を評価する
  - Then: SKILL.md に RESTART_REQUIRED（3 行）のパース行があり、Phase 3 レポートに「新版 v<installed> がインストール済み — セッション再起動で反映されます」が表示され、E2 Auto-Sync は実行されない

## AT-006: 後方互換フォールバック（CS-1）

- [ ] [planned] AT-006: installed_plugins.json が無い/パース不能/該当エントリなしでも従来トークンが壊れない
  - Given: (a) `installed_plugins.json` 不在、(b) パース不能な JSON、(c) 当該 `projectPath` のエントリなし、の 3 ケース
  - When: 各ケースで `check-plugin-version.sh` を実行する（マーカー状態は FIRST_RUN / NO_UPDATE / UPDATED 各相当）
  - Then: 3 ケースとも RESTART_REQUIRED を出さず、従来の `FIRST_RUN` / `NO_UPDATE` / `UPDATED` が壊れずに出力される

## AT-007: STALE_SESSION と RESTART_REQUIRED の同時成立時の優先順位（US-1・US-2 / OQ2）

- [ ] [planned] AT-007: ロード版 < マーカー版 かつ installed 版 > ロード版のとき STALE_SESSION が優先される
  - Given: `CURRENT=3.11.0`、`CACHED=3.11.1`（`CURRENT < CACHED`）、installed 版 `3.12.0`（`INSTALLED > CURRENT`）— STALE 条件と RESTART 条件が同時成立
  - When: `check-plugin-version.sh` を実行する
  - Then: 1 行目が `STALE_SESSION`（RESTART_REQUIRED より優先）で、マーカーは `3.11.1` のまま不変

## AT-008: 再起動後の正常系復帰（US-5）

- [ ] [planned] AT-008: RESTART_REQUIRED / STALE_SESSION 後に再起動した次セッションで正しい UPDATED が出る
  - Given: AT-001（RESTART_REQUIRED）または AT-002（STALE_SESSION）でマーカー非更新の状態。再起動後はロード版が installed 版 `3.12.0` に一致し、CHANGELOG に CACHED 見出しが存在する
  - When: 再起動後の次セッション相当で `check-plugin-version.sh` を実行する
  - Then: RESTART_REQUIRED / STALE_SESSION は出ず、従来どおり正しい CHANGELOG 件数付きの `UPDATED`（または該当時 `NO_UPDATE`）に復帰する

## AT-009: ネットワーク非依存・ローカル完結（CS-2）

- [ ] [planned] AT-009: すべての検知がネットワークアクセスなしでローカルファイルのみで完結する
  - Given: ネットワーク到達不能な環境（検知が参照するのは `installed_plugins.json` / マーカー / `plugin.json` / CHANGELOG のローカルファイルのみ）
  - When: 各検知経路（FIRST_RUN / NO_UPDATE / UPDATED / RESTART_REQUIRED / STALE_SESSION）を実行する
  - Then: 全経路がネットワークアクセスなしで決定的に同一結果を返す（スクリプトに外部ネットワーク呼び出しが存在しない）

## AT-010: 回帰防止とリリース衛生（CS-3）

- [ ] [planned] AT-010: 既存 BATS スイート green + 新規分岐テスト追加 + CHANGELOG/バージョン bump
  - Given: 本機能の feature PR
  - When: `bats tests/test_check_plugin_version.bats tests/test_session_start_version.bats` を実行し、`CHANGELOG.md` と `plugin.json` を確認する
  - Then: 既存テストが全 green、新規分岐（RESTART_REQUIRED / STALE_SESSION / 同時成立優先 / フォールバック / 集計ガード / 再起動後復帰）の BATS テストが追加されて green、`CHANGELOG.md` に Keep a Changelog 形式の本機能エントリがあり、`plugin.json` の version が bump 済み

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |

## US / AC → AT トレーサビリティ

| Story | AT |
|-------|-----|
| US-1（RESTART_REQUIRED） | AT-001, AT-005, AT-007 |
| US-2（STALE_SESSION / ダウングレード抑止） | AT-002, AT-003, AT-007 |
| US-3（CHANGELOG 集計ガード） | AT-004 |
| US-4（session-start 配線） | AT-003, AT-005 |
| US-5（再起動後の復帰） | AT-008 |
| CS-1（後方互換フォールバック） | AT-006 |
| CS-2（ネットワーク非依存） | AT-009 |
| CS-3（回帰防止・リリース衛生） | AT-010 |
