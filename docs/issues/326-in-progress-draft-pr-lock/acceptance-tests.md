# Acceptance Tests: Draft PR 作成時に in-progress 付与 ＋ full-autopilot dispatch の GitHub-state プリフィルタ

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [green] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-326-1: Draft PR 作成時の in-progress 自動付与（F1）

- [ ] [regression] AT-326-1: `gh pr create --draft` を hook が検知し、リンク Issue へ in-progress を付与する
  - Given: モック `gh`／`git` を配置し、PostToolUse hook `in-progress-label.sh` が有効で、ブランチ `324-foo` 上で body に `Closes #324` を含む
  - When: `gh pr create --draft --body "...Closes #324..."` を表す Bash tool 結果 JSON を hook の stdin に流す
  - Then: `gh issue edit 324 --add-label in-progress` 相当が 1 回呼ばれ、hook は exit 0 を返す

## AT-326-2: Issue 番号解決の二経路（F1）

- [ ] [regression] AT-326-2: PR body の `Closes #<N>` と branch 名プレフィックス `<N>-...` の両方から Issue 番号を解決する
  - Given: hook が有効で `resolve_issue_number` を直接呼べる
  - When: (a) body に `Closes #324` を含むコマンド、(b) body 無しでカレントブランチが `324-foo` のコマンド、をそれぞれ与える
  - Then: いずれも `324` を解決し、両者が存在しないコマンドでは空（＝付与をスキップ）を返す

## AT-326-3: 非 Draft / 非対象操作では付与しない（F1 負例）

- [ ] [regression] AT-326-3: `--draft` 無しの PR 作成や無関係 Bash では付与が起きない
  - Given: hook が有効
  - When: `gh pr create`（`--draft` 無し）および `git status` 等の無関係コマンドの JSON を流す
  - Then: `gh issue edit ... --add-label` は一切呼ばれず、hook は exit 0 を返す

## AT-326-4: Draft PR 放棄（close）時の in-progress 除去（F3）

- [ ] [regression] AT-326-4: `gh pr close` を hook が検知し、リンク Issue から in-progress を除去する
  - Given: hook が有効で、Issue 324 に in-progress が付与済み、対象ブランチ `324-foo`
  - When: `gh pr close` を表す Bash tool 結果 JSON を流す
  - Then: `gh issue edit 324 --remove-label in-progress` 相当が呼ばれ、hook は exit 0 を返す

## AT-326-5: 冪等性（二重付与・既消去 label 再除去が no-op）（C2）

- [ ] [regression] AT-326-5: 付与・除去が冪等で害なく no-op になる
  - Given: hook が有効
  - When: 既に in-progress が付いた Issue へ再度 Draft PR 作成イベントを流す／既に label が無い Issue へ close イベントを流す
  - Then: いずれも hook は exit 0・状態を壊さず（追加付与・誤エラーなし）、ラベル操作は冪等に成立する

## AT-326-6: hook の fail-safe（C3 hook 準拠 / 防御）

- [ ] [regression] AT-326-6: 異常入力でも hook は必ず allow（exit 0）し副作用ゼロ
  - Given: hook が有効
  - When: 空 stdin / 不正 JSON / 非 Bash tool_name / `jq` 不在 / `gh` 不在、をそれぞれ与える
  - Then: いずれも exit 0 で終了し、ラベル付与・除去コマンドを一切呼ばない（既存 hook の fail-safe 方針と一致）

## AT-326-7: dispatch が busy Issue を select から除外（F2）

- [ ] [regression] AT-326-7: open PR / in-progress を持つ Issue は dispatch select 対象から除外される
  - Given: `is_issue_busy` を `FAD_BUSY_CMD` 等の env で「Issue 319 は busy、他は idle」と注入
  - When: `full-autopilot-dispatch.sh select 3 318 319 320` を実行
  - Then: 出力に 319 が含まれず、318 と 320 のみが lease・出力される

## AT-326-8: プリフィルタは lease 取得前に除外（C2 二重 dispatch 冪等ガード）

- [ ] [regression] AT-326-8: busy Issue は lease を取得せずスキップされる（揮発 lease 消失後でも再 dispatch しない）
  - Given: lease-store が空（クラッシュ復帰で lease が消えた状況を模す）で、`is_issue_busy` が「Issue 318 は busy（open Draft PR あり）」を返すよう注入
  - When: `select 1 318 319` を実行
  - Then: 318 は出力されず lease も取得されない（lease-store に 318 のエントリが作られない）。319 が選ばれる

## AT-326-9: cmd_select の純粋性が保たれる（C1 回帰）

- [ ] [regression] AT-326-9: プリフィルタ追加後も `cmd_select` は lease-store 合成の純粋ロジックのまま（GitHub 問い合わせを内蔵しない）
  - Given: busy 判定を「全 Issue idle」と注入した状態（既存 FAD-1〜4 と等価条件）
  - When: 既存 dispatch テスト（未 claim キューから先頭 K 件選択・他セッション claim skip・K 未満全件・dispatcher 名義 lease）を実行
  - Then: 既存 FAD-1〜FAD-4 が全て従来どおり green（プリフィルタによる回帰なし）

## AT-326-11: デフォルト is_issue_busy の gh pr list 構文が open PR を正しく検出する（FAD-9 トレーサビリティ）

- [ ] [green] AT-326-11: `FAD_BUSY_CMD` 未設定のデフォルト実装パスで `gh pr list` の構文がブランチプレフィックスマッチを正しく評価し、open PR を持つ Issue を busy と判定する
  - Given: モック `gh` を `FAKE_BIN` に置き（`gh pr list` が issue 318 のブランチ `318-foo` を持つ open PR JSON を返す）、`FAD_BUSY_CMD` は未設定
  - When: `full-autopilot-dispatch.sh select 2 318 319 320` を実行する
  - Then: 318 は出力されず（open PR あり → busy → 除外）、319 と 320 が出力される（シェル変数直接展開による `startswith("${issue}-")` フィルタが正しく動作すること。旧来の `--jq --arg n "$issue"` 構文は gh CLI では無効で常に open_prs=0 になり C2 違反を引き起こしていた）
  - Notes: この AT は FAD-9 テスト（tests/test_full_autopilot_dispatch.bats:212-226）の AT 仕様レベルのトレーサビリティを提供する。レビューフィンディング #326 priority-3 で AT エントリ欠如が指摘されたため追加

## AT-326-10: hook 配布・ドキュメント整合（regression 不変量）

- [ ] [regression] AT-326-10: 新 hook が hooks.json に登録され README・配布整合が保たれる
  - Given: `hooks/in-progress-label.sh` が追加された状態
  - When: `hooks/hooks.json` をパースし、`hooks/README.md`・hook 配布整合テストを確認する
  - Then: `in-progress-label.sh` が PostToolUse(Bash) の hooks 配列に存在し、`hooks/README.md` に対応行があり、`tests/test_hook_distribution.bats` が green（不変量＝「配布対象 hook 集合とドキュメント記載が一致」。点での値はピン留めしない）

<!-- 実装開始後は [green] → [draft] に変更する -->
<!-- テストが通過したら [draft] → [green] に変更する -->
<!-- リグレッション対象になったら [green] → [regression] に変更する -->

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [green] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
