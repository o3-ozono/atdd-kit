# User Stories: autopilot / express 経路判定ルーティングステップ（#302）

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

**I want to** session-start の Recommended Tasks に各推奨 Issue の「推奨経路（autopilot / express）」が表示される,
**so that** Issue 選択時点で diff が無くても、どの Issue がフル ATDD 収束に向くか・どれがドキュメント級省略経路に向くかを一目で把握し、過剰プロセス（doc-grade を autopilot）や誤経路を避けて着手できる.

**I want to** 推奨経路がハイブリッド判定（決定的ガードレール: labels／キーワード + Issue title/body/labels への LLM 判断）で導出され、express 適格信号（docs/README/typo/コメント/gitignore/version-bump のみで挙動変更なし）と autopilot 信号（コード／挙動変更・新機能・CI/hooks・依存追加・セキュリティ）が定義どおりに分類される,
**so that** 経路ヒントが場当たりでなく、express の OK/NG 基準と整合した再現性のある根拠に基づくものになる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

**I want to** 判定が曖昧な Issue が安全側（autopilot＝フルフロー）にフォールバックする,
**so that** express の "when in doubt, full flow" 方針と一致し、AT／review を省く express への誤った寄せによるリスクを負わない.

**I want to** 推奨経路があくまで推奨のみで auto-route せず、ユーザーが最終的に経路を選択する状態が保たれる,
**so that** AT／review を省く express が自動実行されることによる危険を避け、人間が最終判断権を保持する.

**I want to** express の既存トリガ（明示 `/atdd-kit:express` 起動 + APPROVAL-GATE + scope-overflow abort + CI ゲート）が変更されないまま温存される,
**so that** 推奨レイヤの追加が既存の安全ゲートを置換・退行させず、現行の express 運用がそのまま機能し続ける.

**I want to** skill 変更に伴い `tests/test_session_start_task_recommendation.bats` に推奨経路の構造アサーションが追加され、既存スイートが green を維持する（autopilot SKILL.md は本 Issue では変更しない）,
**so that** behavior-shaping code である skill の変更が DEVELOPMENT.md「Skill Changes Require Test Evidence」を満たし、構造退行が検出可能になる.

**I want to** version bump + CHANGELOG 更新が同一 PR で行われる,
**so that** DEVELOPMENT.md Versioning 規約を満たし、プラグイン更新通知システムが破綻しない.

## 非スコープ境界

<!-- PRD の非スコープ節（prd.md L50-54）と整合させ、本 Issue で扱わない範囲を US 側でも明示する。 -->

- **autopilot 冒頭プリチェック（Q1b）と autopilot SKILL.md ローダ分割** — autopilot SKILL.md 行バジェット（279/280 行・第 3 回引き上げ不可）制約により follow-up Issue #304 に委譲する。本 Issue では autopilot SKILL.md を変更しない。
- express 自体の OK/NG 基準・APPROVAL-GATE・scope-overflow ロジックの変更。
- 経路の自動実行（auto-route）。
- diff ベース判定（着手前の Issue 選択時点では diff が存在しないため、Issue テキスト＋labels に依拠する）。
