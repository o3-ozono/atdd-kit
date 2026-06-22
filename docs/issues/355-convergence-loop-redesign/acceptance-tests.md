# Acceptance Tests: autopilot 収束ループ＋review ラウンドの根本再設計 — done を堅牢に認識して止まる

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     不変条件で書く（plugin version / 日付 / 行数の point-in-time pin を禁止 #289）。 -->

## AT-355-F8: red.jsonl への SHA 直接記録による red-gate 堅牢化（記録層）

- [x] [green] AT-355-F8-1: record_red_evidence が test SHA と impl baseline SHA の両方を red.jsonl へ記録する
  - Given: 一時 git リポジトリと空の red.jsonl がある
  - When: `record_red_evidence` を red 観測時点の test-commit SHA・impl baseline SHA・AT ファイル名で呼ぶ
  - Then: red.jsonl の追記行に `commit`（test SHA）と impl baseline SHA の両フィールドが含まれ、JSON として整形されている

- [x] [green] AT-355-F8-2: check_red_evidence は git log 考古学ではなく red.jsonl の記録値で判定する
  - Given: red.jsonl に test SHA の red 記録があり、test commit が impl commit の祖先である
  - When: `check_red_evidence` を test_sha / impl_sha / red.jsonl で呼ぶ
  - Then: exit 0（redObserved=true）を返し、判定が AT ファイルへの git log 探索（commits touching tests/acceptance）に依存しない

- [x] [green] AT-355-F8-3: 記録の無い／改竄された test SHA で fail-closed
  - Given: red.jsonl に該当 test SHA の記録が無い、または ancestry が成立しない
  - When: `check_red_evidence` を呼ぶ
  - Then: 非 0（fail-closed）を返し、redObserved=false と確定する

- [x] [green] AT-355-F8-4: running-atdd-cycle の record_red_evidence 呼び出し契約が impl SHA 記録を含む
  - Given: `skills/running-atdd-cycle/SKILL.md` の Confirm RED 節
  - When: 節を読む
  - Then: red 観測時点で test SHA と impl baseline SHA の両方を red.jsonl へ記録する契約が記述されている（`tests/test_running_atdd_cycle_skill.bats` が pin）

- [x] [green] AT-355-F8-5: autopilot SKILL の red-gate 手順から SHA 推測（git log 考古学）が排除されている
  - Given: `skills/autopilot/SKILL.md` の red-gate 呼び出し手順
  - When: 手順を読む
  - Then: 「search git log for commits touching tests/acceptance」「git rev-parse HEAD / awk NR==2」相当の SHA 推測ステップが存在せず、red.jsonl の記録済み SHA を読む手順になっている

## AT-355-F2: gate-unverifiable 停止理由の追加（ループ層）

- [x] [green] AT-355-F2-1: record_halt が gate-unverifiable reason を受理する
  - Given: 一時 JSONL ログ
  - When: `record_halt` を reason `gate-unverifiable` で呼ぶ
  - Then: `outcome":"HALT"` かつ `reason":"gate-unverifiable"` の HALT 行が追記される

- [x] [green] AT-355-F2-2: 未知 reason は従来どおり拒否される（enum 不変条件）
  - Given: 一時 JSONL ログ
  - When: `record_halt` を enum 外の reason で呼ぶ
  - Then: 非 0 を返し HALT 行を書かない（enum 検証の fail-safe を維持）

## AT-355-F1: 停止理由の二分類（ループ層）

- [x] [green] AT-355-F1-1: autopilot が成果物未完成と機構自己検証失敗を別クラスとして扱う
  - Given: `skills/autopilot/SKILL.md` のオラクル／停止条件レール
  - When: レールを読む
  - Then: (i) 成果物未完成（review findings 残存 / tests red）→ 継続、(ii) 機構自己検証失敗（red-gate SHA / tooling 不全）→ MAX まで空転させず早期手放し、の二分類が記述されている

- [x] [green] AT-355-F1-2: demonstrably-done だが機構未確証なら gate-unverifiable へ分岐する
  - Given: review=correct ＋ tests green ＋ 残るは機構問題のみの状態
  - When: 機構の自己検証が失敗する
  - Then: SKILL は auto-converge せず `gate-unverifiable` で早期に人間 escalation するロジックを記述している（MAX_ITERATIONS まで回さない）

## AT-355-F3: 多視点合議制レビュー（レビュー層）

- [x] [green] AT-355-F3-1: N=3 パネルと 2/3 majority 採用が Aggregate 規則に明記される
  - Given: `skills/reviewing-deliverables/SKILL.md`
  - When: パネル構成と Aggregate 規則を読む
  - Then: N=3（機能正当性 / 安全性 / 設計妥当性）で、2/3 以上が同一所見を blocker/major と判定した場合のみ採用するルールが記述されている

- [x] [green] AT-355-F3-2: 単一レンズの単独判定は severity を一段下げる
  - Given: 同上 SKILL の severity 規則
  - When: 規則を読む
  - Then: 単一レンズの単独所見は severity を一段下げる旨が明記されている（`tests/test_reviewing_deliverables_skill.bats` が pin）

## AT-355-F4: ラウンド横断の収束／停止条件（レビュー層）

- [x] [green] AT-355-F4-1: CONVERGED の二条件が記述される
  - Given: `skills/reviewing-deliverables/SKILL.md` の停止条件
  - When: 停止条件を読む
  - Then: (a) 新規 blocker/major ゼロ、または (b) 残存が「設計判断」「スコープ外」タグのみ で CONVERGED（条件付き PASS）を返す旨が記述されている

- [x] [green] AT-355-F4-2: 最大ラウンド数上限が設けられている
  - Given: 同上 SKILL
  - When: ラウンド制御を読む
  - Then: 最大ラウンド数の上限が定義され、無限 FAIL ラウンドが構造的に防がれている

## AT-355-F5: スコープガードによる out-of-scope 分離（レビュー層）

- [x] [green] AT-355-F5-1: Scout が PRD/US から境界を抽出し out-of-scope を分離する
  - Given: `skills/reviewing-deliverables/SKILL.md` の Scout
  - When: Scout の責務を読む
  - Then: Issue の PRD/US から境界を抽出し、対象外ファイル／関心事の所見を `out-of-scope` タグで分離（FAIL 要因にせず follow-up 起票候補へ回す）する旨が記述されている

## AT-355-F6: 設計判断のラウンド間記憶（レビュー層）

- [x] [green] AT-355-F6-1: 意図的トレードオフは合議で不当判定されない限り再提出されない
  - Given: `skills/reviewing-deliverables/SKILL.md`
  - When: 設計判断の扱いを読む
  - Then: docstring/ADR で「意図的トレードオフ」と宣言された点を round 間で記憶し、合議で「設計として不当」と判定されない限り再提出しない旨が記述されている

## AT-355-F7: severity 較正の単一化（レビュー層）

- [x] [green] AT-355-F7-1: レンズ横断マージ後に 1 回だけ severity を付与する
  - Given: `skills/reviewing-deliverables/SKILL.md` の severity 付与フロー
  - When: フローを読む
  - Then: レンズ横断で同一所見をマージしてから 1 回だけ severity を付与し、レンズ別の重複付与を排除する旨が記述されている

## AT-355-C1: 収束性の保証（横断品質特性）

- [x] [green] AT-355-C1-1: demonstrably-done が単一脆弱 signal に veto されて MAX 空転しない
  - Given: #341 再現シナリオ（review correct ＋ AT 全 green ＋ red.jsonl に赤観測あり、ただし旧 SHA 解決なら false-negative になる状況）
  - When: 再設計後の収束ループを回す
  - Then: redObserved が記録値ベースで true 確定し、MAX_ITERATIONS まで空転せず収束する
  - Note: フル headless 再現不可のため SKILL pin + lib unit で代替（plan.md lines 65-66）。`test_autopilot_skill.bats AT-355-C1-1` が pin（converged 式に redObserved 含む + check_red_evidence が red.jsonl 記録値ベース）。lib unit は `test_autopilot_convergence.bats AT-355-F8-2/F8-3/C2-1` が保証。

- [x] [green] AT-355-C1-2: 機構自己検証失敗が早期 escalation される
  - Given: 機構の自己検証が失敗するシナリオ
  - When: 収束ループを回す
  - Then: MAX_ITERATIONS まで回さず `gate-unverifiable` で早期に人間 escalation する
  - Note: フル headless 再現不可のため SKILL pin で代替（plan.md lines 65-66）。`test_autopilot_skill.bats AT-355-C1-2` が pin（`gateUnverifiable` ブロックが rails check より前に位置し `COMPLETED_WITH_DEBT reason: 'gate-unverifiable'` を返す構造）。

- [x] [green] AT-355-C1-3: review が有限ラウンド内で CONVERGED へ到達する
  - Given: #345 再現シナリオ（前ラウンド blocker 全解消後に別角度の新所見が湧き続ける状況）
  - When: review ラウンドを回す
  - Then: 「新規 blocker/major ゼロ」または「設計判断/スコープ外のみ残存」で有限ラウンド内に CONVERGED へ到達する
  - Note: フル headless 再現不可のため SKILL pin で代替（plan.md lines 65-66）。`test_reviewing_deliverables_skill.bats AT-355-C1-3` が pin（CONVERGED 二条件 + 最大ラウンド数上限 3 rounds + 無限ループ防止の明記）。

## AT-355-C2: red-gate 判定の決定性（記録層品質特性）

- [x] [green] AT-355-C2-1: redObserved 判定がイテレーション数・履歴形状に依存しない
  - Given: 同一 red.jsonl 記録に対し、イテレーション数・コミット履歴形状の異なる複数状況
  - When: `check_red_evidence` を記録済み SHA で評価する
  - Then: いずれの状況でも同一の deterministic な結果（記録あり→0 / 記録なし→非 0）を返し、git log 探索の履歴依存が無い

## AT-355-C3: User gate 構造・Non-Goals 境界の不変性（横断制約）

- [x] [green] AT-355-C3-1: 3ゲート（AL-1）の User gate 数・位置が不変
  - Given: `skills/autopilot/SKILL.md`
  - When: 変更前後の User gate 構造を比較する
  - Then: requirements 承認 / design 承認 / merge の 3ゲートの数・位置が変わっていない

- [x] [green] AT-355-C3-2: red-first 方針（#334）と coverage/atGreen 内部判定が不変
  - Given: 変更後の skills/lib
  - When: red-first の必須性（AT が impl 前に赤）と coverage-gate/atGreen の内部判定アルゴリズムを確認する
  - Then: red-first 方針そのもの・coverage/atGreen の内部判定ロジックは変わらず、変更は SHA の記録方法・停止理由分類・escalation 早期化に留まっている

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
