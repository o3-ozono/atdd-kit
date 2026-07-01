# Acceptance Tests: setup-* の eager-copy を「参照優先 + 使う時に不足検出してプロンプト」モデルへ見直す

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     トレーサビリティ: 各 AT は user-stories.md の Story / prd.md の Outcome に対応する。 -->

## AT-370-1: 仕分け一覧 doc が全 setup-* を網羅する（W-1 / Outcome 1）

- [ ] [green] AT-370-1: `docs/design/setup-eager-copy-inventory.md` が存在し、5 つの setup-* コマンド全ての成果物を実ファイル参照付きで列挙する
  - Given: PRD W-1 と Functional Story（仕分け一覧）が承認済み
  - When: `docs/design/setup-eager-copy-inventory.md` を読む
  - Then: setup-github / setup-ci / setup-discord / setup-ios / setup-web の 5 コマンドすべてが表に登場し、各成果物にソースパス（`templates/…` または `addons/…`）と配置先が記載されている

## AT-370-2: 全アイテムが Gate① 基準で二分類されている（W-1 / Outcome 1）

- [ ] [green] AT-370-2: 仕分け一覧の全アイテムが「参照で足りる」/「プロジェクトローカルに要る」のいずれかに、判定根拠つきで分類されている
  - Given: 仕分け一覧 doc が存在する
  - When: doc 内の分類表を検査する
  - Then: 全アイテムに二分類のいずれかと 1 行以上の判定根拠が付与されており、未分類（空欄）のアイテムが 0 件である

## AT-370-3: 高リスク項目が「プロジェクトローカルに要る」に固定されている（W-1 / Non-Goals）

- [ ] [green] AT-370-3: 秘匿値・書き込み対象は「プロジェクトローカルに要る」側に分類され、本 Issue のオンデマンド移管対象外と明記される
  - Given: 仕分け一覧 doc が存在する
  - When: discord webhook（秘匿値）と GitHub ラベル（書き込み対象）の分類行を検査する
  - Then: 両者が「プロジェクトローカルに要る」に分類され、かつ本 Issue のオンデマンド移管対象外である旨が doc に明記されている

## AT-370-4: オンデマンド移管の設計方針 doc が 3 要素を定義する（W-2 / Outcome 2）

- [ ] [green] AT-370-4: `docs/design/setup-on-demand-policy.md` が移管対象ごとに「トリガー / 検出ロジック / プロンプト方法」を定義する
  - Given: PRD W-2 が承認済み
  - When: `docs/design/setup-on-demand-policy.md` を読む
  - Then: 少なくとも W-3a（ラベル不足検出）を含む移管対象が、トリガー・検出ロジック・プロンプト方法の 3 要素すべてを埋めた行として存在する

## AT-370-5: pre-flight check の標準ガードパターンが明文化されている（W-2 / Open Question 2）

- [ ] [green] AT-370-5: 設計方針 doc に「検出失敗はエラー終了せず通知 → confirm 後続行 / スキップ可能」の標準ガードパターン節がある
  - Given: 設計方針 doc が存在する
  - When: doc の標準ガードパターン節を検査する
  - Then: 「エラー終了しない」かつ「スキップ可能」を要件とする pre-flight check の標準パターンが記述されている

## AT-370-6: 冪等性チェックリストが存在する（W-2 / Outcome 3 / Constraint Story 冪等性）

- [ ] [green] AT-370-6: 設計方針 doc にラベルと hook の両経路の冪等化方法を含む冪等性チェックリストがある
  - Given: 設計方針 doc が存在する
  - When: doc の冪等性チェックリストを検査する
  - Then: 箇条書きの冪等性チェックリストが存在し、ラベル作成（既存を無視）と hook 配線（plugin-global 常時有効で重複回避）の冪等化方法が各 1 項目以上含まれる

## AT-370-7: ラベル不足検出スクリプトが不足を通知する（W-3a / Functional Story ラベル不足検出）

- [ ] [draft] AT-370-7: `scripts/check-required-labels.sh` が必須ラベルの不足を検出して列挙する
  - Given: `commands/setup-github.md` の 16 ラベルが正準ソースとして参照される
  - When: 必須ラベルの一部が存在しない状態で `bash scripts/check-required-labels.sh` を実行する
  - Then: 不足しているラベル名が列挙され、スクリプトはエラー終了せず（非破壊で通知のみ）完了する

## AT-370-8: ラベル未取得環境でもクラッシュせずスキップする（W-3a / Open Question 2）

- [ ] [draft] AT-370-8: gh 不在 / 未認証など label 一覧を取得できない環境で pre-flight check がスキップ扱いになる
  - Given: `gh label list` が結果を返せない環境（gh 不在または未認証）
  - When: `bash scripts/check-required-labels.sh` を実行する
  - Then: クラッシュせず「スキップした」旨のメッセージを出して正常終了し、ワークフローを阻害しない

## AT-370-9: ラベル作成が冪等である（W-3a / Constraint Story 冪等性）

- [ ] [draft] AT-370-9: pre-flight check のラベル作成経路を 2 回連続実行しても副作用が重複しない
  - Given: 一部ラベルが既に存在する状態
  - When: ラベル作成経路（`gh label create --force`）を 2 回連続で実行する
  - Then: 2 回目でエラー・重複作成が起きず、既存ラベルは変更されない（`--force` により冪等）

## AT-370-10: ワークフロー skill に起動時ガードが配線されている（W-3a / Functional Story）

- [ ] [draft] AT-370-10: autopilot / full-autopilot の起動節にラベル不足検出の呼び出しが記述されている
  - Given: W-3a のスクリプトが存在する
  - When: `skills/autopilot/SKILL.md` または `skills/full-autopilot/SKILL.md` を読む
  - Then: check-required-labels の呼び出しと「不足は通知のみ・エラー終了しない・skip 可」旨が記述されている

## AT-370-11: hook が plugin-global に配線されている（W-3b / Constraint Story 鮮度 / regression 不変条件）

- [ ] [draft] AT-370-11: `hooks/hooks.json` の全 hook が `${CLAUDE_PLUGIN_ROOT}` 参照で、プロジェクトローカルパスへ退行していない
  - Given: hook は setup-* を実行していない環境でも機能する必要がある（Constraint Story 鮮度 / Problem 2）
  - When: `hooks/hooks.json` の全 `command` フィールドを検査する
  - Then: すべての `command` が `${CLAUDE_PLUGIN_ROOT}` を含み、`.claude/hooks/` 等のプロジェクトローカルパスへの配線が存在しない
  - Note: これは回帰 AT。将来のバージョン・行数・hook 個数といった時点値を pin せず、「全 command が plugin-global 参照」という**不変条件**のみを assert する（#289 の教訓）。

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
