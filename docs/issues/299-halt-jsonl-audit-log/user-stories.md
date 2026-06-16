# User Stories: autopilot halt の終端レコードを JSONL 監査ログに記録する

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

**I want to** autopilot ループが収束失敗系の halt（MAX_ITERATIONS / sameness-detector / stuck / ac-drift / log-integrity）で終了したとき、`autopilot-log.jsonl` に終端 HALT レコード（`{outcome:"HALT", step, reason, findings_digest, timestamp, ...}`）が 1 行追記される,
**so that** 監査ログ単体（return 値・セッション文脈なし）から「どの step で・なぜ halt し・どの未解決 findings を残したか・いつか」を再構成でき、halt の事後デバッグが return 値のセッション文脈に依存しなくなる.

**I want to** 既存のイテレーション行にも `timestamp` フィールドが付与される（生成は bash 側の `date -u`）,
**so that** 各イテレーションイベントの発生時刻を追え、いつ何が起きたかをログから時系列で把握できる.

**I want to** 終端 HALT レコードがログのみ即コミットされる（#288 と同様）,
**so that** 後続作業ツリーの rollback でも終端レコードが消失せず、halt 監査が永続化される.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

**I want to** timestamp が fingerprint 計算に一切関与せず、sameness / stuck / log-integrity レールの決定論が不変である（既存 BATS が全 PASS のまま）,
**so that** timestamp 付与によって収束レールの決定論が壊れず、同一入力に対する fingerprint が不変に保たれる.

**I want to** JSONL の終端 HALT レコードと return 値（`COMPLETED_WITH_DEBT`）が両立する（return 値は廃止しない）,
**so that** JSONL は冗長な永続記録として、return 値はその run のハンドオフ用として、それぞれの役割を保ったまま機能する.

**I want to** 終端レコードは収束失敗系の halt のみに書かれ、audit/rails/freeze の各 error halt（監査ログへの書込み・整合自体が破綻しているケース）には書かれず return のみでエスカレーションされる,
**so that** 書込み自体が信頼できない halt で誤った終端レコードを残さず、終端レコードが存在する＝信頼できる記録であるという不変条件が保たれる.
