# Plan: autopilot-log.jsonl 削除時に sameness / stuck 履歴が無音リセットされる（fail-open）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

機構選定は `design-doc.md` 参照: **イテレーション連続性検証**（orchestrator がメモリ上で期待行数を追跡し、`check_log_integrity <jsonl> <expected-lines>` に渡す。完全一致でなければ halt）。

## Implementation

- [x] `lib/autopilot_convergence.sh` に `check_log_integrity <jsonl> <expected-lines>` を追加する。仕様: (1) `expected` が空または非数値なら stderr にエラーを出して `return 2`（`check_stuck` の window 検証と同パターン、fail-closed）。(2) ファイル未存在のとき `expected -eq 0` なら `return 0`（正当な初回）、それ以外は `return 1`（run 途中の削除）。(3) `actual=$(grep -c . "$jsonl")` で非空行数を数え、`[ "$actual" -eq "$expected" ] || return 1`（巻き戻し・外部追記の両方向を検出）
- [x] verify: `bash -n lib/autopilot_convergence.sh` が成功し、一時ファイルで手動スモーク（2 行のログに expected=2 → exit 0 / expected=3 → exit 1 / ファイル未存在 + expected=0 → exit 0）が通る

- [x] `lib/autopilot_convergence.sh` ヘッダコメントの Functions 一覧に `check_log_integrity <jsonl> <expected-lines>` の 1 行（用途: non-zero if the audit log was deleted / rolled back mid-run）を追記する
- [x] verify: `grep -n 'check_log_integrity' lib/autopilot_convergence.sh` がヘッダと関数定義の 2 箇所以上にヒットする

- [x] `skills/autopilot/SKILL.md` の FREEZE agent 呼び出しを拡張する: prompt に「ログ（`LOG_GLOB`、未存在なら 0）の非空行数を `logLines` として報告せよ」を追加し、schema の `required` / `properties` に `logLines`（integer）を追加。直後に `let recorded = frozen.logLines`（baseline 吸収 — 再入・phase 跨ぎの既存行を正とする）を置く
- [x] verify: `grep -qE 'logLines' skills/autopilot/SKILL.md` && `grep -qE 'let recorded = frozen.logLines' skills/autopilot/SKILL.md`

- [x] `skills/autopilot/SKILL.md` の audit ステップ: `if (rec.recordOk !== true) ...` の halt 行の直後（converged 判定の前）に `recorded++` を追加する（record 成功 = ログに 1 行増えた、をメモリ側の真実に反映）
- [x] verify: `grep -qE 'recorded\+\+' skills/autopilot/SKILL.md`

- [x] `skills/autopilot/SKILL.md` の rails agent 呼び出しに 5 項目目を追加する: prompt に `(e) check_log_integrity "<log>" ${recorded}` を追記し、schema の `required` / `properties` に `logIntegrityExit`（integer）を追加。halt 三項演算子の `acDriftExit` 直後に `r.logIntegrityExit !== 0 ? 'log-integrity'` を挿入する（sameness / stuck はログを前提とするため、それらより先に理由判定する）
- [x] verify: `grep -qE 'check_log_integrity "<log>" \$\{recorded\}' skills/autopilot/SKILL.md` && `grep -q "logIntegrityExit" skills/autopilot/SKILL.md` && `grep -q "'log-integrity'" skills/autopilot/SKILL.md`

- [x] `skills/autopilot/SKILL.md` の散文 2 箇所を同期する: Loop 説明の rails 行（step 6/7 の記述）と末尾の rails 関数一覧（`fingerprint` / `record_iteration` / …）に `check_log_integrity` を追加する
- [x] verify: `grep -c 'check_log_integrity' skills/autopilot/SKILL.md` が 3 以上（workflow script + 散文 2 箇所）

## Testing

- [x] `tests/test_autopilot_convergence.bats` に検出系テストを追加する（AT-002〜AT-005 に対応）: 「run 途中の削除（ログ未存在 + expected>0）→ 非ゼロ」「巻き戻し（actual < expected）→ 非ゼロ」「外部追記（actual > expected）→ 非ゼロ」「expected が空 / 非数値 / コマンド注入文字列 → status 2」
- [x] verify: `bats tests/test_autopilot_convergence.bats` が green

- [x] `tests/test_autopilot_convergence.bats` に非検出系テストを追加する（AT-001 に対応）: 「正当な初回（ログ未存在 + expected=0）→ 0」「行数一致 → 0」（誤検出ゼロの回帰保証）
- [x] verify: `bats tests/test_autopilot_convergence.bats` が green

- [x] `tests/test_autopilot_skill.bats` に配管テストを追加する（AT-006/AT-007 に対応）: SKILL.md が (1) rails で `check_log_integrity "<log>" ${recorded}` を呼ぶ、(2) freeze で `logLines` baseline を取得し `recorded` を初期化する、(3) record 成功後に `recorded++` する、(4) halt 理由 `'log-integrity'` を持つ、を grep で検証
- [x] verify: `bats tests/test_autopilot_skill.bats` が green

- [x] 既存スイート全体の回帰確認（AT-008 に対応）
- [x] verify: `bats tests/` が green（既存テストに変更なしで通る）

## Finishing

- [x] `.claude-plugin/plugin.json` の version を minor バンプし、`CHANGELOG.md` に Added エントリ（autopilot 監査ログの fail-closed ガード `check_log_integrity`）を追加する（DEVELOPMENT.md: 既存スキルへのゲート追加 = minor）
- [x] verify: `bash scripts/check-plugin-version.sh` 相当のチェックが通り、version と CHANGELOG の最新エントリが一致している

- [x] ドキュメント整合性チェック: `docs/` 配下の autopilot 関連記述（workflow-detail 等）と `tests/README.md` に rails 一覧の記載があれば `check_log_integrity` を反映する
- [x] verify: `grep -rn 'check_sameness' docs/ tests/README.md` のヒット箇所すべてで関数一覧が新ガードと整合している（一覧が無い箇所は変更不要）
