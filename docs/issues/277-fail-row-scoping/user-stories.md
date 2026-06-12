# User Stories: sameness / stuck rails の比較母集団を同一 step の FAIL 行のみに絞る (#277)

## Functional Story

**I want to** `check_sameness` / `check_stuck` の比較母集団が「同一 step かつ verdict が FAIL の行」のみになる,
**so that** PASS 行や他 step の行が衝突源として混入せず、失敗が反復していないのに rails が偽停止しない.

**I want to** 設計ゲート差し戻しの再入シナリオ（同一 step のログが [PASS, PASS, FAIL] となる状態）で `check_stuck` が 0（continue）を返す,
**so that** #261 で正式サポートされた再入経路を 2 回経ただけで autopilot が偽 stuck halt せず、dogfood を続行できる.

**I want to** step 引数省略時のレガシー全ログモードでも FAIL-only フィルタが適用される,
**so that** どの呼び出しモードでも PASS 行が「失敗の反復」の証拠として扱われず、偽停止の残存経路がなくなる（Gate ① 承認済みの全モード適用方針）.

**I want to** `check_sameness` / `check_stuck` の関数コメントと `skills/autopilot/SKILL.md` の rails 説明が「同一 step の FAIL 行のみ」という実態の検出意味論に同期されている,
**so that** 実装とドキュメントの乖離なく rails の挙動を理解・保守できる.

## Constraint Story (Non-Functional)

**I want to** 真の失敗反復（同一 step の FAIL 行 fingerprint の連続一致 / window 内重複）の検出が FAIL-only フィルタ導入後も従来どおり機能し、既存 BATS が green のまま維持される,
**so that** 偽停止の修正と引き換えに安全レール本来の検出力が弱まらない.

**I want to** PASS 行混入シナリオ（[PASS, PASS, FAIL] で continue になること）が `tests/test_autopilot_convergence.bats` 等の回帰テストとして固定されている,
**so that** 将来の rails 変更で同種の偽停止バグが再発してもテストで即検出できる.
