# PRD: Skill E2E テストの claude 起動に --model sonnet を指定 — モデル未指定によるトークン過大消費の解消

## Problem

Skill E2E テスト(`tests/e2e/*.bats` 全 11 ファイル)の `_run_claude` ヘルパーが `claude -p` を **`--model` 指定なし**で起動している。このためテストはセッション/グローバルのデフォルトモデル(現在 Fable 等の最上位モデル)で実行され、1 User Story = 1 `@test` × 11 skill 分のトークンが毎回最上位モデル単価で消費される。E2E は skill のトリガー・構造応答を検証するものでありモデル品質のベンチではないため、この消費は純粋な無駄コストになっている。

## Why now

ユーザーの実運用でトークン使用量が顕在化済み(本 Issue 起票の直接動機)。また #259 ベンチで「機能品質同等・コスト比 Sonnet 1.0 : Opus 2.2 : Fable 4.1」が実証され、プラグイン本体(autopilot impl / review subagent)は Sonnet 化済み — テストハーネスだけがモデル未指定のまま残っており、整合を取るタイミングとして適切。

## Outcome

- `tests/e2e/*.bats` 全 11 ファイルの `claude -p` 起動が明示的にモデルを指定する(デフォルト: **sonnet**)
- 環境変数 `SKILL_E2E_MODEL` で上書き可能(既存の `SKILL_E2E_TIMEOUT_SECS` と同じ命名規約・同じ上書き方式)
- E2E 実行 1 回あたりのトークンコストが最上位モデル比で約 1/4 になる(#259 ベンチ準拠)
- BATS suite(E2E の構造検証側)が green

## What

- 各 `tests/e2e/*.bats` の `_run_claude` に `--model "${E2E_MODEL}"` を追加する
  - ファイル冒頭の設定部に `E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"` を定義(`TIMEOUT_SECS="${SKILL_E2E_TIMEOUT_SECS:-120}"` と同じパターン)
  - `timeout` / `gtimeout` / フォールバックの全分岐に同一の `--model` フラグを追加(11 ファイル × 各分岐)
- `tests/README.md` の Skill E2E Tests 節にモデルポリシー(デフォルト sonnet・`SKILL_E2E_MODEL` で上書き)を 1-2 行追記する
- E2E 構造検証テスト(`tests/test_skill_test_coverage.bats` 等)に「全 e2e ファイルが `--model` を指定している」回帰 pin を追加する
- `CHANGELOG.md` + `.claude-plugin/plugin.json` patch bump

## Non-Goals

- `_run_claude` ヘルパーの共通ファイル化(11 ファイルの重複解消)— テストハーネスのリファクタリングは本 Issue のコスト修正と独立しており、bats の load パス設計を伴うため別 Issue とする
- headless replay fixtures(`tests/fixtures/headless/`)のモデル変更 — 既に Haiku デフォルトで運用されており(`docs/guides/headless-skill-testing.md`)、replay はモデル非依存のため対象外
- `scripts/run-skill-e2e.sh` の実行対象算定ロジックの変更 — モデル指定は bats ファイル側で完結する

## Open Questions

なし(デフォルトモデル = sonnet はユーザー指定で確定。環境変数名・追記箇所は既存規約から導出)
