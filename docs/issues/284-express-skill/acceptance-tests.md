# Acceptance Tests: express skill の再導入 — 機能破壊リスクのないドキュメント級タスクの省略経路

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

> **検証方式の注記:** 本 Issue の成果物は SKILL.md / コマンド / ドキュメントであるため、
> 各 AT は Step 4（running-atdd-cycle）で `tests/test_express_skill.bats` 等の
> BATS 構造アサーションとして実装する（`docs/testing-skills.md` の Unit Test 方式）。

## AT-001: コマンド発動と Issue 駆動ガード（US-1 / AC1 / AC3）

- [x] [regression] AT-001: express は明示コマンドでのみ発動し、Issue なしでは起動エラーになる
  - Given: `skills/express/SKILL.md` と `commands/express.md` が存在する
  - When: SKILL.md の発動条件と Step 1（入力検証）を検査する
  - Then: 発動は `/atdd-kit:express <issue>` の明示起動のみ（keyword 検出の implicit 発動記述がない）であり、Issue 番号なし・Issue not found・closed・`in-progress` 付きの各ケースで STOP するエラー分岐が記述されている

## AT-002: 発動承認ゲート（US-1 / AC1）

- [x] [regression] AT-002: ユーザの明示的承認なしには開始されない
  - Given: `skills/express/SKILL.md` の Step 2
  - When: 承認ゲートの記述を検査する
  - Then: `<APPROVAL-GATE>` ブロックが存在し、ユーザの明示的承認 + 該当 OK 基準（理由）の提示なしに先へ進むことを禁止している

## AT-003: 適用基準の文書化と入口判定（US-2 / AC2）

- [x] [regression] AT-003: OK/NG 基準が文書化され、迷ったらフルフローへ案内される
  - Given: `skills/express/SKILL.md`
  - When: 適用基準セクションを検査する
  - Then: OK 例（docs/README 追記・typo・コメント・gitignore・バージョン bump のみ等）と NG 例（新機能・振る舞い変更・依存追加・CI/hooks 変更・セキュリティ影響等）の双方が記述され、NG・判定に迷う場合はフルフロー（`/atdd-kit:defining-requirements <n>`）へ誘導する記述がある

## AT-004: 中間成果物ゼロの最短経路（US-3）

- [x] [regression] AT-004: express は中間成果物を一切作らない
  - Given: `skills/express/SKILL.md` の全文
  - When: ランタイムフロー（branch 作成 → 実装 → commit → PR 作成）を検査する
  - Then: `docs/issues/<NNN>/` 配下の成果物（PRD / US / plan / AT / レビューレポート）を生成する手順が存在せず、中間成果物を作らないことが明記されている

## AT-005: PR での識別と理由の記録（US-4 / AC5 / AC6）

- [x] [regression] AT-005: express PR には `express-mode` ラベルと理由セクションが必ず付く
  - Given: `skills/express/SKILL.md` の PR 作成ステップ
  - When: PR 作成手順を検査する
  - Then: `express-mode` ラベルの付与と、PR body の固定セクション `## Express Mode`（適用基準のどれに該当したかの理由）が必須として記述され、ラベル欠落時は `/atdd-kit:setup-github` を案内している。`commands/setup-github.md` に `express-mode` ラベル作成行が存在する

## AT-006: skill-gate との統合（US-5 / AC8）

- [x] [regression] AT-006: skill-gate が express 経路を正規ルートとして認識する
  - Given: `skills/skill-gate/SKILL.md`
  - When: Pre-check: Issue Work Routing を検査する
  - Then: 明示的な `/atdd-kit:express <issue>` 発動を正規ルートとして認識し、defining-requirements への誘導やブロックを行わない分岐が存在する（`bats tests/test_skill_gate_collision.bats` は green のまま）

## AT-007: スコープ逸脱時のフルフロー切替（US-6 / AC9）

- [x] [regression] AT-007: diff が適用基準を超えたら express を中断しフルフローへ切り替える
  - Given: `skills/express/SKILL.md`
  - When: スコープ逸脱フォールバックの記述を検査する
  - Then: 実装中に diff が適用基準を超えた場合（コードファイル接触等）に express を中断し、利用者へ報告のうえフルフロー（`/atdd-kit:defining-requirements <n>`）へ切り替える手順が記述されている

## AT-008: CI ゲートと人間 merge の維持（CS-1 / AC4）

- [x] [regression] AT-008: CI は省略されず、merge は常に人間が行う
  - Given: `skills/express/SKILL.md` の CI / merge ステップ
  - When: ゲート記述を検査する
  - Then: `<HARD-GATE>` で CI green まで merge 不可（バイパス・`--admin` 禁止）と記述され、SKILL.md 内に `gh pr merge` を自動実行する手順が存在しない（merge は人間ゲート）

## AT-009: atdd-kit 自身への適用時の DEVELOPMENT.md 遵守（CS-2 / AC7）

- [x] [regression] AT-009: 対象が atdd-kit 自身なら version bump + CHANGELOG は省略不可
  - Given: `skills/express/SKILL.md` の実装ステップ
  - When: AC7 関連の記述を検査する
  - Then: 対象リポジトリが atdd-kit 自身の場合、`.claude-plugin/plugin.json` の version bump と `CHANGELOG.md` 更新を同一 PR で行うことが必須として記述されている

## AT-010: 最小構成とリリース衛生（CS-3 / CS-4）

- [x] [regression] AT-010: SKILL.md は最小構成で、テスト・README・CHANGELOG・bump が揃っている
  - Given: 本 Issue の導入 PR の全変更
  - When: 構成とリリース整備を検査する
  - Then: `skills/express/SKILL.md` が 200 行以内で承認ゲートは APPROVAL-GATE の 1 つのみ（多段ゲート・成果物テンプレート・構造化レビューなし）。`tests/test_express_skill.bats` が存在して green、`tests/test_skill_structure.bats` の `ALL_SKILLS` に express が追加済み、`skills/README.md` / `commands/README.md` / `tests/README.md` が更新され、`CHANGELOG.md` に Added エントリ + `plugin.json` が `3.14.0` へ minor bump されている

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
