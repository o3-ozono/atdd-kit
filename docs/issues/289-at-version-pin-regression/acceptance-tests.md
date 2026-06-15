# Acceptance Tests: 恒久実行される acceptance AT のバージョン完全一致ピンを将来耐性のある検証へ置換する

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-289-1: AT-284 AT-010 のバージョン検証が将来耐性化されている（US-1）

- [x] [regression] AT-289-1: AT-284 AT-010 が完全一致ピンではなく履歴事実＋最新リリース見出し整合で検証する
  - Given: `tests/acceptance/AT-284.bats` の旧 `@test "AT-010: plugin.json version is 3.14.0"`（`grep -q '"version": "3.14.0"'` の完全一致）を書き換えた状態
  - When: `bats tests/acceptance/AT-284.bats` を実行する
  - Then: 当該 AT-010 テストが green になる。検証内容は (a) CHANGELOG に `## [3.14.0]` 見出しが存在すること、(b) plugin.json の version が CHANGELOG 最新リリース見出し（`## [Unreleased]` を除く先頭の `## [X.Y.Z]`）と一致すること、の 2 点であり、特定バージョン文字列の完全一致ピンを含まない

## AT-289-2: AT-271 AT-005 の version 完全一致ピンが置換されている（US-2）

- [x] [regression] AT-289-2: AT-271 AT-005 が履歴事実を維持したまま完全一致ピンを最新リリース見出し整合へ置換する
  - Given: `tests/acceptance/AT-271.bats` の AT-005 で `[[ "$version" == "3.12.0" ]]` の完全一致ブロックを書き換え、`[3.12.0]` 見出し存在検証と `### Removed` 存在検証は残した状態
  - When: `bats tests/acceptance/AT-271.bats` を実行する
  - Then: AT-005 相当テストが green になる。`[3.12.0]` ＋ `### Removed` の履歴事実検証は維持されており、version は CHANGELOG 最新リリース見出しとの一致で検証され、`3.12.0` 完全一致ピンは残っていない

## AT-289-3: AT-271 AT-006（全 suite 再帰実行）が連鎖的に green 化する（US-3）

- [x] [regression] AT-289-3: AT-006 の構造を変えずに全 suite 再帰実行が green になる
  - Given: AT-289-1・AT-289-2 の修正を適用し、AT-271 AT-006（L301-324）の構造は未変更の状態
  - When: `bats tests/acceptance/AT-271.bats` を実行する
  - Then: AT-006（配下の AT-284.bats を含む全 suite の再帰実行）が fail 0 件で green になる

## AT-289-4: 時点依存ピン再発防止ガイダンスが整備されている（US-4）

- [x] [regression] AT-289-4: 両 SKILL.md に時点依存ピン禁止のガイダンスが明文化されている
  - Given: `skills/writing-plan-and-tests/SKILL.md` と `skills/running-atdd-cycle/SKILL.md` を編集した状態
  - When: 両ファイルを参照する
  - Then: 「`[regression]` として恒久実行される AT には、バージョン等の時点依存値を完全一致でピンしない（履歴事実＋最新リリース見出しとの整合で書く）」旨のガイダンスが両ファイルに存在する

## AT-289-5: post-merge regression が version bump 起因で red 化しない（US-5・NFR）

- [x] [regression] AT-289-5: 現状および将来の version bump 後も対象 AT が green を維持する
  - Given: 本 Issue の全修正を適用した状態。さらに plugin.json version を疑似的な次版へ、CHANGELOG 先頭に対応する `## [X.Y.Z]` 見出しを追加した（疑似 bump）状態
  - When: `bats tests/acceptance/`（現状）および疑似 bump 状態での `bats tests/acceptance/AT-271.bats tests/acceptance/AT-284.bats` を実行する
  - Then: いずれも fail 0 件で green。version bump によって対象 AT が red 化しない（regression 信号が bump に対して安定）

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
