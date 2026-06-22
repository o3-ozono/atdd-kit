# User Stories: autopilot 収束ループ＋review ラウンドの根本再設計 — done を堅牢に認識して止まる

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### F1: 停止理由の二分類（ループ層 — オラクル再設計）

**I want to** autopilot 収束ループが「成果物そのものの未完成（review findings 残存 / tests red）」と「ゲート機構の自己検証失敗（SHA 解決失敗・tooling 不全）」を別クラスの停止理由として区別し、後者を MAX_ITERATIONS まで空転させず早期に手放せるようにする,
**so that** 単一の脆弱な deterministic signal が、demonstrably done（review PASS ＋ tests green）な成果物を veto して約2時間・大量トークンを空転で浪費する事態を構造的に防げる.

### F2: gate-unverifiable による早期 escalation（ループ層）

**I want to** review が correct かつ tests green かつ残るが機構問題のみという状態で機構の自己検証が失敗した場合に、オラクルが auto-converge せず `gate-unverifiable` という distinct な停止理由で早期に人間へ escalation する,
**so that** done に到達しているのに機構が確証できないケースを、回数上限まで回さず人間が即座に引き取って判断できる.

### F3: 多視点合議制レビュー（レビュー層 — 旧 #345 を集約）

**I want to** reviewing-deliverables が単一敵対パネルではなく独立した N=3 パネル（機能正当性 / 安全性 / 設計妥当性）を並列実行し、2/3 以上が同一所見を blocker/major と判定した場合のみ採用（単一レンズの単独判定は severity を一段下げる）するようにする,
**so that** 単一レンズの偽陽性所見が FAIL を引き起こして収束を阻害するのを抑え、合意された所見だけがマージ判断に効く.

### F4: ラウンド横断の収束／停止条件（レビュー層）

**I want to** review がラウンドをまたいで所見を追跡し、(a) 新規 blocker/major がゼロ、または (b) 残存が「設計判断」「スコープ外」タグのみ、で CONVERGED（条件付き PASS）を返し、最大ラウンド数の上限も設ける,
**so that** 「常に何かを探す」敵対レビューが別角度の新所見を湧かせ続けて無限に FAIL する（stockbot-jp #7 の4ラウンド連続 FAIL のような）状況を、有限ラウンド内で停止できる.

### F5: スコープガードによる out-of-scope 分離（レビュー層）

**I want to** Scout が Issue の PRD/US から境界を抽出し、対象外ファイル／関心事に対する所見を `out-of-scope` として分離（FAIL 要因にせず follow-up 起票候補へ回す）するようにする,
**so that** スコープ外の指摘が収束を阻害せず、本 Issue のマージ判断とスコープ外の改善が混線しない.

### F6: 設計判断のラウンド間記憶（レビュー層）

**I want to** 実装側が docstring/ADR で「意図的トレードオフ」と宣言した点を review が round 間で記憶し、合議で「設計として不当」と判定されない限り再提出しないようにする,
**so that** 解決済み・意図的と確定した設計判断が毎ラウンド蒸し返されて振動する（P0 数が 多→4→0→1 と振動するような）のを防げる.

### F7: severity 較正の単一化（レビュー層）

**I want to** レンズ横断で同一所見をマージしてから 1 回だけ severity を付与する（レンズ別の重複付与を排除する）ようにする,
**so that** 同じ所見が複数レンズから別個に severity を付けられて過大評価され、FAIL 判定を不当に押し上げるのを防げる.

### F8: red.jsonl への SHA 直接記録による red-gate 堅牢化（記録層 — triggering instance の修正）

**I want to** running-atdd-cycle が red 観測時点で test/impl SHA を red.jsonl に直接記録し、red-gate（`check_red_evidence`）が git log 考古学で SHA を推測せず記録済みの値を読むだけにする,
**so that** 多イテレーションで SHA 解決が false-negative 化して `redObserved=false` がオラクルを veto する triggering instance が再発しなくなる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### C1: 収束性の保証（ループ全体の品質特性）

**I want to** 再設計後の収束ループが #341 / #345 の再現シナリオで、(a) demonstrably-done が単一の脆弱 signal に veto されて MAX 空転しない、(b) 機構の自己検証失敗が早期 escalation される、(c) review が有限ラウンド内で CONVERGED へ到達する、のすべてを満たす,
**so that** 無限ラウンド・MAX_ITERATIONS 空転が排除され、収束時間とトークンコストが大幅に削減される.

### C2: red-gate 判定の決定性（記録層の品質特性）

**I want to** red-gate の `redObserved` 判定が git log 考古学による推測ではなく red.jsonl の記録済み SHA に基づく deterministic な判定で成立している,
**so that** 無人運転フェーズでもイテレーション数や履歴形状に依存せず、再現性のある赤証跡判定が得られる.

### C3: User gate 構造の不変性（横断制約）

**I want to** 本 Issue の変更が 3ゲート（AL-1）の User gate の数・位置・red-first 方針（#334）そのもの・coverage-gate/atGreen の内部判定アルゴリズムを変えず、停止理由の分類・escalation の早期化・SHA の記録方法のみに留まっている,
**so that** 既存の自律実行基盤の Non-Goals 境界を侵さず、収束性改善が他の確立済みレールへ波及しない.
