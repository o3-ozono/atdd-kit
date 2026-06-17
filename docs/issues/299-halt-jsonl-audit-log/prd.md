# PRD: autopilot halt の終端レコードを JSONL 監査ログに記録する

## Problem

autopilot の収束ループが halt すると、halt 理由（MAX_ITERATIONS / sameness / stuck / ac-drift / log-integrity 等）と未解決 findings は **orchestrator の return 値（`COMPLETED_WITH_DEBT`）にのみ存在する**。これらは JSONL 監査ログ（`autopilot-log.jsonl`）には残らない。

- 現状: JSONL に残るのは各イテレーションの `{"iteration","step","verdict":"PASS|FAIL","fingerprint"}` 行のみ。halt はループ脱出時に return するだけで、ログ上は「最後の FAIL 行で唐突に途切れる」状態になる。
- それによる困りごと: AL-4「JSONL は外部の信頼できる唯一の真実」という不変条件が halt 終端では成立していない。run が**なぜ・どの findings を残して**終わったかをログ単体から再構成できず、事後デバッグ（dogfood 中の halt 分析）が return 値のセッション文脈に依存する。各行に時刻も無いため、いつ起きたかも追えない。

## Why now

#248（autopilot 収束レール追加ハードニング）の繰り越し最終項目（項目3）。項目1（`_fingerprints` corruption guard, PR #298）と項目2（step 跨ぎ分離, #272/#277/#262）は解消済みで、本項目が #248 の残りすべて。autopilot は現在も dogfood で実走を重ねており（#277 系）、halt の事後分析需要が継続的に発生している。AL-4 完全性を halt 終端まで広げる小さな投資で、以後すべての halt が監査可能になる。

## Outcome

- autopilot ループが収束失敗系の halt（MAX_ITERATIONS / sameness-detector / stuck / ac-drift / log-integrity）で終了したとき、JSONL に **終端 HALT レコード**が 1 行追記される: `{outcome:"HALT", step, reason, findings_digest, timestamp, ...}`。
- 監査ログ単体（return 値・セッション文脈なし）から「どの step で・なぜ halt し・どの未解決 findings を残したか・いつか」を再構成できる。
- 既存のイテレーション行にも timestamp が付与され、各イベントの発生時刻が追える。
- timestamp は fingerprint の対象外であり、sameness / stuck / log-integrity レールの決定論は不変（既存 BATS が全 PASS のまま）。

## What

- `lib/autopilot_convergence.sh` に終端 HALT レコードを追記する関数（例: `record_halt <jsonl> <step> <reason> <findings_digest> <timestamp>`）を追加する。BATS 検証付きの単一ソースとして既存レール関数群に並べる。
- `record_iteration` の出力行に `timestamp` フィールドを追加する（生成は bash 側の `date -u`、fingerprint 非対象）。
- autopilot Workflow スクリプト（autopilot SKILL.md）の halt return 直前に、終端 HALT レコードを追記する audit agent 呼び出しを追加する。`findings_digest` は halt 時の `verdict.findings`（blocking）＋ coverage uncovered AC から構成する。
- 終端 HALT レコードも #288 と同様にログのみ即コミットする（後続作業ツリー rollback での消失を防ぐ）。
- AT: 終端 HALT レコードの存在・形・timestamp 付与・決定論不変（fingerprint 不変）を検証する Acceptance Test。

## Non-Goals

- **return 値（`COMPLETED_WITH_DEBT`）の廃止** — JSONL は冗長な永続記録、return 値はその run のハンドオフ用として両立させる。return 値は残す。
- **fingerprint への timestamp 混入** — 決定論を壊すため、timestamp は fingerprint 計算に一切関与させない。
- **audit 書込自体が失敗した halt（record-error / rails-error / freeze-error）への終端レコード** — これらは監査ログへの書込み・整合自体が破綻しているケースで、終端レコードも信頼して書けない。return 値のみで人間へエスカレーションする（収束失敗系のみ終端レコードを書く）。
- **既存ログ行への遡及的 timestamp 付与** — 過去ログの書き換えはしない。timestamp は本変更以降の新規行から付く。

## Open Questions

1. **`findings_digest` の中身と形式**（scope 判断・要確認）: 提案は blocking findings を `[{priority, evidence_ref}]` の配列に圧縮し、coverage 由来の uncovered AC も併記する案。`detail` 本文は冗長なので除外し evidence_ref で追跡可能にする。— これで十分か、それとも findings 全文を残すか。
2. **終端レコードを書く halt の範囲**（割り切り・要確認）: 提案は収束失敗系（MAX_ITERATIONS / sameness / stuck / ac-drift / log-integrity）のみに終端レコードを書き、audit/rails/freeze の各 error halt は return のみ（Non-Goals 参照）。— この線引きで良いか。
3. **log-integrity カウンタとの整合**（要確認）: 終端 HALT レコードはレールチェック後・return 直前の「その run の最後の書込」になる。当該 run では以後 `check_log_integrity` は走らず、再入時は freeze の baseline 吸収（#262）で既存行として取り込まれるため整合は自然に保たれる、という理解で良いか。
