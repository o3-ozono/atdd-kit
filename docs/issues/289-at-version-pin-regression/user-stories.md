# User Stories: 恒久実行される acceptance AT のバージョン完全一致ピンを将来耐性のある検証へ置換する

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: AT-284 AT-010 のバージョン検証を将来耐性化する

**I want to** `tests/acceptance/AT-284.bats` の AT-010 が `.claude-plugin/plugin.json` の version を `"3.14.0"` で完全一致ピンする代わりに、(a) CHANGELOG に `## [3.14.0]` 見出しが存在すること、(b) `.claude-plugin/plugin.json` の version が CHANGELOG 最新リリース見出し（`## [Unreleased]` を除く先頭の `## [X.Y.Z]`）と一致すること、の 2 点で検証する,
**so that** #284 が当該版に bump した履歴事実を残しつつ、将来の version bump でこの AT が無関係に red 化しなくなる.

### US-2: AT-271 AT-005 の version 完全一致ピンを置換する

**I want to** `tests/acceptance/AT-271.bats` の AT-005 で、`[3.12.0]` 見出しと `### Removed` セクションの存在検証はそのまま残しつつ、`version == 3.12.0` の完全一致のみを「`.claude-plugin/plugin.json` version が CHANGELOG 最新リリース見出しと一致」へ置き換える,
**so that** #271 のリリース規律の履歴事実を維持したまま、v3.13.0 以降ずっと red だった既存破損を解消し、将来の bump でも green を保つ.

### US-3: AT-271 AT-006（全 suite 再帰実行）の green 化を確認する

**I want to** US-1・US-2 の修正により、`tests/acceptance/AT-271.bats` の AT-006（全 suite 再帰実行）が AT-006 自体の構造を変更せずに連鎖的に green 化することを確認する,
**so that** 時点依存ピンに連鎖して失敗していた suite 全体の再帰実行が信頼できる信号に戻る.

### US-4: 時点依存ピン再発防止ガイダンスを整備する

**I want to** `writing-plan-and-tests` / `running-atdd-cycle` のガイドに「`[regression]` として恒久実行される AT には、バージョン等の時点依存値を完全一致でピンしない」を明文化する,
**so that** 同種の時点依存ピンが新規 AT に混入するのを将来にわたって予防できる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### US-5: post-merge regression の信号信頼性を維持する

**I want to** 対象 AT が現在および将来の version bump 後も green を維持し、post-merge regression（`bats tests/acceptance/`）が version bump 起因で red 化しない,
**so that** regression suite が「常に red ＝無視してよいもの」と形骸化せず、本物の退行を検出できる信頼できる oracle であり続ける.
