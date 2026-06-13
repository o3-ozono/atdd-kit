# PRD: 恒久実行される acceptance AT のバージョン完全一致ピンを将来耐性のある検証へ置換する

## Problem

**現状**: `tests/acceptance/` 配下の一部 AT が、その時点の plugin バージョン文字列を完全一致（exact-match）でピンしている。

| テスト | ピン値 | 状態 |
|--------|--------|------|
| `tests/acceptance/AT-284.bats` L187 `AT-010: plugin.json version is 3.14.0` | `"version": "3.14.0"` 完全一致 | v3.14.1 バンプで破損 |
| `tests/acceptance/AT-271.bats` L295 `AT-005` | `version == 3.12.0` 完全一致 | v3.13.0 以降ずっと既存 red |
| `tests/acceptance/AT-271.bats` L322 `AT-006`（全 suite 再帰実行） | — | 上記 AT-284 ピンに連鎖して失敗 |

**それによって何が困るか**: これらの AT は merge ごとの post-merge regression（`merging-and-deploying`）で恒久的に実行されるが、version bump のたびに無関係に red 化する。regression が「常に red」だと本物の退行を検出できなくなる（オオカミ少年化）。CI（skill-tests）は `tests/acceptance/` を実行しないため、この破損は post-merge regression まで顕在化しない。実際 #277（v3.14.1）merge 後の regression で 3 件失敗が検出され、すべて時点依存ピン起因だった。

## Why now

#277 の post-merge regression で本問題が顕在化し、AT-271 AT-005 は v3.13.0 以降ずっと red のまま放置されていたことが判明した。regression が恒常 red の状態が続くほど、regression suite 全体が「無視してよいもの」として形骸化し、本物の退行を見逃すリスクが累積する。version bump は今後も毎リリース発生するため、時点依存ピンを残す限り破損は再発し続ける。早期に断ち切る必要がある。

## Outcome

- `tests/acceptance/AT-284.bats` / `AT-271.bats` のバージョン関連 AT が、現在および将来の version bump 後も green を維持する（plugin.json version を完全一致でハードコードしない）。
- post-merge regression（`bats tests/acceptance/`）が version bump 起因で red 化しない＝ regression の信号が信頼できる状態に戻る。
- 同種の時点依存ピンの再発を防ぐガイダンスが整備される（What で確定）。

## What

1. **AT-284 AT-010 の書き換え**: `plugin.json` の version を `"3.14.0"` で完全一致ピンする代わりに、(a) CHANGELOG に `## [3.14.0]` 見出しが存在すること（#284 が当該版に bump した履歴事実 — append-only な履歴なので将来も不変）、(b) plugin.json の version が CHANGELOG 最新リリース見出し（`## [Unreleased]` を除く先頭の `## [X.Y.Z]`）と一致すること、の 2 点で検証する。
2. **AT-271 AT-005 の書き換え**: `[3.12.0]` 見出しと `### Removed` セクションの存在（#271 のリリース規律の履歴事実 — 維持）はそのままに、`version == 3.12.0` の完全一致のみを「plugin.json version が CHANGELOG 最新リリース見出しと一致」へ置換する。
3. **AT-271 AT-006（全 suite 再帰実行）**: 上記 1・2 の修正により連鎖的に green 化することを確認する（AT-006 自体の構造は変更しない）。
4. **再発防止ガイダンス**: `writing-plan-and-tests` / `running-atdd-cycle` のガイドに「`[regression]` として恒久実行される AT には、バージョン等の時点依存値を完全一致でピンしない」を明文化する。

## Non-Goals

- **CI で `tests/acceptance/` を実行するようにする**: 本問題が post-merge regression まで検出されなかった根因の一つだが、acceptance suite を CI に組み込むのは実行時間・スコープの観点で別個の判断を要するため本 Issue では扱わない（必要なら別 Issue で追跡）。
- **他の AT ファイルの網羅的な時点依存ピン監査**: 本 Issue は #277 regression で実際に検出された AT-284 / AT-271 の 3 件に限定する。他ファイルの予防的監査は再発防止ガイダンス（What 4）でカバーし、個別の書き換えはスコープ外。
- **plugin.json / CHANGELOG のバージョン体系そのものの変更**: バージョニング規約（DEVELOPMENT.md）には手を入れない。

## Open Questions

- none remain（What 4 の再発防止ガイダンスの要否、および CI で acceptance を実行する件の扱いは Gate ① の承認時に確認する）。
