# Acceptance Tests: check_sameness / check_stuck の step スコープ化と gate 状態 fingerprint — 偽 sameness halt の解消

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

実行形態: BATS（`tests/test_autopilot_convergence.bats` / `tests/test_autopilot_skill.bats`）。
実行コマンド: `bats tests/test_autopilot_convergence.bats tests/test_autopilot_skill.bats`

## AT-001: クロス step 同一 fingerprint で発火しない（#269 再現） — US-1, US-2

- [x] [regression] AT-001: 別 step・別 phase のログ行が sameness の比較対象に混入しない
  - Given: autopilot-log.jsonl に design phase 最終行（step=`writing-plan-and-tests` 等、fingerprint X = 空 findings `4f53cda1…`）と impl iteration 1 の行（step=`running-atdd-cycle`、fingerprint X）が連続して記録されている
  - When: `check_sameness <log> running-atdd-cycle` を step 引数付きで実行する
  - Then: exit code 0（continue）— 同一 step の行が 1 行しかないため sameness は成立せず、#269 の偽 halt が再現しない

## AT-002: 同一 step 内の真の停滞は従来どおり halt — US-2, US-6

- [x] [regression] AT-002: step スコープ化しても検出力が後退しない（sameness）
  - Given: 同一 step の行が連続 2 行、同一 fingerprint でログに記録されている
  - When: `check_sameness <log> <その step>` を実行する
  - Then: exit code 非ゼロ（halt）— 同一 step 内の反復停滞は従来どおり検出される

## AT-003: step 引数省略時の後方互換 — US-5

- [x] [regression] AT-003: step 省略時はログ全体を単一系列とする現行挙動が維持される
  - Given: AT-001 と同じクロス step 同一 fingerprint のログがある
  - When: `check_sameness <log>` を step 引数なしで実行する
  - Then: exit code 非ゼロ（現行挙動どおり末尾 2 行比較で halt）。かつ既存の `check_sameness` / `check_stuck` 系 BATS が無修正のまま green

## AT-004: check_stuck の step スコープ化 — US-1, US-2, US-6

- [x] [regression] AT-004a: 別 step 行は window の母集団から除外される
  - Given: 別 step の行を挟んで対象 step の fingerprint がすべて異なるログ（対象 step 系列は正当な前進）がある
  - When: `check_stuck <log> 3 <対象 step>` を実行する
  - Then: exit code 0（continue）— 別 step 行との重複起因では発火しない

- [x] [regression] AT-004b: 同一 step 内の真の停滞（flatline: A,A,A）は halt
  - Given: 対象 step の行が window 内で A,A,A（flatline）の fingerprint 系列を持つログがある
  - When: `check_stuck <log> 3 <対象 step>` を実行する
  - Then: exit code 非ゼロ（halt）— AL-5 の無限ループ防止の検出力が維持される

- [x] [regression] AT-004c: 同一 step 内の真の停滞（oscillation: A,B,A）は halt
  - Given: 対象 step の行が window 内で A,B,A（oscillation）の fingerprint 系列を持つログがある
  - When: `check_stuck <log> 3 <対象 step>` を実行する
  - Then: exit code 非ゼロ（halt）— fix-one / break-another の振動パターンも無限ループ防止として検出される

## AT-005: Workflow script の step 引き渡し構造 pin — US-3

- [x] [regression] AT-005: canonical Workflow script が rails 呼び出しに現在の step を渡している
  - Given: `skills/autopilot/SKILL.md` の canonical Workflow script（rails ステップ）
  - When: `tests/test_autopilot_skill.bats` の構造 pin（grep）を実行する
  - Then: `check_sameness "<log>" "${step}"` / `check_stuck "<log>" 3 "${step}"` 形式の呼び出しが存在し、step なしの旧形式呼び出しが script 内に存在しない

## AT-006: 監査 fingerprint の oracle 状態込み拡張の構造 pin — US-4

- [x] [regression] AT-006: audit payload が oracle 状態込み JSON に拡張されている
  - Given: `skills/autopilot/SKILL.md` の audit ステップ（`label: audit:${step}`）
  - When: `tests/test_autopilot_skill.bats` の構造 pin（grep）を実行する
  - Then: payload が `JSON.stringify({ atGreen, coverageOk, uncovered, blocking })` であり、旧 `JSON.stringify(blocking)` 単独 payload が存在しない。`uncovered` は payload より前にループスコープで宣言・代入されている

## AT-007: 全スイート green（変更の総合保証） — US-7

- [x] [regression] AT-007: 両 BATS スイートがフル実行で green
  - Given: 実装・テスト変更がすべて適用されたワークツリー
  - When: `bats tests/test_autopilot_convergence.bats tests/test_autopilot_skill.bats` を実行する
  - Then: exit code 0（全テスト green）— DEVELOPMENT.md「Skill Changes Require Test Evidence」準拠

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
