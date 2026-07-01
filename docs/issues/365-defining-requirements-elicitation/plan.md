# Plan: defining-requirements に引き出し型対話ディシプリンを追加

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。
     Anchor: docs/issues/365-defining-requirements-elicitation/user-stories.md（承認済み）。 -->

## 概要

`skills/defining-requirements/SKILL.md` の Flow セクションに独立した `## Iron Law: 対話ディシプリン` ブロックを追加し、6 つのディシプリン（1 ターン 1 問 / 引き出し型 HARD-GATE 提案完成型禁止 / 対話の語彙制約 / 経緯記録の自動駆動 / Wall 検知と差し戻し / ターゲット層化追問）を一括で明記する。Wall 検知差し戻しの共通文言テンプレートを内蔵し、6 ディシプリンの識別キーフレーズを `grep` で検証する BATS pin テストを `tests/acceptance/` に追加する。CHANGELOG 更新と patch version bump を行う。

## Implementation

- [x] `skills/defining-requirements/SKILL.md` の Flow セクション内に独立した `## Iron Law: 対話ディシプリン` 見出しブロックを追加する（各 Section Step 本文の問い文は現行維持）（F1）
- [x] verify: `skills/defining-requirements/SKILL.md` に `## Iron Law: 対話ディシプリン` 見出しが 1 つ存在し、Flow セクション内に配置されている

- [x] Iron Law ブロックにディシプリン 1「1 ターン 1 問」を記述する（1 ターンに複数の問いを並べない旨、一次情報 Steve Krug *Rocket Surgery Made Easy* (2010) を明記）（F1）
- [x] verify: Iron Law ブロックに「1 ターン 1 問」の識別句と出典 `Rocket Surgery Made Easy` が含まれる

- [x] Iron Law ブロックにディシプリン 2「引き出し型 HARD-GATE — 提案完成型禁止」を記述し、本質（課題・ゴール・機能＝何を解くか/何を達成するか/何を作るか）は AI が候補を完成形で列挙して選ばせることを禁止、例外として手法領域（どう計測するか/どう実装するか）のみ選択肢提示を許す境界線を明文化する（F2）
- [x] verify: Iron Law ブロックに「提案完成型」禁止句・`HARD-GATE`・境界線（本質は引き出し／手法は AI 提示可）・「手法」例外の明記が含まれる

- [x] Iron Law ブロックにディシプリン 3「対話の語彙制約」を記述する（内部 ID・フレームワーク用語・出典名を使わない／作者の過去回答はその語をそのまま引用／原則は平易な言葉に言い換える、産婆術 Socratic elicitation の系譜を明記）（C1）
- [x] verify: Iron Law ブロックに「語彙制約」の識別句と「そのまま引用」「平易な言葉」の記述が含まれる

- [x] Iron Law ブロックにディシプリン 4「経緯記録の自動駆動」を記述する（機能の増減・優先度変更・分類変更を検知したら変更内容・理由・日付を git commit message ではなく PRD 本体に追記する旨）（C2）
- [x] verify: Iron Law ブロックに「経緯記録」の識別句と「PRD 本体」追記・「commit message」依存不可の記述が含まれる

- [x] Iron Law ブロックにディシプリン 5「Wall 検知と差し戻し」を記述する（3 シグナル a: 層化要素の欠如 / b: 情報量の極端な低下（具体が 1 件未満）/ c: 症状の別語再陳述、1 回深掘りしてなお情報量が上がらなければ上流の壁打ちへ戻す提案を発動、Wall 検知は [独自] 整理と明記）（F3）
- [x] verify: Iron Law ブロックに「Wall 検知」の識別句・3 シグナル（層化要素の欠如 / 情報量の低下 / 別語再陳述）・「1 回深掘り」後の差し戻し発動条件が含まれる

- [x] Iron Law ブロックに Wall 検知差し戻しの共通文言テンプレート 1 本を内蔵する（発動シグナルを本文中で補足する形式、テンプレート例「ここで一度立ち止めて、課題をもう少し具体化するところから始めてみましょうか？」）（F3）
- [x] verify: Iron Law ブロックに差し戻し文言テンプレートの引用可能な文言と「どのシグナルが発動したかを本文中で補足」する旨が含まれる

- [x] Iron Law ブロックにディシプリン 6「ターゲット層化追問」を記述する（「全員」型の層化されない回答に「強いて言うと誰？」を 1 回だけ追問して層化を試みる旨）（F4）
- [x] verify: Iron Law ブロックに「層化追問」の識別句・「強いて言うと誰」・「1 回だけ」の記述が含まれる

## Testing

- [x] `tests/acceptance/AT-365.bats` を新規作成し、Iron Law 6 ディシプリンそれぞれの識別キーフレーズが `skills/defining-requirements/SKILL.md` 本文に `grep` ヒットする pin テストを実装する（キーフレーズ grep のみ・論理順序検証は行わない）（F5）
- [x] verify: `bats tests/acceptance/AT-365.bats` が green で、6 ディシプリン各 1 テスト（計 6 以上）が pass する

- [x] AT-365.bats に差し戻し文言テンプレート内蔵・境界線例外の pin と、既存 `tests/test_defining_requirements_skill.bats` 非回帰確認を含める（F5）
- [x] verify: `bats tests/test_defining_requirements_skill.bats` が green（既存構造 pin 非回帰）

## Finishing

- [x] `CHANGELOG.md` を Keep a Changelog 形式で更新し、`.claude-plugin/plugin.json` を patch version bump する（`DEVELOPMENT.md` Versioning 準拠）（F6）
- [x] verify: `plugin.json` の version が CHANGELOG 最新リリース見出しと一致し、#365 の Iron Law 追加エントリが `### Added` に存在する

- [x] ドキュメント整合性チェック（`skills/README.md` の記述が SKILL.md 変更と整合しているか確認）
- [x] verify: 関連ドキュメントが変更内容と整合し、`bats tests/` 相当の全スイートが green
