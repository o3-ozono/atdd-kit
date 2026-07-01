# Acceptance Tests: defining-requirements に引き出し型対話ディシプリンを追加

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     Anchor: docs/issues/365-defining-requirements-elicitation/user-stories.md（承認済み）。
     #289: version・日付・行数を exact-pin しない。不変条件をアサートする。 -->

## AT-365-1: Iron Law ブロックの存在と一括配置（F1）

- [ ] [planned] AT-365-1: `skills/defining-requirements/SKILL.md` の Flow セクションに独立した `## Iron Law: 対話ディシプリン` ブロックが存在する
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `skills/defining-requirements/SKILL.md` の見出し構造を検査する
  - Then: `## Iron Law: 対話ディシプリン` 見出しが 1 つ存在し、その配下に 6 ディシプリンがまとめて記述されている。各 Section Step の問い文は現行維持されている

## AT-365-2: ディシプリン 1「1 ターン 1 問」の pin（F1）

- [ ] [planned] AT-365-2: Iron Law に「1 ターン 1 問」ディシプリンと一次情報が明記される
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: Iron Law ブロックを grep する
  - Then: 「1 ターン 1 問」の識別句（1 ターンに複数の問いを並べない旨）と一次情報 `Rocket Surgery Made Easy` が本文にヒットする

## AT-365-3: ディシプリン 2「引き出し型 HARD-GATE — 提案完成型禁止」と例外境界の pin（F2）

- [ ] [planned] AT-365-3: Iron Law に提案完成型禁止 HARD-GATE と手法領域例外の境界線が明文化される
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: Iron Law ブロックを grep する
  - Then: 「提案完成型」禁止句・`HARD-GATE` 語・境界線（本質＝何を解くか/何を達成するか/何を作るかは引き出す、手法＝どう計測するか/どう実装するかは AI が選択肢提示可）が本文にヒットする

## AT-365-4: ディシプリン 3「対話の語彙制約」の pin（C1）

- [ ] [planned] AT-365-4: Iron Law に対話の語彙制約が明記される
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: Iron Law ブロックを grep する
  - Then: 「語彙制約」の識別句・「内部 ID・フレームワーク用語・出典名を使わない」旨・「作者の過去回答はそのまま引用」・「平易な言葉に言い換える」が本文にヒットする

## AT-365-5: ディシプリン 4「経緯記録の自動駆動」の pin（C2）

- [ ] [planned] AT-365-5: Iron Law に経緯記録の PRD 本体定着が明記される
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: Iron Law ブロックを grep する
  - Then: 「経緯記録」の識別句・機能増減/優先度変更/分類変更の検知・「変更内容・理由・日付を PRD 本体に追記」・「commit message 依存不可」が本文にヒットする

## AT-365-6: ディシプリン 5「Wall 検知と差し戻し」＋差し戻しテンプレートの pin（F3）

- [ ] [planned] AT-365-6: Iron Law に Wall 検知 3 シグナルと共通差し戻しテンプレートが内蔵される
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: Iron Law ブロックを grep する
  - Then: 「Wall 検知」識別句・3 シグナル（(a) 層化要素の欠如 / (b) 情報量の極端な低下 / (c) 症状の別語再陳述）・「1 回深掘りしてなお情報量が上がらなければ上流の壁打ちへ戻す」発動条件・共通差し戻し文言テンプレートの引用可能な文言・「どのシグナルが発動したかを本文中で補足」する旨が本文にヒットする

## AT-365-7: ディシプリン 6「ターゲット層化追問」の pin（F4）

- [ ] [planned] AT-365-7: Iron Law にターゲット層化追問が明記される
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: Iron Law ブロックを grep する
  - Then: 「層化追問」の識別句・「全員」型の層化されない回答への「強いて言うと誰」追問・「1 回だけ」の制約が本文にヒットする

## AT-365-8: pin テストの存在と非回帰（F5）

- [ ] [planned] AT-365-8: `tests/acceptance/AT-365.bats` が Iron Law 6 ディシプリンの grep pin を実装し、既存 skill テストが非回帰
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `bats tests/acceptance/AT-365.bats` および `bats tests/test_defining_requirements_skill.bats` を実行する
  - Then: `AT-365.bats` に 6 ディシプリン各 1 テスト以上（キーフレーズ grep のみ・論理順序は検証しない）が存在し green。既存 `test_defining_requirements_skill.bats` も green（構造 pin 非回帰）

## AT-365-9: version bump ＋ CHANGELOG 整合（不変条件 / F6）

- [ ] [planned] AT-365-9: `plugin.json` version が CHANGELOG 最新リリース見出しと一致し #365 エントリが存在する
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `.claude-plugin/plugin.json` の version と `CHANGELOG.md` の最新リリース見出し・#365 エントリを検査する
  - Then: `plugin.json` の version が CHANGELOG 最新リリース見出しと一致（exact-pin せず不変条件でアサート、#289）。`CHANGELOG.md` の `### Added` に #365 の Iron Law 追加エントリが存在する

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
