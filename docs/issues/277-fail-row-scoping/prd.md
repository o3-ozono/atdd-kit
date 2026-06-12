# PRD — sameness / stuck rails の比較母集団を同一 step の FAIL 行のみに絞る (#277)

## Problem

stockbot-jp Issue #61 の impl phase 実走で、reviewer PASS / blocking 0 件 / AT green にもかかわらずカバレッジゲートのみ false のイテレーションが `sameness-detector` で偽停止した。Issue #277 が挙げた 2 つの原因のうち、以下は #273（merged）で解消済み:

1. ~~fingerprint ペイロードが blocking findings のみ~~ → audit payload は `{atGreen, coverageOk, uncovered, blocking}` に拡張済み（oracle 全否決要因を含む）
2. ~~check_sameness / check_stuck がログ全行を比較~~ → `_fingerprints` の step スコープ化済み

**残存バグ**: `_fingerprints` は同一 step の **PASS 行**も比較母集団に含める。PASS 行のペイロードは収束状態を表す定数（design phase では常に `{atGreen:true, coverageOk:true, uncovered:[], blocking:[]}`）のため、同一 step の全 PASS 行が同一 fingerprint になる。

具体的な誤停止シナリオ（設計ゲート差し戻しの再入で発生）:
- run 1: step が PASS で収束 → log に PASS 行 A
- 設計ゲート差し戻し → run 2: 同 step が再収束 → log に PASS 行 B（fingerprint = A）
- 再差し戻し → run 3: iteration 1 が FAIL → rails 評価時、`check_stuck`（window 3）の母集団が [PASS-A, PASS-B, FAIL] となり distinct(2) < count(3) → **偽 stuck halt**

PASS 行は「同じ失敗の繰り返し」の証拠になり得ない（sameness / stuck は失敗の反復を検出するレール）にもかかわらず、母集団に混入して衝突源になっている。

## Why now

- #273 の step スコープ化により頻度は下がったが、設計ゲート差し戻し再入（#261 で正式サポートされた経路）を 2 回経るだけで再現する。autopilot の実用上の主経路で偽停止が残っている
- #277 は実走インシデント起点の type:bug であり、autopilot dogfood の続行をブロックする

## Outcome

- `check_sameness` / `check_stuck` の比較母集団が「同一 step の FAIL 行のみ」になり、PASS 行・他 step の行は一切寄与しない
- 上記の再入シナリオ（[PASS, PASS, FAIL]）で `check_stuck` が 0（continue）を返す
- 真の失敗反復（同一 step の FAIL 行 fingerprint が連続一致 / window 内で重複）の検出は従来どおり機能する（既存 BATS が green のまま）

## What

- `lib/autopilot_convergence.sh` の行フィルタを拡張し、`verdict` フィールドが `FAIL` の行のみを fingerprint 抽出対象にする（step フィルタとの AND）
- `check_sameness` / `check_stuck` の関数コメント（検出意味論）を「同一 step の FAIL 行のみ」へ更新
- 該当 BATS テスト（`tests/test_autopilot_convergence.bats` 等）に PASS 行混入シナリオの回帰テストを追加
- `skills/autopilot/SKILL.md` の rails 説明・doc 参照（doc-sync-checklist に従い該当箇所のみ）を実態へ同期

## Non-Goals

- fingerprint ペイロード構成の変更 — #273 で解消済み（oracle 全否決要因を含む）
- step スコープ化の再設計 — #273 で解消済み
- `check_log_integrity` / `check_max_iterations` / pin 系の変更 — 本件の原因と無関係
- record_iteration の JSONL スキーマ変更 — `verdict` フィールドは既に PASS/FAIL を記録しており、追加情報は不要
- autopilot オーケストレータ（SKILL.md の Workflow スクリプト）の呼び出しシグネチャ変更 — lib 側のフィルタ変更で完結する

## Open Questions

- **FAIL-only フィルタの適用範囲**: step 引数省略時（レガシー全ログモード）にも FAIL-only を適用するか。
  - 推奨: **適用する**（sameness / stuck の意味論上、PASS 行はどのモードでも「失敗の反復」の証拠にならない。レガシーモードを「PASS 行込み」のまま残すと同じ偽停止がレガシー経路に残存する）
  - 代替: step 指定時のみ FAIL-only とし、省略時は完全互換を維持する
