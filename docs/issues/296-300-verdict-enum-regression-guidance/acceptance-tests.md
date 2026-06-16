# Acceptance Tests: VERDICT_SCHEMA enum 制約化 ＋ regression ピン禁止ガイダンス補完・changelog ヘルパー集約

対象 Issue: #296 / #300

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-001: VERDICT_SCHEMA.overall_correctness が enum 制約を持つ（AC-296-1）

- [ ] [planned] AT-001: autopilot SKILL.md の overall_correctness が enum 制約化されている
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `skills/autopilot/SKILL.md` の `VERDICT_SCHEMA` 内 `overall_correctness` プロパティ定義を検査する
  - Then: `overall_correctness` の定義に `enum: ['correct', 'incorrect']` が含まれる（grep ヒット）

## AT-002: oracle の厳密一致判定が enum 制約と整合し破綻しない（AC-296-2）

- [ ] [planned] AT-002: 厳密一致判定式が無改修で維持されている
  - Given: enum 制約を追加した autopilot SKILL.md
  - When: satisfaction oracle の収束判定式（`overall_correctness === 'correct'`）を検査する
  - Then: `overall_correctness === 'correct'` の厳密一致式が従来どおり存在し（line 78 / 224 相当）、enum 値 `'correct'` がその一致を通すため判定が破綻しない。SKILL.md の構造 pin（行バジェット・schema 構造）も維持される

## AT-003: running-atdd-cycle に時点依存ピン禁止ガイダンスが存在する（AC-300-1）

- [ ] [planned] AT-003: running-atdd-cycle の [regression] 箇所に再発防止ガイダンスが追加されている
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `skills/running-atdd-cycle/SKILL.md` の `[regression]` 確立箇所（C2 バレット）を検査する
  - Then: `[regression]` AT が version 等の時点依存値を完全一致でピンせず、履歴事実（`## [X.Y.Z]` 見出し存在）＋ 整合事実（plugin.json version が CHANGELOG 最新リリース見出しと一致）の 2 アサーションで表現する旨が grep 可能である

## AT-004: ガイダンス文言が writing-plan-and-tests と整合している（AC-300-2）

- [ ] [planned] AT-004: 両スキルの再発防止ガイダンス用語が揃っている
  - Given: running-atdd-cycle と writing-plan-and-tests の両 SKILL.md
  - When: 両ファイルの再発防止ガイダンス文言（完全一致でピンしない／時点依存値／#289 参照）を突き合わせる
  - Then: 用語・主旨が整合し、`#289` 参照を含む同主旨のガイダンスが両スキルに存在する

## AT-005: changelog_latest_release ヘルパーが定義されている（AC-300-3）

- [ ] [planned] AT-005: helpers/changelog.bash が latest_release 抽出関数を提供する
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `tests/acceptance/helpers/changelog.bash` を source し `changelog_latest_release CHANGELOG.md` を実行する
  - Then: `tests/acceptance/helpers/changelog.bash` が存在し、関数が `## [Unreleased]` をスキップして先頭の `## [X.Y.Z]` から `X.Y.Z` を出力する（出力が現行 plugin.json version と一致する）

## AT-006: AT-271/AT-284 のインライン抽出重複が解消されている（AC-300-4）

- [ ] [planned] AT-006: 2 つの AT がインライン抽出ではなくヘルパー呼び出しを使う
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `tests/acceptance/AT-271.bats`（AT-005）と `tests/acceptance/AT-284.bats`（AT-010）を検査する
  - Then: 両ファイルが `changelog_latest_release` 呼び出しを使い、`grep -oE '^## \[...'` のインライン抽出重複が残っていない

## AT-007: regression suite が green を維持する（AC-COM-1）

- [ ] [planned] AT-007: bats tests/acceptance/ が fail 0 件で、疑似 version bump でも red 化しない
  - Given: 本 Issue の全変更を適用した作業ツリー
  - When: `bats tests/acceptance/` を実行し、さらに plugin.json version と CHANGELOG 先頭見出しを同値で疑似 bump して AT-271(AT-005)/AT-284(AT-010) を再実行する
  - Then: いずれも `0 failures`。invariant（plugin.json version == CHANGELOG 最新リリース見出し）で判定するため、時点依存値に依らず疑似 bump 後も green を維持する

## AT-008: version bump ＋ CHANGELOG エントリがリリース規約に従う（AC-COM-2）

- [ ] [planned] AT-008: plugin.json version と CHANGELOG 最新リリース見出しが一致する
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `.claude-plugin/plugin.json` の version と `changelog_latest_release CHANGELOG.md` の出力を突き合わせる
  - Then: version が SemVer で bump され、CHANGELOG（Keep a Changelog 形式）の最新リリース見出しと完全一致する（不変条件として表現し、特定 version 文字列を完全一致ピンしない）

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
