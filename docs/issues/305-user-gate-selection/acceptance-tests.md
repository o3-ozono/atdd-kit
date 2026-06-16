# Acceptance Tests: User gate を選択肢提示（ワンタップ承認）にする

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     注: regression 対象は point-in-time 値（現行 version・日付・行数）を exact-pin しない。不変条件をアサートする（#289）。 -->

## AT-001: ワンタップ承認（Story 1）

- [ ] [regression] AT-001: すべての User gate で第一選択肢として承認がワンタップ提示される
  - Given: Issue がいずれかの User gate（要件承認 / 設計承認 / マージ）に到達している
  - When: 各ゲートが提示される（`defining-requirements` 要件承認 / `autopilot` 設計承認 / `merging-and-deploying` マージ）
  - Then: 各ゲートが AskUserQuestion 形式で提示され、第一選択肢が `(Recommended)` 付きの承認（要件承認・設計承認は「承認 (ok)」、マージは「マージ」）であり、ユーザーは手入力なしにそれを選んで承認できる
  - 注（finding #3, AL-1 トレーサビリティ）: 要件承認ゲートは `defining-requirements` のみが提示する。autopilot の Gate ① は独自の要件質問を出さず `defining-requirements`（壁打ち）を再利用するため、autopilot 側に別の要件承認ゲートは存在しない（未移行のゲートが残っていないことを確認できる）。マージゲートは既存の Trigger レベル confirm（`merging-and-deploying` の `Y/n`）の提示方法を選択肢化したものであり、新規 in-skill ゲートではない

## AT-002: 文脈に応じた差し戻し選択肢（Story 2）

- [ ] [regression] AT-002: 各ゲートが文脈別の差し戻し選択肢を併せて提示する
  - Given: User gate が AskUserQuestion 形式で提示されている
  - When: 提示された選択肢を確認する
  - Then: 要件承認ゲートは「Problem を修正」「Outcome を修正」「スコープを変更」、設計承認ゲートは「User Stories を修正」「Plan を修正」「Acceptance Tests を修正」、マージゲートは「保留（レビュー継続）」を、承認選択肢に続けて提示する（各ゲート合計 2-4 選択肢、skill-authoring-guide (b) 準拠）

## AT-003: 自由記述の常設（Story 3）

- [ ] [regression] AT-003: どのゲートでも「Other（自由記述）」が常に選択できる
  - Given: User gate が AskUserQuestion 形式で提示されている
  - When: 選択肢に収まらないフィードバックを返したい
  - Then: harness が自動付与する「Other」を選んで自由記述でき（SKILL.md は Other を手動列挙しない）、その自由記述は現行の自然言語フィードバック経路にそのまま流れる

## AT-004: 承認/差し戻しロジックへの忠実なマッピング（Story 4）

- [ ] [regression] AT-004: 選択結果が現行の承認/差し戻し意味論にそのままマッピングされる
  - Given: 設計承認ゲートが選択肢提示で表示されている
  - When: ユーザーが承認以外（差し戻し選択肢、または部分承認に相当する複数指摘）を返す
  - Then: 現行どおり成果物セット全体が差し戻され、指摘はセクション単位で 1 セクション = 1 finding 化される（部分承認は承認ではない）。提示方法を選択肢化しても承認/差し戻しの意味論は変わらず、その旨が設計承認ゲート記述に明記されている

## AT-005: 非対応チャネルへのフォールバック（Story 5）

- [ ] [regression] AT-005: selection UI 非対応チャネルでは従来の `ok` テキスト入力にフォールバックする
  - Given: ヘッドレス / cron など selection UI が使えないチャネルで User gate に到達する
  - When: ゲートが提示される
  - Then: 各ゲート記述に `Recommended: ... — reply 'ok'` 行（`recommended.*ok` にマッチ）とフォールバック文言が存在し、ユーザーは従来どおり `ok` テキスト入力で承認できる

## AT-006: ゲート数の不変性（AL-1）（Story 6）

- [ ] [regression] AT-006: 選択肢提示化によって User gate の数・構造が変わらない
  - Given: 変更後のスキル群（autopilot / 各フロースキル）
  - When: User gate の総数と構造を確認する
  - Then: User gate は要件承認・設計承認・マージの 3 つのまま増減せず（AL-1 不変）、変わったのは提示方法のみである
  - テスト設計（finding #4, ゲート数を実際にカウントする機構）: per-skill grep（AskUserQuestion / Recommended / fallback の有無）では 4 つ目のゲート混入を検出できないため、AT-006 は既存の `tests/test_autopilot_skill.bats:339-347`「gates stay exactly three (CS-1)」を維持・利用する。これは autopilot SKILL.md の `## User gates` 節内の番号付き項目（`^[0-9]+\. ` 行）を数えて `== 3` を assert する機構で、4 つ目のゲート行が加わると fail する（finding #2 のマージゲート挿入リスクを機械的に捕捉）。merging-and-deploying 側は Trigger confirm の置換であり新規ゲート項目を増やさないため、本カウントは 3 のまま不変
  - 注: regression 化する際は「ゲート数 3」という不変条件をアサートし、version・日付・行数など point-in-time 値を exact-pin しない（#289）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
