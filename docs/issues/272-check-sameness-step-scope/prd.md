# PRD: check_sameness / check_stuck の step スコープ化と gate 状態 fingerprint — 偽 sameness halt の解消

## Problem

#269 の autopilot impl phase 実走で、iteration 1 直後に `sameness-detector` が誤発火し `COMPLETED_WITH_DEBT` で halt した。反復停滞の実体はなく、iteration 2 が解消するはずだった coverage gate の残課題はオーケストレーターの手動介入で消化された。原因は 2 点:

1. **step/phase 非区別**: `lib/autopilot_convergence.sh` の `_fingerprints` が JSONL の `step` フィールドを無視してログ全体を単一系列として返すため、`check_sameness`(末尾 2 行比較)と `check_stuck`(window 内重複検出)が「design phase 最終行」と「impl iteration 1」という**別 phase・別 step の行**を同一反復の繰り返しと誤認する
2. **fingerprint の情報欠落**: fingerprint の素材が blocking findings のみで、oracle の他要素(atGreen / coverageOk / uncovered)を含まない。空配列 `[]` の sha256 は常に同一(`4f53cda1…`)のため、「review クリーン × deterministic gate FAIL」という状態では fingerprint が進捗情報を持たず、uncovered が 3→1 件に減る正当な前進すら sameness と区別できない

design phase は通常 findings 0 件の PASS で終わるため、impl phase で「review クリーン × gate FAIL」となる Issue は **iteration 1 で必ず偽 halt する**(再現条件が常設)。

## Why now

autopilot は現在の主運用モード(直近 #246〜#269 で連続実走)であり、本欠陥は impl phase の最初の反復で確定的に発火する。halt のたびに人間のエスカレーション対応(#269 では手動での coverage 解消)が必要になり、autopilot の「ゲート間は自律収束」という価値提案そのものを毀損する。また誤 halt は `sameness-detector` 由来の `COMPLETED_WITH_DEBT` として #259 のモデル昇格(Sonnet → セッションモデル)を不当にトリガーし、コスト面の副作用もある。

## Outcome

- 「review クリーン × gate FAIL → 次 iteration で gate 解消」のシナリオで sameness / stuck が発火しない(#269 の再現ケースが green)
- 別 step・別 phase のログ行が sameness / stuck の比較対象に混入しない
- 同一 step 内で oracle 状態(findings + gate 状態)に変化がない真の停滞は、従来どおり halt する(検出力の後退なし)
- `bats tests/test_autopilot_convergence.bats` および skill BATS が green

## What

- `lib/autopilot_convergence.sh`:
  - `_fingerprints <jsonl> [step]` — 第 2 引数があれば `"step":"<step>"` の行のみ抽出
  - `check_sameness <jsonl> [step]` / `check_stuck <jsonl> <window> [step]` — step 引数を透過し、同一 step の系列だけで判定(引数省略時は現行挙動 = 後方互換)
- `skills/autopilot/SKILL.md` の canonical Workflow script:
  - rails 呼び出しで `check_sameness "<log>" "<step>"` / `check_stuck "<log>" 3 "<step>"` と現在の step を渡す
  - 監査 fingerprint の payload を blocking findings 単独から **oracle 状態込み**(`{atGreen, coverageOk, uncovered, blocking}` の JSON)へ拡張し、「findings 0 件でも gate 状態が変化していれば別 fingerprint」になるようにする
- BATS:
  - `tests/test_autopilot_convergence.bats` — #269 再現(別 step 行とのクロス比較で発火しない / 同一 step の真の停滞では発火する / step 引数省略時の現行挙動維持)の回帰テスト追加
  - `tests/test_autopilot_skill.bats` — script 変更(step 引き渡し・payload 拡張)の構造 pin 更新(DEVELOPMENT.md「Skill Changes Require Test Evidence」準拠)
- `CHANGELOG.md` + `.claude-plugin/plugin.json` patch bump

## Non-Goals

- rails 全体の再設計(check_log_integrity / check_pin 等は #262/#256 で確立済みの現行設計を維持)— 本 Issue は誤発火 2 因子の修正に限定
- 監査 JSONL のスキーマ変更(`iteration/step/verdict/fingerprint` の 4 フィールドは不変。payload 拡張は fingerprint の**素材**側の変更であり、ログ形式には影響しない)
- `#259` モデル昇格ポリシー自体の見直し — 偽 halt が解消されれば不当昇格も止まるため、ポリシー側は触らない

## Open Questions

1. **修正範囲: step スコープ化のみ(案 a)か、gate 状態 fingerprint も併せる(案 a+b)か** — 案 a 単独ではクロス phase 誤発火は解消するが、同一 step 内で「review クリーンのまま uncovered が 3→1 件に減る」正当な前進を依然 sameness と誤認する。
   → **Resolved(Gate ① 承認, 2026-06-11)**: 案 a+b 両方を実施する。
