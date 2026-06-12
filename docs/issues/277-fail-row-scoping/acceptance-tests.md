# Acceptance Tests: sameness / stuck rails の比較母集団を同一 step の FAIL 行のみに絞る (#277)

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-001: 設計ゲート差し戻し再入シナリオで偽 stuck halt しない

- [ ] [planned] AT-001: 同一 step の [PASS, PASS, FAIL] ログで check_stuck が continue を返す
  - Given: 同一 step の JSONL ログに PASS 行 2 件（収束状態の定数ペイロードのため同一 fingerprint）と FAIL 行 1 件が記録されている（#261 の設計ゲート差し戻し再入 ×2 の再現）
  - When: `check_stuck <log> 3 <step>` を実行する
  - Then: exit code 0（continue）— PASS 行は window 母集団から除外され、FAIL 行 1 件だけでは stuck 不成立

## AT-002: check_sameness が PASS 行を比較母集団から除外する

- [ ] [planned] AT-002: 同一 step の [PASS(fp X), FAIL(fp X)] で check_sameness が continue を返す
  - Given: 同一 step の JSONL ログに PASS 行と FAIL 行が同一 fingerprint で隣接して記録されている
  - When: `check_sameness <log> <step>` を実行する
  - Then: exit code 0（continue）— PASS 行は prev として数えず、FAIL 行は 1 件のみのため sameness 不成立

## AT-003: step 引数省略のレガシー全ログモードにも FAIL-only が適用される

- [ ] [planned] AT-003: step なし呼び出しで PASS 行が衝突源にならない
  - Given: PASS 行と FAIL 行が同一 fingerprint で隣接する複数 step 混在ログ（既存 `_make_cross_step_log` フィクスチャ）
  - When: `check_sameness <log>`（step 引数なし）を実行する
  - Then: exit code 0（continue）— Gate ① 承認の全モード適用方針どおり、レガシーモードでも PASS 行は除外される（旧 #272 AT-003 の「halt」期待値はこの新意味論へ更新する）

## AT-004: 真の失敗反復の検出力が FAIL-only 導入後も維持される

- [ ] [planned] AT-004: 同一 step の FAIL 行反復は従来どおり halt する
  - Given: 同一 step の JSONL ログに FAIL 行のみが記録されている — (a) 同一 fingerprint 連続 2 件、(b) flatline A,A,A、(c) oscillation A,B,A
  - When: (a) に `check_sameness <log> <step>`、(b)(c) に `check_stuck <log> 3 <step>` を実行する
  - Then: いずれも exit code 非ゼロ（halt）。あわせて `bats tests/test_autopilot_convergence.bats` の既存テストが全件 green（期待値変更は AT-003 (#272) の 1 件のみ）

## AT-005: 関数コメントとドキュメントが新しい検出意味論に同期されている

- [ ] [planned] AT-005: lib コメント・SKILL.md・iron-law doc・skills/README・lib/README が「同一 step の FAIL 行のみ」を記載する
  - Given: FAIL-only フィルタの実装が完了している
  - When: `lib/autopilot_convergence.sh` の `_fingerprints` / `check_sameness` / `check_stuck` コメント、`skills/autopilot/SKILL.md` の rails 説明、`docs/methodology/autopilot-iron-law.md` の sameness/stuck 記述、`skills/README.md` の autopilot 行、`lib/README.md` の autopilot_convergence.sh 行を確認する
  - Then: いずれも「同一 step かつ verdict=FAIL の行のみを比較する」検出意味論（#277）が記載され、実装と乖離がない（skills/README.md の #272 のみの旧記述が残っていない）

## AT-006: 跨 run の同一 FAIL fingerprint 再発は意図どおり halt する（FAIL-only 隣接の意味論 pin）

- [ ] [planned] AT-006: 同一 step の [FAIL(fp A), PASS, FAIL(fp A)] で check_sameness が halt を返す
  - Given: 同一 step の JSONL ログに FAIL 行（fingerprint A）→ PASS 行 → FAIL 行（fingerprint A）が記録されている（run 1 で 1 回 FAIL 後に収束し、設計ゲート差し戻し後の run 2 初回が同一 fingerprint で FAIL する跨 run シナリオ）
  - When: `check_sameness <log> <step>` を実行する
  - Then: exit code 非ゼロ（halt）— FAIL-only 母集団では PASS を挟んだ同一 fingerprint の FAIL 行が隣接として比較され、「同じ失敗の繰り返し」として検出される。承認済み PRD Outcome（比較母集団 = 同一 step の FAIL 行のみ・PASS 行は一切寄与しない）の直接帰結であり、従来 continue → 新規 halt となるこの経路を**意図された挙動**としてここで pin する（plan.md 前提の意味論ノート参照）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
