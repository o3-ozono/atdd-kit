# User Stories: check_sameness / check_stuck の step スコープ化と gate 状態 fingerprint — 偽 sameness halt の解消

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: `_fingerprints` の step フィルタ

**I want to** `lib/autopilot_convergence.sh` の `_fingerprints <jsonl> [step]` が第 2 引数を受け取り、指定時は `"step":"<step>"` の行のみを fingerprint 系列として返す,
**so that** 別 step・別 phase のログ行が単一系列に混入せず、反復比較の母集団が同一 step に限定される.

### US-2: `check_sameness` / `check_stuck` への step 引数透過

**I want to** `check_sameness <jsonl> [step]` と `check_stuck <jsonl> <window> [step]` が step 引数を `_fingerprints` に透過し、同一 step の系列だけで sameness / stuck を判定する,
**so that** 「design phase 最終行」と「impl iteration 1」のようなクロス step 比較による誤発火（#269 の偽 halt）が構造的に起こらなくなる.

### US-3: Workflow script からの step 引き渡し

**I want to** `skills/autopilot/SKILL.md` の canonical Workflow script が rails 呼び出しで `check_sameness "<log>" "<step>"` / `check_stuck "<log>" 3 "<step>"` と現在の step を渡している,
**so that** step スコープ化がオーケストレーター側で配管漏れなく毎イテレーション有効になる.

### US-4: 監査 fingerprint の oracle 状態込み拡張

**I want to** 監査 fingerprint の payload が blocking findings 単独から oracle 状態込み（`{atGreen, coverageOk, uncovered, blocking}` の JSON）へ拡張されている,
**so that** 「review クリーン × deterministic gate FAIL」でも gate 状態の変化（uncovered 3→1 件等の正当な前進）が別 fingerprint として現れ、sameness と区別できる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### US-5: step 引数省略時の後方互換

**I want to** `check_sameness` / `check_stuck` の step 引数省略時はログ全体を単一系列とする現行挙動が維持されている,
**so that** 既存の呼び出し箇所・既存 BATS が変更なしに動作し続け、移行に伴う回帰が入らない.

### US-6: 検出力の後退なし

**I want to** 同一 step 内で oracle 状態（findings + gate 状態）に変化がない真の停滞では sameness / stuck が従来どおり halt する,
**so that** 偽 halt の解消と引き換えに無限ループ防止（AL-5）の検出力が弱まらない.

### US-7: BATS による回帰保証

**I want to** `tests/test_autopilot_convergence.bats` に #269 再現の回帰テスト（別 step 行とのクロス比較で発火しない / 同一 step の真の停滞では発火する / step 引数省略時の現行挙動維持）が追加され、`tests/test_autopilot_skill.bats` の構造 pin（step 引き渡し・payload 拡張）も更新されたうえで両スイートが green である,
**so that** 誤発火 2 因子の修正が継続的に検証され、skill 変更が DEVELOPMENT.md「Skill Changes Require Test Evidence」に準拠する.
