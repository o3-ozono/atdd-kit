# Acceptance Tests: autopilot-log.jsonl 削除時に sameness / stuck 履歴が無音リセットされる（fail-open）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

実行形態: AT-001〜AT-005 は `tests/test_autopilot_convergence.bats`、AT-006/AT-007 は `tests/test_autopilot_skill.bats`、AT-008 はスイート全体実行。

## AT-001: 正当な初回実行での誤検出ゼロ（US-4）

- [ ] [planned] AT-001: ログ未存在 + 期待行数 0 はガードを通過する
  - Given: `autopilot-log.jsonl` が存在せず、orchestrator の期待行数（baseline + 記録数）が 0 である
  - When: `check_log_integrity "$JSONL" 0` を実行する
  - Then: exit code 0 を返し halt しない（正当な新規 run が阻害されない）。同様に「実際の行数 == 期待行数」のログでも exit code 0 を返す

## AT-002: run 途中の削除の検出（US-1, US-2）

- [ ] [planned] AT-002: 記録済みのはずのログが消えていたら halt する
  - Given: orchestrator の期待行数が 1 以上だが `autopilot-log.jsonl` が存在しない（run 途中で削除された）
  - When: `check_log_integrity "$JSONL" <expected>` を実行する
  - Then: 非ゼロ exit code を返す（orchestrator は halt 理由 `log-integrity` で人間にエスカレーションできる）

## AT-003: 巻き戻し（truncate / リセット）の検出（US-1, US-2）

- [ ] [planned] AT-003: 行数が期待より少ないログは halt する
  - Given: `record_iteration` で N 行記録済みのログが N 未満に巻き戻されている（actual < expected）
  - When: `check_log_integrity "$JSONL" N` を実行する
  - Then: 非ゼロ exit code を返す（sameness / stuck の履歴が無音リセットされたまま続行しない）

## AT-004: 外部追記（改竄）の検出（US-1, US-2）

- [ ] [planned] AT-004: 行数が期待より多いログは halt する
  - Given: orchestrator 以外の書き手によりログ行が追記されている（actual > expected）
  - When: `check_log_integrity "$JSONL" <expected>` を実行する
  - Then: 非ゼロ exit code を返す（完全一致検証 — 過不足どちらの方向も fail-closed）

## AT-005: 不正な期待行数引数の fail-closed（US-2）

- [ ] [planned] AT-005: expected が空・非数値なら halt する
  - Given: ガードに渡す期待行数が空文字列・非数値・コマンド注入文字列（例: `"3; echo PWNED"`）である
  - When: `check_log_integrity "$JSONL" <不正値>` を実行する
  - Then: stderr にエラーを出して exit code 2 を返す（レールを黙って無効化する fail-open にならない。`check_stuck` の window 検証と同等）

## AT-006: Workflow script への rails 配管（US-3）

- [ ] [planned] AT-006: SKILL.md の rails チェックが新ガードを呼んでいる
  - Given: `skills/autopilot/SKILL.md` の Workflow script
  - When: rails agent 呼び出しの prompt・schema・halt 判定を grep で検査する
  - Then: `check_log_integrity "<log>" ${recorded}` の呼び出し、schema の `logIntegrityExit`、halt 理由 `'log-integrity'`（`acDriftExit` 判定の直後）がすべて存在する

## AT-007: baseline 取得とカウンタ維持の配管（US-3, US-4）

- [ ] [planned] AT-007: 期待行数の真実が freeze から audit まで一貫して維持される
  - Given: `skills/autopilot/SKILL.md` の Workflow script
  - When: freeze agent と audit ステップを grep で検査する
  - Then: freeze の schema に `logLines` があり `let recorded = frozen.logLines` で初期化され（再入時の既存行を吸収）、`record_iteration` 成功後に `recorded++` される

## AT-008: BATS による回帰保証（US-5）

- [ ] [planned] AT-008: 既存スイート green の維持
  - Given: AT-001〜AT-007 のテストが追加されたリポジトリ
  - When: `bats tests/` でスイート全体を実行する
  - Then: 新規テストを含む全テストが pass し、既存テストへの変更なしで green を維持する

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
