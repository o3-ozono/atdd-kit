# User Stories: autopilot Workflow の `agent()` null フェイルセーフ化（#292）

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### FS-1: at-gate の null をループ継続で吸収

**I want to** at-gate の `agent()` が null を返しても workflow がクラッシュせず、当該 iteration を「AT gate 未通過」として扱いループを継続できる,
**so that** モデルアクセスの transient 障害で AT ゲートのサブエージェントが死亡しても、収束ループ内で自然にリトライされ run 全体が落ちない.

### FS-2: coverage の null をループ継続で吸収

**I want to** coverage の `agent()` が null を返しても workflow がクラッシュせず、当該 iteration を「coverage gate 未通過」（`uncovered = []`）として扱いループを継続できる,
**so that** AC→AT カバレッジ判定の transient 死亡が run 全体のクラッシュにならず、次イテレーションで再評価される.

### FS-3: review の null を未収束扱いでループ継続

**I want to** review（`verdict`）の `agent()` が null を返しても workflow がクラッシュせず、当該 iteration を「未収束」（`overall_correctness` 不一致・findings 無し）として扱いループを継続できる,
**so that** レビューサブエージェントの transient 死亡で run を落とさず、収束を諦めずに継続できる.

### FS-4: freeze の null をフェイルクローズで安全終了

**I want to** freeze（`frozen`）の `agent()` が null を返した場合、workflow がクラッシュせず `COMPLETED_WITH_DEBT`（reason 系: `freeze-error`）で安全に終了する,
**so that** anchor が確定しないまま走って AL-2（不変アンカー）が崩れる事態を防ぎ、安全側で停止できる.

### FS-5: audit の null をフェイルクローズで安全終了

**I want to** audit（`rec`）の `agent()` が null を返した場合、workflow がクラッシュせず `COMPLETED_WITH_DEBT`（reason: `record-error`）で安全に終了する,
**so that** 監査記録（AL-4）が確定しないまま継続せず、既存の `recordOk !== true` 経路と同じく安全側で停止できる.

### FS-6: rails の null をフェイルクローズで halt

**I want to** rails（`r`）の `agent()` が null を返した場合、workflow がクラッシュせず halt（`COMPLETED_WITH_DEBT`, reason: `rails-error`）で安全に終了する,
**so that** レール判定を計算できないときに走り続けず、安全側で停止できる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1: null は決して fail-open しない（フェイルセーフ不変条件）

**I want to** いずれの null 経路も「収束済み / PASS」と誤判定せず、必ず fail-safe（ループ継続 or フェイルクローズ）に倒れる,
**so that** transient 障害が誤って成功・収束とみなされて未検証の成果物が通ることがない.

### CS-2: ループ継続経路が無限ループにならない

**I want to** null をループ継続として扱う経路（FS-1/FS-2/FS-3）でも `check_max_iterations` レールが上限を担保する,
**so that** 恒久的な障害でも run が無限にリトライし続けず、上限到達で安全に停止する.

### CS-3: Skill 変更はテスト証跡と行バジェットを満たす

**I want to** 変更が `skills/autopilot/SKILL.md` の Workflow スクリプトに反映され、`tests/test_autopilot_skill.bats` に null フェイルセーフの構造アサーションが追加され、既存 BATS スイートが green を維持し、SKILL.md が行バジェット（280 行）以内に収まる,
**so that** DEVELOPMENT.md「Skill Changes Require Test Evidence」と行バジェット（第 3 回引き上げ不可）を遵守し、in-line ガード中心で行数増を最小化できる.
