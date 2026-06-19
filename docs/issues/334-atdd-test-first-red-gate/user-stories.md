# User Stories: ATDD の test-first（AT red 先行）を構造的に担保する

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### F1: 決定的 red ゲート（A / Hard）

**I want to** 新規 AT について実装着手前に当該 AT を実行して red（非0 exit）を deterministic に記録し、red 証跡が無い限り impl phase が前進・収束（satisfaction oracle を満たすこと）できないようにする,
**so that** AT が「実装の事後追認」になるのを機械的に防ぎ、test-first が green ゲート（AL-3）と対称な決定的ガードで担保される.

### F2: test/impl コミット分離による red→green の機械検証（A）

**I want to** test コミットと impl コミットの分離を必須化し、`red→green` の粒度をコミット履歴から機械検証できるようにする,
**so that** 1 コミットに test と実装が混在して red→green の順序が検証不能になる事態を避けられる.

### F3: Gate③後フィードバックの正規ルート（B / 規模で使い分け）

**I want to** autopilot ライフサイクルに「Gate③後フィードバックで新ACが生じたら直接実装せず、規模で分岐（小=設計アンカー不変・少数AC は同一Issue内の design 差し戻し / 大=設計アンカー変更を伴うまとまった新機能は新Issue）する」正規ルートを methodology / autopilot-iron-law に明文化する,
**so that** Gate③後の新ACをオーケストレータが autopilot の外で先行実装して AT を後付けする逸脱を防げる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### C1: red ゲートの決定性（A の品質特性）

**I want to** red ゲートが LLM の自律判断ではなく exit code に基づく deterministic な判定で成立している,
**so that** 無人運転フェーズでもエージェントのブレに依存せず、green だが事後追認の AT が無検出で量産されない.

### C2: 効率は逸脱理由にしない（C / 横断ルール）

**I want to** 「効率（session limit / トークン / 速さ）は test-first 逸脱の理由にしない」が Iron Law（`docs/methodology/autopilot-iron-law.md`）/ `rules/atdd-kit.md` に文言として明記されている,
**so that** 効率を口実にした test-first 逸脱が規範上も明確に禁止される.
