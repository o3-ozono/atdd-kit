# Plan: autopilot halt の終端レコードを JSONL 監査ログに記録する

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

対象ファイル:
- `lib/autopilot_convergence.sh` — 終端 HALT レコード追記関数 `record_halt` の追加、`record_iteration` への `timestamp` 付与
- `skills/autopilot/SKILL.md` — 収束失敗系 halt の return 直前に終端 HALT レコードを追記する audit agent 呼び出しの追加
- `tests/test_autopilot_convergence.bats` — `record_halt` / `timestamp` の BATS 検証
- `tests/test_autopilot_skill.bats` — SKILL.md の終端レコード配線の構造 pin
- `lib/README.md` — `record_halt` を関数一覧に追記
- `CHANGELOG.md` / `.claude-plugin/plugin.json` — minor bump（新規ゲート関数の追加）

## Implementation

- [ ] `lib/autopilot_convergence.sh` 冒頭の Functions コメント表に `record_halt <jsonl> <step> <reason> <findings_digest>` の 1 行説明を追加する（収束失敗系 halt の終端 HALT レコードを 1 行追記）
- [ ] verify: `grep -n "record_halt" lib/autopilot_convergence.sh` が冒頭コメントにヒットする

- [ ] `record_iteration` の出力 `printf` に `timestamp` フィールドを追加する。値は関数内で `local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"` を生成し、`"timestamp":"%s"` を JSON 末尾に付加する。`fp`（fingerprint）引数は従来どおりそのまま使い、`ts` は fingerprint 計算に一切渡さない。**構造プロパティ（finding-2 解消）**: `ts` は `printf` の `timestamp` フィールド専用ローカル変数であり、`fp` 引数の生成経路（呼び出し側の `fingerprint < "$tmp"`）にも `record_iteration` 内のどの分岐にも渡らない。fingerprint は呼び出し側で `ts` 生成より前に計算され、`record_iteration` は `fp` を不透明値としてそのまま出力する（`ts` は fingerprint 計算経路に存在しない）
- [ ] verify: `record_iteration "$JSONL" 1 US FAIL abc123` の出力行に `"timestamp":"<ISO8601 UTC>"` が含まれ、かつ `"fingerprint":"abc123"` が**入力 `fp` 引数と同一のまま不変**（`record_iteration` が `fp` を変換しない）であることを BATS で確認

- [ ] `record_halt` 関数を `record_iteration` の直後に追加する。シグネチャは `record_halt <jsonl> <step> <reason> <findings_digest>`。出力は `{"outcome":"HALT","step":"<step>","reason":"<reason>","findings_digest":<digest>,"timestamp":"<ISO8601 UTC>"}` の 1 行を JSONL へ append する。**`findings_digest` の埋め込み形式の決定（finding-1 解消）**: `findings_digest` 引数は **既に整形された JSON 配列値（例 `[{"priority":1,"evidence_ref":"..."}]`）として渡され、`record_halt` は `printf` の `%s` でそのまま（クォートなし・`_json_escape` を通さず）埋め込む**。したがって終端 HALT レコード内の `findings_digest` は **ネストした JSON 配列値**であり、エスケープ済み JSON 文字列スカラ（`"[{\"priority\":...}]"`）ではない。`step` / `reason` のみがスカラ文字列ボディなので `_json_escape` を通す（`findings_digest` は通さない）
- [ ] verify: `record_halt "$JSONL" US MAX_ITERATIONS '[{"priority":1,"evidence_ref":"x"}]'` 実行後、ログ末尾行が `"outcome":"HALT"` を含み、`findings_digest` の値が `[` で始まるネストした JSON 配列（先頭が `"findings_digest":[` であり `"findings_digest":"[` ではない）であることを BATS で確認

- [ ] `record_halt` の入力検証を既存レール様式に合わせて実装する: (a) `reason` を収束失敗系の enum（`MAX_ITERATIONS` / `sameness-detector` / `stuck` / `ac-drift` / `log-integrity`）に限定し、範囲外は非ゼロ return（誤った終端レコードを書かない不変条件の防御）。(b) `step` / `reason` のみ `_json_escape` を通して JSON 安全化する（**`findings_digest` は整形済み JSON 配列値なので `_json_escape` を通さない** — finding-1 の矛盾解消）。(c) `jsonl` 未指定は非ゼロ return。(d) `findings_digest` 未指定時は空配列 `[]` を既定とする
- [ ] verify: `record_halt "$JSONL" US bogus-reason '[]'` が非ゼロで return し、ログに HALT 行が追記されないことを BATS で確認

- [ ] `skills/autopilot/SKILL.md` の `if (halt !== 'none') return { status: 'COMPLETED_WITH_DEBT', step, reason: halt, verdict }` 直前に、終端 HALT レコードを追記する audit agent 呼び出しを挿入する。`findings_digest` は halt 時の blocking findings（`verdict.findings` の priority<=1）＋ coverage 由来 uncovered AC を `[{priority, evidence_ref}]` 形式に圧縮した JSON 配列とする（finding-1 の決定どおり `record_halt` へ整形済み JSON 配列値として渡す）
- [ ] verify: SKILL.md 内の挿入箇所が `record_halt` を呼び、`halt` 変数（収束失敗系の reason）を渡していることを目視確認

- [ ] **log-integrity カウンタ整合の明示決着（finding-3 / OQ3 解消）**: 終端 HALT レコード追記は rails チェック合格後・`return` 直前の「その run の最後の書込」であり、`recorded` カウンタ（`record_iteration` 成功時のみ `recorded++`）を **インクリメントしない**。当該 run では HALT 行追記後に `check_log_integrity` を再走させない（rails は HALT 行追記前に評価済みで `grep -c` 行数 == `recorded` が成立）。次回 freeze 再入時は #262 の baseline 吸収で HALT 行が既存行として取り込まれ整合が保たれる。SKILL.md の挿入指示にこの「HALT 行は recorded を増やさない・追記後に integrity を再走させない」前提をコメントで明記する
- [ ] verify: SKILL.md 上で終端 HALT レコード追記が rails チェック後・return 直前にあり、追記後に `recorded++` も `check_log_integrity` 呼び出しも無いことを目視確認

- [ ] 終端 HALT レコードの追記も #288 と同様に「ログのみ即コミット」する。audit agent に `git add "<resolved-log-path>" && git commit -m "chore(autopilot): halt record ${step} ${halt} (#${NNN})"`（ログ単独 stage）を指示する
- [ ] verify: SKILL.md の終端レコード追記指示に「ログ単独 stage + commit」の文言が含まれる

- [ ] 終端 HALT レコードは収束失敗系の halt のみに書くことを明示する。`record-error` / `rails-error` / `freeze-error` / `anchor-pin-failed` の各 return 経路には終端レコードを追記しない（これらは return のみでエスカレーション）。`record_halt` の reason enum 制約がこの不変条件を二重に守る
- [ ] verify: SKILL.md 上で `reason: 'record-error'` / `'rails-error'` / `'freeze-error'` / `'anchor-pin-failed'` の各 return 経路には `record_halt` 呼び出しが無いことを目視確認

## Testing

- [ ] `tests/test_autopilot_convergence.bats` に `record_halt` の正常系テストを追加する（終端 HALT 行の存在・`outcome`/`step`/`reason`/`findings_digest`/`timestamp` フィールド形）
- [ ] verify: `bats tests/test_autopilot_convergence.bats` の新規テストが PASS

- [ ] `tests/test_autopilot_convergence.bats` に `record_halt` の異常系テストを追加する（範囲外 reason の拒否・JSON 安全化）
- [ ] verify: `bats tests/test_autopilot_convergence.bats` の異常系テストが PASS

- [ ] `tests/test_autopilot_convergence.bats` に `record_iteration` の timestamp 付与テストと「timestamp が fingerprint に関与しない（決定論不変）」テストを追加する。**finding-2 解消**: 後者は秒粒度 `date` の時刻差に依存せず、構造プロパティを直接 assert する — (i) `record_iteration` に与えた `fp` 引数値が、出力行の `"fingerprint"` フィールドにそのまま（無変換で）現れること、(ii) 同一の入力ペイロードに対し `fingerprint` を 2 回計算した出力が一致すること（fingerprint 関数が timestamp を入力に取らない）。時刻差の強制（date モック等）に依存しないため trivially-pass しない
- [ ] verify: 既存 56 テスト + 新規テストがすべて PASS（`bats tests/test_autopilot_convergence.bats`）。timestamp 非関与テストは `fp` 無変換と `fingerprint` 入力非依存の 2 点を assert する

- [ ] `tests/test_autopilot_skill.bats` に終端レコード配線の構造 pin を追加する（SKILL.md が halt return 直前に `record_halt` 呼び出しと「ログ単独 commit」指示を持つこと、収束失敗系のみであること）。**finding-3 解消**: HALT 行追記が rails チェック後・return 直前にあり、追記後に `recorded++` も `check_log_integrity` 呼び出しも無いこと（log-integrity カウンタ整合の前提）を構造 pin する
- [ ] verify: `bats tests/test_autopilot_skill.bats` が PASS（pin が現行 SKILL.md とマッチ）

## Finishing

- [ ] `lib/README.md` の関数一覧に `record_halt` を追加する
- [ ] verify: `grep -n "record_halt" lib/README.md` がヒット

- [ ] `CHANGELOG.md` に Unreleased エントリを追加し、`.claude-plugin/plugin.json` を minor bump する（新規ゲート関数 `record_halt` + `timestamp` 付与）
- [ ] verify: plugin.json の version が CHANGELOG 最上位リリース見出しと一致する（不変条件: version == topmost CHANGELOG release heading）

- [ ] ドキュメント整合性チェック
- [ ] verify: 関連ドキュメント（`lib/README.md`、autopilot SKILL.md の Functions 説明、CHANGELOG）が変更内容と整合している
