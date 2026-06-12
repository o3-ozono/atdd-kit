# User Stories: Skill E2E テストの claude 起動に --model sonnet を指定 — モデル未指定によるトークン過大消費の解消

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: E2E の claude 起動を明示的に sonnet で実行する

**I want to** `tests/e2e/*.bats` 全 11 ファイルの `claude -p` 起動が明示的にモデル（デフォルト sonnet）を指定して実行される,
**so that** skill のトリガー・構造応答の検証が最上位モデル単価で課金されず、E2E 1 回あたりのトークンコストが約 1/4 になる（#259 ベンチ準拠）.

### US-2: 環境変数でテスト実行モデルを上書きできる

**I want to** `SKILL_E2E_MODEL` 環境変数で E2E の実行モデルを上書きできる（未設定時は `sonnet`）,
**so that** 将来のモデル検証ニーズの際に bats ファイルを書き換えずに任意モデルで同じ E2E を回せる.

### US-3: モデル指定漏れを回帰 pin で検出する

**I want to** E2E 構造検証テストが「全 `tests/e2e/*.bats` ファイルが `--model` を指定している」ことを回帰 pin として検証する,
**so that** 既存ファイルの巻き戻りや新規 e2e ファイルのモデル未指定が BATS suite で機械的に検出され、トークン過大消費が再発しない.

### US-4: モデルポリシーをドキュメントで把握できる

**I want to** `tests/README.md` の Skill E2E Tests 節にモデルポリシー（デフォルト sonnet・`SKILL_E2E_MODEL` で上書き）が記載されている,
**so that** E2E の実行者がデフォルトモデルと上書き方法を README だけで把握できる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1: 全 timeout 分岐でモデル指定が一貫している

**I want to** `_run_claude` の `timeout` / `gtimeout` / フォールバックの全分岐に同一の `--model "${E2E_MODEL}"` フラグが適用されている,
**so that** 実行環境（GNU coreutils の有無）によってコスト特性が変わらず、どの分岐を通っても同じモデルで実行される.

### CS-2: 既存の環境変数規約に整合している

**I want to** モデル設定が既存の `TIMEOUT_SECS="${SKILL_E2E_TIMEOUT_SECS:-120}"` と同じ命名規約・同じ上書き方式（ファイル冒頭の設定部で `E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"`）で定義されている,
**so that** テストハーネスの設定方法が一貫し、利用者が既存の知識のまま新しい変数を扱える.
