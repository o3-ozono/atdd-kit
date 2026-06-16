# Acceptance Tests: autopilot halt の終端レコードを JSONL 監査ログに記録する

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

実行形態: BATS（`tests/test_autopilot_convergence.bats` + `tests/test_autopilot_skill.bats`）。
AT は不変条件を assert する（バージョン番号・行数・日付などの時点固定値を pin しない）。

## AT-299-1: 収束失敗系 halt で終端 HALT レコードが 1 行追記される

- [ ] [planned] AT-299-1: `record_halt` が JSONL に終端 HALT レコードを追記する
  - Given: 既存のイテレーション行を持つ `autopilot-log.jsonl` がある
  - When: `record_halt <jsonl> US MAX_ITERATIONS '<findings_digest>'` を実行する
  - Then: ログ末尾に 1 行追記され、その行は `"outcome":"HALT"`・`"step":"US"`・`"reason":"MAX_ITERATIONS"`・`"findings_digest"` キー・`"timestamp"` キーを含み、既存行は変更されない
  - verify: `bats tests/test_autopilot_convergence.bats`

## AT-299-2: 終端 HALT レコードはログ単体から halt を再構成できる形を持つ

- [ ] [planned] AT-299-2: 終端 HALT レコードが step・reason・findings_digest・timestamp を全て保持する
  - Given: `[{"priority":1,"evidence_ref":"AT-299-2#x"}]` を `findings_digest` として `record_halt` で書かれた終端 HALT レコード行
  - When: その 1 行を return 値・セッション文脈なしで読む
  - Then: 「どの step で（step）・なぜ halt し（reason）・どの未解決 findings を残し（findings_digest）・いつか（timestamp）」の 4 要素がすべて 1 行から取得できる（AL-4 完全性を halt 終端まで拡張）。かつ **`findings_digest` の値は再エスケープ無しでそのままパース可能なネストした JSON 配列**であること（finding-1 の決定の pin）: 行が `"findings_digest":[` を含み（`"findings_digest":"[` ではない）、配列要素から `priority` と `evidence_ref` が**追加のアンエスケープ無しで**再構成できる。エスケープ済み JSON 文字列スカラ（`"findings_digest":"[{\"priority\"...}]"`）であれば FAIL する
  - verify: `bats tests/test_autopilot_convergence.bats`

## AT-299-3: 各イテレーション行に timestamp が付与される

- [ ] [planned] AT-299-3: `record_iteration` の出力行に timestamp が含まれる
  - Given: 空または既存の `autopilot-log.jsonl`
  - When: `record_iteration <jsonl> 1 US FAIL abc123` を実行する
  - Then: 追記された行が `"timestamp"` キーを含み、その値が ISO 8601 UTC 形式（`...Z`）である。かつ従来の `iteration`/`step`/`verdict`/`fingerprint` フィールドは不変
  - verify: `bats tests/test_autopilot_convergence.bats`

## AT-299-4: timestamp は fingerprint に関与せず決定論が不変

- [ ] [planned] AT-299-4: timestamp 付与後も fingerprint と収束レール決定論が不変
  - Given: 同一の失敗ペイロード
  - When: 構造プロパティを検査する（finding-2 解消: 秒粒度 `date` の時刻差強制に依存しない）
  - Then: 以下の構造不変を直接 assert する — (i) `record_iteration "$JSONL" 1 US FAIL <fp>` の出力行の `"fingerprint"` 値が**入力 `<fp>` 引数と完全一致**（`record_iteration` が `fp` を変換せず不透明値として出力する＝timestamp 生成が fingerprint 経路に存在しない）、(ii) 同一ペイロードを `fingerprint` に 2 回通した出力が一致する（`fingerprint` 関数が timestamp を入力に取らない）。かつ `check_sameness` / `check_stuck` / `check_log_integrity` の判定が timestamp 導入前と同一に保たれる（既存 BATS が全 PASS のまま）。秒粒度 date の同一 timestamp 偶然一致に依存しないため trivially-pass しない
  - verify: `bats tests/test_autopilot_convergence.bats`（既存スイート全 PASS を含む）

## AT-299-5: 終端 HALT レコードは収束失敗系の halt のみに書かれる

- [ ] [planned] AT-299-5: 範囲外 reason の終端レコードは拒否される
  - Given: `autopilot-log.jsonl`
  - When: `record_halt <jsonl> US record-error '[]'`（audit/rails/freeze 系 error reason）を実行する
  - Then: `record_halt` が非ゼロで return し、HALT 行は追記されない（収束失敗系 enum: MAX_ITERATIONS / sameness-detector / stuck / ac-drift / log-integrity のみ受理）
  - verify: `bats tests/test_autopilot_convergence.bats`

- [ ] [planned] AT-299-5b: autopilot SKILL.md が終端レコードを収束失敗系 halt のみに配線する
  - Given: `skills/autopilot/SKILL.md` のループ本体
  - When: 構造を検査する
  - Then: 収束失敗系の `if (halt !== 'none') return ...` 直前にのみ `record_halt` 呼び出しがあり、`record-error` / `rails-error` / `freeze-error` / `anchor-pin-failed` の各 return 経路には `record_halt` 呼び出しが無い
  - verify: `bats tests/test_autopilot_skill.bats`

## AT-299-6: 終端 HALT レコードはログのみ即コミットされる（#288 同様）

- [ ] [planned] AT-299-6: 終端レコード追記が「ログ単独 stage + commit」として配線される
  - Given: `skills/autopilot/SKILL.md` の終端レコード追記 audit agent 指示
  - When: 構造を検査する
  - Then: 終端レコード追記指示が、ログファイルを単独で stage して commit する文言（#288 と同様のログのみ即コミット）を含み、後続作業ツリー rollback でも終端レコードが消失しない設計になっている
  - verify: `bats tests/test_autopilot_skill.bats`

## AT-299-7: return 値（COMPLETED_WITH_DEBT）と JSONL 終端レコードが両立する

- [ ] [planned] AT-299-7: 終端レコード追記後も return 値は廃止されない
  - Given: `skills/autopilot/SKILL.md` の収束失敗系 halt 経路
  - When: 構造を検査する
  - Then: `record_halt` 配線が追加されても `return { status: 'COMPLETED_WITH_DEBT', ... }` がそのまま残っている（JSONL は永続記録・return 値はハンドオフ用として両立）
  - verify: `bats tests/test_autopilot_skill.bats`

## AT-299-8: 終端 HALT レコードは log-integrity カウンタ整合を壊さない（OQ3 解消）

- [ ] [planned] AT-299-8: HALT 行は recorded カウンタを増やさず・追記後に integrity 再走が無い
  - Given: `skills/autopilot/SKILL.md` の収束失敗系 halt 経路
  - When: 構造を検査する（finding-3 / PRD OQ3 の明示決着の pin）
  - Then: 終端 HALT レコード追記が rails チェック（`check_log_integrity` 含む）後・`return` 直前に配置され、HALT 行追記後の経路に `recorded++` も `check_log_integrity` 呼び出しも存在しない。これにより当該 run の `check_log_integrity`（`grep -c` 行数 == `recorded`）は HALT 行追記前に評価済みで矛盾せず、次回 freeze 再入時は #262 baseline 吸収で HALT 行が既存行として取り込まれる
  - verify: `bats tests/test_autopilot_skill.bats`

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
